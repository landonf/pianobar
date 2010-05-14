//
//  PianoBarController.h
//  pianobar
//
//  Created by Josh Weinberg on 5/13/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#include <TargetConditionals.h>

#if TARGET_OS_MAC
    #import <AppKit/AppKit.h>
#else
    #import <UIKit/UIKit.h>
#endif

#import "piano.h"
#import "waitress.h"
#import "settings.h"
#import "player_macosx.h"

@class PPStation, PPTrack, PPPianobarController;

@protocol PPPianobarDelegate

-(void)pianobarWillLogin:(PPPianobarController *)pianobar;
-(void)pianobarDidLogin:(PPPianobarController *)pianobar;

-(void)pianobar:(PPPianobarController *)pianobar didBeginPlayingSong:(PPTrack *)song;
-(void)pianobar:(PPPianobarController *)pianobar didBeginPlayingChannel:(PPStation *)channel;

@end


@interface PPPianobarController : NSObject {
	PianoHandle_t ph;
    WaitressHandle_t waith;
    BarSettings_t settings;
    PianoStation_t *curStation;
    PianoSong_t *songHistory;
	PianoSong_t *playlist;
    pthread_t playerThread;
    
    
	NSArray *stations;
    
	PPStation *selectedStation;
	PPTrack *nowPlaying;
    
    BOOL paused;
    NSThread * backgroundPlayer;
    struct audioPlayer player;
    
    id <PPPianobarDelegate> delegate;
}

@property (nonatomic, retain) PPStation *selectedStation;
@property (nonatomic, retain) PPTrack *nowPlaying;

@property (nonatomic, retain) NSArray *stations;

@property (nonatomic, assign) BOOL paused;
@property (nonatomic, assign) id <PPPianobarDelegate> delegate;
-(NSAttributedString *)nowPlayingAttributedDescription;
-(BOOL)isInPlaybackMode;
-(BOOL)isPlaying;
-(BOOL)isPaused;

- (id)initWithUsername:(NSString*)username andPassword:(NSString*)password;
- (BOOL)login;
- (BOOL)loadStations;
- (void)playStationWithID:(NSString *)stationID;

- (void)stop;

- (IBAction)thumbsUpCurrentSong:(id)sender;
- (IBAction)thumbsDownCurrentSong:(id)sender;
- (IBAction)playPauseCurrentSong:(id)sender;
- (IBAction)playNextSong:(id)sender;

@end
