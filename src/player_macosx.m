#include <unistd.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
#include <limits.h>

#include "player_macosx.h"
#include "config.h"
#include "ui.h"

#import "OEAudio.h"
#import "OERingBuffer.h"

#define PRINTERROR(LABEL)	printf("%s\n", LABEL)

/* wait while locked, but don't slow down main thread by keeping
 * locks too long */
#define QUIT_PAUSE_CHECK \
pthread_mutex_lock (&player->pauseMutex); \
pthread_mutex_unlock (&player->pauseMutex); \
if (player->doQuit) { \
/* err => abort playback */ \
return WAITRESS_CB_RET_ERR; \
}

#define byteswap32(x) (((x >> 24) & 0x000000ff) | ((x >> 8) & 0x0000ff00) | \
((x << 8) & 0x00ff0000) | ((x << 24) & 0xff000000))

void MyAudioQueueOutputCallback(void* inClientData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer);
void MyAudioQueueIsRunningCallback(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID);

void StreamPropertyListenerProc(	void *							inClientData,
                                AudioFileStreamID				inAudioFileStream,
                                AudioFileStreamPropertyID		inPropertyID,
                                UInt32 *						ioFlags);

void MyPacketsProc(				void *							inClientData,
                   UInt32							inNumberBytes,
                   UInt32							inNumberPackets,
                   const void *					inInputData,
                   AudioStreamPacketDescription	*inPacketDescriptions);

OSStatus MyEnqueueBuffer(struct audioPlayer* player);
void WaitForFreeBuffer(struct audioPlayer* player);

void StreamPropertyListenerProc(	void *						inClientData,
                                AudioFileStreamID				inAudioFileStream,
                                AudioFileStreamPropertyID		inPropertyID,
                                UInt32 *						ioFlags)
{	
	// this is called by audio file stream when it finds property values
	struct audioPlayer* player = (struct audioPlayer*)inClientData;
	OSStatus err = noErr;
    
	switch (inPropertyID) {
		case kAudioFileStreamProperty_ReadyToProducePackets :
		{
			// the file stream parser is now ready to produce audio packets.
			// get the stream format.
			AudioStreamBasicDescription asbd;
			UInt32 asbdSize = sizeof(asbd);
			err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &asbdSize, &asbd);
			if (err) { PRINTERROR("get kAudioFileStreamProperty_DataFormat"); player->failed = true; break; }
			
			// create the audio queue
			err = AudioQueueNewOutput(&asbd, MyAudioQueueOutputCallback, player, NULL, NULL, 0, &player->audioQueue);
			if (err) { PRINTERROR("AudioQueueNewOutput"); player->failed = true; break; }
			
			// allocate audio queue buffers
			for (unsigned int i = 0; i < kNumAQBufs; ++i) {
				err = AudioQueueAllocateBuffer(player->audioQueue, kAQBufSize, &player->audioQueueBuffer[i]);
				if (err) { PRINTERROR("AudioQueueAllocateBuffer"); player->failed = true; break; }
			}
            
			// get the cookie size
			UInt32 cookieSize;
			Boolean writable;
			err = AudioFileStreamGetPropertyInfo(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
			if (err) { PRINTERROR("info kAudioFileStreamProperty_MagicCookieData"); break; }
			printf("cookieSize %d\n", cookieSize);
            
			// get the cookie data
			void* cookieData = calloc(1, cookieSize);
			err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
			if (err) { PRINTERROR("get kAudioFileStreamProperty_MagicCookieData"); free(cookieData); break; }
            
			// set the cookie on the queue.
			err = AudioQueueSetProperty(player->audioQueue, kAudioQueueProperty_MagicCookie, cookieData, cookieSize);
			free(cookieData);
			if (err) { PRINTERROR("set kAudioQueueProperty_MagicCookie"); break; }
            
			// listen for kAudioQueueProperty_IsRunning
			err = AudioQueueAddPropertyListener(player->audioQueue, kAudioQueueProperty_IsRunning, MyAudioQueueIsRunningCallback, player);
			if (err) { PRINTERROR("AudioQueueAddPropertyListener"); player->failed = true; break; }
			
			break;
		}
	}
}

