//
//  PianoBarController.h
//  pianobar
//
//  Created by Josh Weinberg on 5/13/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "piano.h"
#import "waitress.h"
#import "settings.h"
#import "player_macosx.h"

@interface PPPianobarController : NSObject {
	PianoHandle_t ph;
    WaitressHandle_t waith;
    BarSettings_t settings;
    PianoStation_t *curStation;
    PianoSong_t *songHistory;
	PianoSong_t *playlist;
    pthread_t playerThread;
    
    
	NSArray *stations;
    
	NSDictionary *selectedStation;
	NSDictionary *nowPlaying;
    
    BOOL paused;
    NSThread * backgroundPlayer;
    struct audioPlayer player;
}

@property (nonatomic, retain) NSDictionary *selectedStation;
@property (nonatomic, retain) NSDictionary *nowPlaying;

@property (nonatomic, retain) NSArray *stations;

@property (nonatomic, assign) BOOL paused;

-(NSAttributedString *)nowPlayingAttributedDescription;
-(BOOL)isInPlaybackMode;
-(BOOL)isPlaying;
-(BOOL)isPaused;

- (id)initWithUsername:(NSString*)username andPassword:(NSString*)password;
- (BOOL)login;
- (BOOL)loadStations;
- (void)playStationWithID:(NSString *)stationID;

- (IBAction)thumbsUpCurrentSong:(id)sender;
- (IBAction)thumbsDownCurrentSong:(id)sender;
- (IBAction)playPauseCurrentSong:(id)sender;
- (IBAction)playNextSong:(id)sender;

@end
