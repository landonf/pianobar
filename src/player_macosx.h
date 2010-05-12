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

#ifdef ENABLE_FAAD
#include <neaacdec.h>
#endif

#ifdef ENABLE_MAD
#include <mad.h>
#endif

#include <CoreAudio/AudioHardware.h>
#include <pthread.h>

#include <piano.h>
#include <waitress.h>

#define BAR_PLAYER_MS_TO_S_FACTOR 1000

struct audioPlayer {
	unsigned char buffer[WAITRESS_RECV_BUFFER*2];
	size_t bufferFilled;
	size_t bufferRead;
	size_t bytesReceived;
	
	enum {
		PLAYER_FREED = 0, /* thread is not running */
		PLAYER_STARTING, /* thread is starting */
		PLAYER_INITIALIZED, /* decoder/waitress initialized */
		PLAYER_FOUND_ESDS,
		PLAYER_AUDIO_INITIALIZED, /* audio device opened */
		PLAYER_FOUND_STSZ,
		PLAYER_SAMPLESIZE_INITIALIZED,
		PLAYER_RECV_DATA, /* playing track */
		PLAYER_FINISHED_PLAYBACK
	} mode;
	
	PianoAudioFormat_t audioFormat;
	
	/* duration and already played time; measured in milliseconds */
	unsigned long int songDuration;
	unsigned long int songPlayed;

	/* aac */
#ifdef ENABLE_FAAD
	NeAACDecHandle aacHandle;
	/* stsz atom: sample sizes */
	unsigned int *sampleSize;
	size_t sampleSizeN;
	size_t sampleSizeCurr;
#endif
	
	/* mp3 */
#ifdef ENABLE_MAD
	struct mad_stream mp3Stream;
	struct mad_frame mp3Frame;
	struct mad_synth mp3Synth;
#endif
	
	unsigned long samplerate;
	unsigned char channels;
	
	float gain;
	unsigned int scale;
	
	WaitressHandle_t waith;
	
	char doQuit;
	pthread_mutex_t pauseMutex;
	
	// audio output
	AudioDeviceID                outputDeviceID;
    AudioStreamBasicDescription  outputStreamBasicDescription;	
    UInt32                       outputBufferByteCount;
	void                        *outputBuffer; // TODO switch this to a ring buffer?
    unsigned int                 outputFirstValidByteOffset;
    unsigned int                 outputValidByteCount;
    pthread_mutex_t              outputMutex;
    pthread_cond_t               outputCondition;	
	
};

enum {PLAYER_RET_OK = 0, PLAYER_RET_ERR = 1};

void *BarPlayerThread (void *data);
void *BarPlayerMacOSXThread(void *data);

void BarPlayerInitializeCoreAudioOutputDevice(struct audioPlayer *player);

static OSStatus BarPlayerMacOSX_AudioDeviceIOProc(AudioDeviceID inDevice, const AudioTimeStamp *inNow, const AudioBufferList *inInputData, const AudioTimeStamp *inInputTime, AudioBufferList *outOutputData, const AudioTimeStamp *inOutputTime, void *inClientData);

#endif /* _PLAYER_MACOSX_H */
