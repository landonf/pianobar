/*
 *  player_macosx.h
 *  pianobar
 *
 *  Created by Steve Streza on 5/12/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#ifndef _PLAYER_MACOSX_H
#define _PLAYER_MACOSX_H

#include "config.h"

#include <pthread.h>

#include "piano.h"
#include "waitress.h"
#include <AudioToolbox/AudioToolbox.h>

#define BAR_PLAYER_MS_TO_S_FACTOR 1000

#define kNumAQBufs 3		
#define kAQBufSize (1024)
#define kAQMaxPacketDescs (512)

#define PRINTERROR(LABEL)	printf("%s\n", LABEL)

struct audioPlayer {

	enum {
		PLAYER_FREED = 0, /* thread is not running */
		PLAYER_STARTING, /* thread is starting */
        PLAYER_SAMPLESIZE_INITIALIZED,
		PLAYER_INITIALIZED, /* decoder/waitress initialized */
		PLAYER_RECV_DATA, /* playing track */
		PLAYER_FINISHED_PLAYBACK
	} mode;
	
	PianoAudioFormat_t audioFormat;
    size_t bytesReceived;
	
    /* duration and already played time; measured in milliseconds */
	unsigned long int songDuration;
	unsigned long int songPlayed;
    double packetDuration;
    double dSongPlayed;
    unsigned long int processedPacketsSize;
    unsigned long int processedPacketCount;
    AudioFileStreamID audioFileStream;	// the audio file stream parser
    
	AudioQueueRef audioQueue;								// the audio queue
	AudioQueueBufferRef audioQueueBuffer[kNumAQBufs];		// audio queue buffers
	
	AudioStreamPacketDescription packetDescs[kAQMaxPacketDescs];	// packet descriptions for enqueuing audio
	
	unsigned int fillBufferIndex;	// the index of the audioQueueBuffer that is being filled
	size_t bytesFilled;				// how many bytes have been filled
	size_t packetsFilled;			// how many packets have been filled
    
	bool inuse[kNumAQBufs];			// flags to indicate that a buffer is still in use
	bool started;					// flag to indicate that the queue has been started
	bool failed;					// flag to indicate an error occurred

    
	float gain;
	unsigned int scale;
	
    AudioFileStreamID streamID;
    
	WaitressHandle_t waith;
	unsigned long samplerate;
	char doQuit;
    pthread_mutex_t mutex;			// a mutex to protect the inuse flags
	pthread_mutex_t pauseMutex;
    pthread_cond_t cond;			// a condition varable for handling the inuse flags
	pthread_cond_t done;			// a condition varable for handling the inuse flags
    void * audio;
};

enum {PLAYER_RET_OK = 0, PLAYER_RET_ERR = 1};

void BarPlayerInit (struct audioPlayer *player);
void BarPlayerCleanup (struct audioPlayer *player);

void *BarPlayerThread (void *data);
void *BarPlayerMacOSXThread(void *data);

#endif /* _PLAYER_MACOSX_H */
