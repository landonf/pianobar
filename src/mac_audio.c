/*
 *  mac_audio.c
 *  pianobar
 *
 *  Created by Josh Weinberg on 5/12/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "mac_audio.h"
#include "player_macosx.h"

unsigned long int EstimatedDuration(struct audioPlayer * player);

void StreamPropertyListenerProc(void * inClientData,
                                AudioFileStreamID inAudioFileStream,
                                AudioFileStreamPropertyID inPropertyID,
                                UInt32 * ioFlags)
{	
	// this is called by audio file stream when it finds property values
	struct audioPlayer* player = (struct audioPlayer*)inClientData;
	OSStatus err = noErr;
    
//    printf("found property '%c%c%c%c'\n", (inPropertyID>>24)&255, (inPropertyID>>16)&255, (inPropertyID>>8)&255, inPropertyID&255);

	switch (inPropertyID) {
		case kAudioFileStreamProperty_ReadyToProducePackets :
		{
			// the file stream parser is now ready to produce audio packets.
			// get the stream format.
			AudioStreamBasicDescription asbd;
			UInt32 asbdSize = sizeof(asbd);
			err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &asbdSize, &asbd);
			if (err) { PRINTERROR("get kAudioFileStreamProperty_DataFormat"); player->failed = true; break; }
			
            //TODO: Is this really right!?!
            player->songDuration = player->waith.contentLength * 2000 / asbd.mSampleRate;
            player->samplerate = asbd.mSampleRate;
            
            player->packetDuration = asbd.mFramesPerPacket / asbd.mSampleRate;
            
			// create the audio queue
			err = AudioQueueNewOutput(&asbd, PianobarAudioQueueOutputCallback, player, NULL, NULL, 0, &player->audioQueue);
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
            
			// get the cookie data
			void* cookieData = calloc(1, cookieSize);
			err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
			if (err) { PRINTERROR("get kAudioFileStreamProperty_MagicCookieData"); free(cookieData); break; }
            
			// set the cookie on the queue.
			err = AudioQueueSetProperty(player->audioQueue, kAudioQueueProperty_MagicCookie, cookieData, cookieSize);
			free(cookieData);
			if (err) { PRINTERROR("set kAudioQueueProperty_MagicCookie"); break; }
            
			// listen for kAudioQueueProperty_IsRunning
			err = AudioQueueAddPropertyListener(player->audioQueue, kAudioQueueProperty_IsRunning, AudioQueueIsRunningCallback, player);
			if (err) { PRINTERROR("AudioQueueAddPropertyListener"); player->failed = true; break; }
			
			break;
		}
	}
}

void StreamPacketsProc(void * inClientData,
                       UInt32 inNumberBytes,
                       UInt32 inNumberPackets,
                       const void * inInputData,
                       AudioStreamPacketDescription	*inPacketDescriptions)
{
	// this is called by audio file stream when it finds packets of audio
	struct audioPlayer* player = (struct audioPlayer*)inClientData;
    
	// the following code assumes we're streaming VBR data. for CBR data, you'd need another code branch here.
    
    
	for (int i = 0; i < inNumberPackets; ++i) {
		SInt64 packetOffset = inPacketDescriptions[i].mStartOffset;
		SInt64 packetSize   = inPacketDescriptions[i].mDataByteSize;
        
        player->processedPacketsSize += packetSize;
        player->processedPacketCount += 1;
        
		// if the space remaining in the buffer is not enough for this packet, then enqueue the buffer.
		size_t bufSpaceRemaining = kAQBufSize - player->bytesFilled;
		if (bufSpaceRemaining < packetSize) {
			EnqueueBuffer(player);
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
		player->dSongPlayed += player->packetDuration * 1000.0f; 
        player->songPlayed = (unsigned long int)player->dSongPlayed;
		// if that was the last free packet description, then enqueue the buffer.
		size_t packetsDescsRemaining = kAQMaxPacketDescs - player->packetsFilled;
		if (packetsDescsRemaining == 0) {
			EnqueueBuffer(player);
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
	}
	return err;
}

OSStatus EnqueueBuffer(struct audioPlayer* player)
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
	pthread_mutex_lock(&player->mutex); 
	while (player->inuse[player->fillBufferIndex]) {
		pthread_cond_wait(&player->cond, &player->mutex);
        usleep(100);
	}
	pthread_mutex_unlock(&player->mutex);
}

int MyFindQueueBuffer(struct audioPlayer* player, AudioQueueBufferRef inBuffer)
{
	for (unsigned int i = 0; i < kNumAQBufs; ++i) {
		if (inBuffer == player->audioQueueBuffer[i]) 
			return i;
	}
	return -1;
}


void PianobarAudioQueueOutputCallback(void* inClientData, 
                                      AudioQueueRef inAQ, 
                                      AudioQueueBufferRef inBuffer)
{
	// this is called by the audio queue when it has finished decoding our data. 
	// The buffer is now free to be reused.
	struct audioPlayer* player = (struct audioPlayer*)inClientData;

    if (player->mode != PLAYER_FREED)
    {
        unsigned int bufIndex = MyFindQueueBuffer(player, inBuffer);

        // signal waiting thread that the buffer is free.
        pthread_mutex_lock(&player->mutex);
        player->inuse[bufIndex] = false;
        player->songDuration = EstimatedDuration(player);
        pthread_cond_signal(&player->cond);
        pthread_mutex_unlock(&player->mutex);
    }
}

void AudioQueueIsRunningCallback(void* inClientData, 
                                 AudioQueueRef inAQ, 
                                 AudioQueuePropertyID inID)
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

double CalculatedBitRate(struct audioPlayer * player)
{
	if (player->packetDuration && player->processedPacketCount > 50)
	{
		double averagePacketByteSize = player->processedPacketsSize / player->processedPacketCount;
		return 8.0 * averagePacketByteSize / player->packetDuration;
	}
    
	return 0;
}

unsigned long int EstimatedDuration(struct audioPlayer * player)
{
	double calculatedBitRate = CalculatedBitRate(player);
    
	if (calculatedBitRate == 0 || player->waith.contentLength == 0)
	{
		return 0.0;
	}
    
	return (unsigned long int)(((double)(player->waith.contentLength) / (calculatedBitRate * 0.125)) * 1000);
}
