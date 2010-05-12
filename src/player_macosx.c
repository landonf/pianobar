#include <unistd.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
#include <limits.h>

#include "mac_audio.h"
#include "player_macosx.h"
#include "config.h"
#include "ui.h"

/* wait while locked, but don't slow down main thread by keeping
 * locks too long */
#define QUIT_PAUSE_CHECK \
pthread_mutex_lock (&player->pauseMutex); \
pthread_mutex_unlock (&player->pauseMutex); \
if (player->doQuit) { \
/* err => abort playback */ \
return WAITRESS_CB_RET_ERR; \
}

static WaitressCbReturn_t BarPlayerAACCb (void *ptr, size_t size, void *stream) {
	struct audioPlayer *player = stream;
	
	QUIT_PAUSE_CHECK;
    AudioFileStreamParseBytes(player->audioFileStream, size, ptr, 0);
    
    return WAITRESS_CB_RET_OK;
}

#pragma mark Thread

void *BarPlayerThread (void *data){
	return BarPlayerMacOSXThread(data);
}

void *BarPlayerMacOSXThread(void *data){
	struct audioPlayer *player = data;
	
	char extraHeaders[25];
	void *ret = PLAYER_RET_OK;
    
	WaitressReturn_t wRet = WAITRESS_RET_ERR;
	
	/* init handles */
	pthread_mutex_init (&player->pauseMutex, NULL);

	player->waith.data = (void *) player;
	/* extraHeaders will be initialized later */
	player->waith.extraHeaders = extraHeaders;

    player->songPlayed = 0;
	switch (player->audioFormat) {
		case PIANO_AF_AACPLUS:
        {
            OSStatus err = AudioFileStreamOpen(player, StreamPropertyListenerProc, StreamPacketsProc, 
                                               kAudioFileAAC_ADTSType, &player->audioFileStream);
            if (err) 
                BarUiMsg (MSG_ERR, "Error opening stream!\n");
			player->waith.callback = BarPlayerAACCb;
        }
			break;

		case PIANO_AF_MP3:
		case PIANO_AF_MP3_HI:
        {
            OSStatus err = AudioFileStreamOpen(player, StreamPropertyListenerProc, StreamPacketsProc, 
                                               kAudioFileMP3Type, &player->audioFileStream);			
            if (err)
                BarUiMsg (MSG_ERR, "Error opening stream!\n");
			player->waith.callback = BarPlayerAACCb;
        }
			break;
			
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
        
	switch (player->audioFormat) {
		case PIANO_AF_AACPLUS:
        case PIANO_AF_MP3:
		case PIANO_AF_MP3_HI:
            AudioFileStreamClose(player->streamID);
			break;
		default:
			/* this should never happen: thread is aborted above */
			break;
	}
    
	WaitressFree (&player->waith);
	pthread_mutex_destroy (&player->pauseMutex);
	player->mode = PLAYER_FINISHED_PLAYBACK;
	
	return ret;	
}