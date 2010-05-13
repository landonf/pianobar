/*
 *  mac_audio.h
 *  pianobar
 *
 *  Created by Josh Weinberg on 5/12/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#pragma once
#include <CoreAudio/CoreAudio.h>
#include <AudioToolbox/AudioToolbox.h>
#include "player_macosx.h"

void PianobarAudioQueueOutputCallback(void* inClientData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer);
void AudioQueueIsRunningCallback(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID);

void StreamPropertyListenerProc(void * inClientData,
                                AudioFileStreamID inAudioFileStream,
                                AudioFileStreamPropertyID inPropertyID,
                                UInt32 * ioFlags);

void StreamPacketsProc(void * inClientData,
                       UInt32 inNumberBytes,
                       UInt32 inNumberPackets,
                       const void * inInputData,
                       AudioStreamPacketDescription	*inPacketDescriptions);

OSStatus EnqueueBuffer(struct audioPlayer* player);
void WaitForFreeBuffer(struct audioPlayer* player);