void MyPacketsProc(				void *							inClientData,
                   UInt32							inNumberBytes,
                   UInt32							inNumberPackets,
                   const void *					inInputData,
                   AudioStreamPacketDescription	*inPacketDescriptions)
{
	// this is called by audio file stream when it finds packets of audio
	struct audioPlayer* player = (struct audioPlayer*)inClientData;
	printf("got data.  bytes: %d  packets: %d\n", inNumberBytes, inNumberPackets);
    
	// the following code assumes we're streaming VBR data. for CBR data, you'd need another code branch here.
    
	for (int i = 0; i < inNumberPackets; ++i) {
		SInt64 packetOffset = inPacketDescriptions[i].mStartOffset;
		SInt64 packetSize   = inPacketDescriptions[i].mDataByteSize;
		
		// if the space remaining in the buffer is not enough for this packet, then enqueue the buffer.
		size_t bufSpaceRemaining = kAQBufSize - player->bytesFilled;
		if (bufSpaceRemaining < packetSize) {
			MyEnqueueBuffer(player);
			WaitForFreeBuffer(player);
		}
		
		// copy data to the audio queue buffer
		AudioQueueBufferRef fillBuf = player->audioQueueBuffer[player->fillBufferIndex];
		memcpy((char*)fillBuf->mAudioData + player->bytesFilled, (const char*)inInputData + packetOffset, packetSize);
		// fill out packet description
		player->packetDescs[player->packetsFilled] = inPacketDescriptions[i];
		player->packetDescs[player->packetsFilled].mStartOffset = player->bytesFilled;
		// keep track of bytes filled and packets filled
		player->bytesFilled += packetSize;
		player->packetsFilled += 1;
		
		// if that was the last free packet description, then enqueue the buffer.
		size_t packetsDescsRemaining = kAQMaxPacketDescs - player->packetsFilled;
		if (packetsDescsRemaining == 0) {
			MyEnqueueBuffer(player);
			WaitForFreeBuffer(player);
		}
	}	
}

OSStatus StartQueueIfNeeded(struct audioPlayer* player)
{
	OSStatus err = noErr;
	if (!player->started) {		// start the queue if it has not been started already
		err = AudioQueueStart(player->audioQueue, NULL);
		if (err) { PRINTERROR("AudioQueueStart"); player->failed = true; return err; }		
		player->started = true;
		printf("started\n");
	}
	return err;
}

OSStatus MyEnqueueBuffer(struct audioPlayer* player)
{
	OSStatus err = noErr;
	player->inuse[player->fillBufferIndex] = true;		// set in use flag
	
	// enqueue buffer
	AudioQueueBufferRef fillBuf = player->audioQueueBuffer[player->fillBufferIndex];
	fillBuf->mAudioDataByteSize = player->bytesFilled;		
	err = AudioQueueEnqueueBuffer(player->audioQueue, fillBuf, player->packetsFilled, player->packetDescs);
	if (err) { PRINTERROR("AudioQueueEnqueueBuffer"); player->failed = true; return err; }		
	
	StartQueueIfNeeded(player);
	
	return err;
}


void WaitForFreeBuffer(struct audioPlayer* player)
{
	// go to next buffer
	if (++player->fillBufferIndex >= kNumAQBufs) player->fillBufferIndex = 0;
	player->bytesFilled = 0;		// reset bytes filled
	player->packetsFilled = 0;		// reset packets filled
    
	// wait until next buffer is not in use
	printf("->lock\n");
	pthread_mutex_lock(&player->mutex); 
	while (player->inuse[player->fillBufferIndex]) {
		pthread_cond_wait(&player->cond, &player->mutex);
	}
	pthread_mutex_unlock(&player->mutex);
	printf("<-unlock\n");
}

int MyFindQueueBuffer(struct audioPlayer* player, AudioQueueBufferRef inBuffer)
{
	for (unsigned int i = 0; i < kNumAQBufs; ++i) {
		if (inBuffer == player->audioQueueBuffer[i]) 
			return i;
	}
	return -1;
}


void MyAudioQueueOutputCallback(	void*					inClientData, 
                                AudioQueueRef			inAQ, 
                                AudioQueueBufferRef		inBuffer)
{
	// this is called by the audio queue when it has finished decoding our data. 
	// The buffer is now free to be reused.
	struct audioPlayer* player = (struct audioPlayer*)inClientData;
    
	unsigned int bufIndex = MyFindQueueBuffer(player, inBuffer);
	
	// signal waiting thread that the buffer is free.
	pthread_mutex_lock(&player->mutex);
	player->inuse[bufIndex] = false;
	pthread_cond_signal(&player->cond);
	pthread_mutex_unlock(&player->mutex);
}

