/*
 *  PPPianobarController+Playback.h
 *  pianobar
 *
 *  Created by Josh Weinberg on 5/14/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */
#import "PPPianobarController.h"

@interface PPPianobarController (Playback)
- (void)playSong;
- (void)fetchPlaylist;
- (void)updateHistory;
- (void)finishSong;
@end