void MyAudioQueueIsRunningCallback(		void*					inClientData, 
                                   AudioQueueRef			inAQ, 
                                   AudioQueuePropertyID	inID)
{
	struct audioPlayer* player = (struct audioPlayer*)inClientData;
	
	UInt32 running;
	UInt32 size;
	OSStatus err = AudioQueueGetProperty(inAQ, kAudioQueueProperty_IsRunning, &running, &size);
	if (err) { PRINTERROR("get kAudioQueueProperty_IsRunning"); return; }
	if (!running) {
		pthread_mutex_lock(&player->mutex);
		pthread_cond_signal(&player->done);
		pthread_mutex_unlock(&player->mutex);
	}
}


static WaitressCbReturn_t BarPlayerAACCb (void *ptr, size_t size, void *stream) {
	struct audioPlayer *player = stream;
	
	QUIT_PAUSE_CHECK;
	
    AudioFileStreamParseBytes(player->audioFileStream, size, ptr, 0);
    
    return WAITRESS_CB_RET_OK;
}

#ifdef ENABLE_MAD
#pragma mark MP3 Decoding

/*	convert mad's internal fixed point format to short int
 *	@param mad fixed
 *	@return short int
 */
static inline signed short int BarPlayerMadToShort (mad_fixed_t fixed) {
	/* Clipping */
	if (fixed >= MAD_F_ONE) {
		return SHRT_MAX;
	} else if (fixed <= -MAD_F_ONE) {
		return -SHRT_MAX;
	}
	
	/* Conversion */
	return (signed short int) (fixed >> (MAD_F_FRACBITS - 15));
}

static WaitressCbReturn_t BarPlayerMp3Cb (void *ptr, size_t size, void *stream) {
#if MAD_SET_UP
	char *data = ptr;
	struct audioPlayer *player = stream;
	size_t i;
	
	QUIT_PAUSE_CHECK;
	
	if (!BarPlayerBufferFill (player, data, size)) {
		return WAITRESS_CB_RET_ERR;
	}
	
	/* some "prebuffering" */
	if (player->mode < PLAYER_RECV_DATA &&
		player->bufferFilled < sizeof (player->buffer) / 2) {
		return WAITRESS_CB_RET_OK;
	}
	
	mad_stream_buffer (&player->mp3Stream, player->buffer,
					   player->bufferFilled);
	player->mp3Stream.error = 0;
	do {
		/* channels * max samples, found in mad.h */
		signed short int madDecoded[2*1152], *madPtr = madDecoded;
		
		if (mad_frame_decode (&player->mp3Frame, &player->mp3Stream) != 0) {
			if (player->mp3Stream.error != MAD_ERROR_BUFLEN) {
				BarUiMsg (MSG_ERR, "mp3 decoding error: %s\n",
						  mad_stream_errorstr (&player->mp3Stream));
				return WAITRESS_CB_RET_ERR;
			} else {
				/* rebuffering required => exit loop */
				break;
			}
		}
		mad_synth_frame (&player->mp3Synth, &player->mp3Frame);
		for (i = 0; i < player->mp3Synth.pcm.length; i++) {
			/* left channel */
			*(madPtr++) = applyReplayGain (BarPlayerMadToShort (
																player->mp3Synth.pcm.samples[0][i]), player->scale);
			
			/* right channel */
			*(madPtr++) = applyReplayGain (BarPlayerMadToShort (
																player->mp3Synth.pcm.samples[1][i]), player->scale);
		}
		if (player->mode < PLAYER_AUDIO_INITIALIZED) {
			ao_sample_format format;
			int audioOutDriver;
			
			player->channels = player->mp3Synth.pcm.channels;
			player->samplerate = player->mp3Synth.pcm.samplerate;
			audioOutDriver = ao_default_driver_id();
			memset (&format, 0, sizeof (format));
			format.bits = 16;
			format.channels = player->channels;
			format.rate = player->samplerate;
			format.byte_format = AO_FMT_LITTLE;
			if ((player->audioOutDevice = ao_open_live (audioOutDriver,
														&format, NULL)) == NULL) {
				player->aoError = 1;
				BarUiMsg (MSG_ERR, "Cannot open audio device\n");
				return WAITRESS_CB_RET_ERR;
			}
			
			/* calc song length using the framerate of the first decoded frame */
			player->songDuration = (unsigned long long int) player->waith.contentLength /
			((unsigned long long int) player->mp3Frame.header.bitrate /
			 (unsigned long long int) BAR_PLAYER_MS_TO_S_FACTOR / 8LL);
			
			/* must be > PLAYER_SAMPLESIZE_INITIALIZED, otherwise time won't
			 * be visible to user (ugly, but mp3 decoding != aac decoding) */
			player->mode = PLAYER_RECV_DATA;
		}
		/* samples * length * channels */
		ao_play (player->audioOutDevice, (char *) madDecoded,
				 player->mp3Synth.pcm.length * 2 * 2);
		
		/* avoid division by 0 */
		if (player->mode == PLAYER_RECV_DATA) {
			/* same calculation as in aac player; don't need to divide by
			 * channels, length is number of samples for _one_ channel */
			player->songPlayed += (unsigned long long int) player->mp3Synth.pcm.length *
			(unsigned long long int) BAR_PLAYER_MS_TO_S_FACTOR /
			(unsigned long long int) player->samplerate;
		}
		
		QUIT_PAUSE_CHECK;
	} while (player->mp3Stream.error != MAD_ERROR_BUFLEN);
	
	player->bufferRead += player->mp3Stream.next_frame - player->buffer;
	
	BarPlayerBufferMove (player);
#endif
	return WAITRESS_CB_RET_OK;
}
#endif /* ENABLE_MAD */

#pragma mark Thread

void *BarPlayerThread (void *data){
	return BarPlayerMacOSXThread(data);
}

void *BarPlayerMacOSXThread(void *data){
	struct audioPlayer *player = data;
	
    //	BarPlayerInitializeCoreAudioOutputDevice(player);
	
	char extraHeaders[25];
	void *ret = PLAYER_RET_OK;
    
	WaitressReturn_t wRet = WAITRESS_RET_ERR;
	
	/* init handles */
	pthread_mutex_init (&player->pauseMutex, NULL);
//	player->scale = computeReplayGainScale (player->gain);
	player->waith.data = (void *) player;
	/* extraHeaders will be initialized later */
	player->waith.extraHeaders = extraHeaders;
	
	switch (player->audioFormat) {
#ifdef ENABLE_FAAD
		case PIANO_AF_AACPLUS:
        {
            OSStatus err = AudioFileStreamOpen(player, StreamPropertyListenerProc, MyPacketsProc, 
                                               kAudioFileAAC_ADTSType, &player->audioFileStream);
            if (err) { PRINTERROR("AudioFileStreamOpen"); }
			player->waith.callback = BarPlayerAACCb;
        }
			break;
#endif /* ENABLE_FAAD */
			
#ifdef ENABLE_MAD
		case PIANO_AF_MP3:
		case PIANO_AF_MP3_HI:
			mad_stream_init (&player->mp3Stream);
			mad_frame_init (&player->mp3Frame);
			mad_synth_init (&player->mp3Synth);
			
			player->waith.callback = BarPlayerMp3Cb;
			break;
#endif /* ENABLE_MAD */
			
		default:
			BarUiMsg (MSG_ERR, "Unsupported audio format!\n");
			return PLAYER_RET_OK;
			break;
	}
	
	player->mode = PLAYER_INITIALIZED;
	
	/* This loop should work around song abortions by requesting the
	 * missing part of the song */
	do {
		snprintf (extraHeaders, sizeof (extraHeaders), "Range: bytes=%zu-\r\n",
				  player->bytesReceived);
		wRet = WaitressFetchCall (&player->waith);
	} while (wRet == WAITRESS_RET_PARTIAL_FILE || wRet == WAITRESS_RET_TIMEOUT
			 || wRet == WAITRESS_RET_READ_ERR);
    
    while([[(id)player->audio buffer] bytesUsed])
    {
        [NSThread sleepForTimeInterval:.01f];
    }
    
	switch (player->audioFormat) {
#ifdef ENABLE_FAAD
		case PIANO_AF_AACPLUS:
            AudioFileStreamClose(player->streamID);
            [(id)player->audio release];
			break;
#endif /* ENABLE_FAAD */
			
#ifdef ENABLE_MAD
		case PIANO_AF_MP3:
		case PIANO_AF_MP3_HI:
			mad_synth_finish (&player->mp3Synth);
			mad_frame_finish (&player->mp3Frame);
			mad_stream_finish (&player->mp3Stream);
			break;
#endif /* ENABLE_MAD */
			
		default:
			/* this should never happen: thread is aborted above */
			break;
	}
    //	if (player->aoError) {
    //		ret = (void *) PLAYER_RET_ERR;
    //	}
    //	ao_close(player->audioOutDevice);
	WaitressFree (&player->waith);
    
	pthread_mutex_destroy (&player->pauseMutex);
	
	player->mode = PLAYER_FINISHED_PLAYBACK;
	
	return ret;	
}