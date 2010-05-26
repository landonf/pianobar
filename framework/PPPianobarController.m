//
//  PianoBarController.m
//  pianobar
//
//  Created by Josh Weinberg on 5/13/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PPPianobarController.h"
#import "mac_piano.h"
#import "piano.h"
#import "PPTrack.h"
#import "PPStation.h"
#import "PPPianobarController+Playback.h"
#import "PPSearchResult.h"

NSString *PPPianobarControllerWillLoginNotification = @"PPPianobarControllerWillLoginNotification";
NSString *PPPianobarControllerDidLoginNotification = @"PPPianobarControllerDidLoginNotification";
NSString *PPPianobarControllerDidBeginPlayingStationNotification = @"PPPianobarControllerDidBeginPlayingStationNotification";
NSString *PPPianobarControllerDidBeginPlayingTrackNotification = @"PPPianobarControllerDidBeginPlayingTrackNotification";
NSString *PPPianobarControllerDidBeginPlayingTrackDistributedNotification = @"com.villainware.PlayerPiano.PPPianobarControllerDidBeginPlayingTrackNotification";

@interface PPPianobarController ()
-(NSURL *)iTunesLink;
-(NSURL *)amazonLink;
@end

@implementation PPPianobarController

@synthesize stations, selectedStation, nowPlaying, paused, delegate;

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key{
	if([key isEqualToString:@"paused"]){
		return [NSSet setWithObjects:
				@"isInPlaybackMode", @"isPlaying", @"isPaused",
				nil];
	}else if([key isEqualToString:@"nowPlaying"]){
		return [NSSet setWithObjects:
				@"nowPlayingAttributedDescription",
				nil];
	}else{
		return [super keyPathsForValuesAffectingValueForKey:key];
	}
}

-(void)setNowPlaying:(PPTrack *)aTrack{
	[self willChangeValueForKey:@"nowPlaying"];
	[nowPlaying autorelease];
	nowPlaying = [aTrack retain];
	[self didChangeValueForKey:@"nowPlaying"];
}

-(BOOL)isInPlaybackMode{
	return player.mode > PLAYER_INITIALIZED;
}

-(BOOL)isPlaying{
	return [self isInPlaybackMode] && !paused;
}

-(BOOL)isPaused{
	return [self isInPlaybackMode] && paused;
}

-(double)volume{
	AudioQueueRef audioQueue = player.audioQueue;
	
	AudioQueueParameterValue volume;
	if(AudioQueueGetParameter(audioQueue, kAudioQueueParam_Volume, &volume) == noErr){
		return (double)volume;
	}else{
		return 0.;
	}
}

-(void)setVolume:(double)volume{
	AudioQueueSetParameter(player.audioQueue, kAudioQueueParam_Volume, (AudioQueueParameterValue)volume);
}

-(NSAttributedString *)nowPlayingAttributedDescription{
	NSMutableAttributedString *description = [[[NSMutableAttributedString alloc] initWithString:@""] autorelease];
#if !TARGET_OS_IPHONE && !TARGET_IPHONE_SIMULATOR
	PPTrack *playing = self.nowPlaying;
	if(playing){
		NSFont *titleFont = [[NSFontManager sharedFontManager] convertFont: [NSFont fontWithName:@"Helvetica" size:18.0]
															   toHaveTrait:NSBoldFontMask];
		NSFont *restFont = [NSFont fontWithName:@"Helvetica Neue Light" size:16.0];
		
		NSColor *titleColor = [NSColor colorWithCalibratedWhite:0.8 alpha:1.0];
		NSColor *restColor  = [NSColor colorWithCalibratedWhite:0.6 alpha:1.0];
		
		NSAttributedString *newline = [[[NSAttributedString alloc] initWithString:@"\n"] autorelease];
		
		NSAttributedString *title = [[[NSAttributedString alloc] initWithString:[playing title]
																	 attributes:[NSDictionary dictionaryWithObjectsAndKeys:
																				 titleFont, NSFontAttributeName,
																				 titleColor, NSForegroundColorAttributeName,
																				 nil]] autorelease];
		NSAttributedString *artist = [[[NSAttributedString alloc] initWithString:[@"by " stringByAppendingString:[playing artist]]
                                                                      attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                  restFont, NSFontAttributeName,
                                                                                  restColor, NSForegroundColorAttributeName,
                                                                                  nil]] autorelease];
		NSAttributedString *album = [[[NSAttributedString alloc] initWithString:[@"on " stringByAppendingString:[playing album]]
																	 attributes:[NSDictionary dictionaryWithObjectsAndKeys:
																				 restFont, NSFontAttributeName,
																				 restColor, NSForegroundColorAttributeName,
																				 nil]] autorelease];
		[description appendAttributedString:title];
		[description appendAttributedString:newline];
		[description appendAttributedString:artist];
		[description appendAttributedString:newline];
		[description appendAttributedString:album];
	}
	
    //	NSLog(@"Now playing attributed description! %@ -> %@",description, attributedDescription);
#endif
	return [[description copy] autorelease];
}


- (id)initWithUsername:(NSString*)username andPassword:(NSString*)password;
{
    if ((self = [super init]))
    {
        PianoInit(&ph);
        WaitressInit (&waith);

        strncpy (waith.host, PIANO_RPC_HOST, sizeof (waith.host)-1);
        strncpy (waith.port, PIANO_RPC_PORT, sizeof (waith.port)-1);

        BarSettingsInit (&settings);
        BarSettingsRead (&settings);
        
        settings.username = strdup([username UTF8String]);
        settings.password = strdup([password UTF8String]);
        
        if (settings.controlProxy != NULL) {
            char tmpPath[2];
            WaitressSplitUrl (settings.controlProxy, waith.proxyHost,
                              sizeof (waith.proxyHost), waith.proxyPort,
                              sizeof (waith.proxyPort), tmpPath, sizeof (tmpPath));
        }
    }
    return self;
}

- (void)dealloc;
{
   delegate = nil;
    
    [stations release], stations = nil;
    [nowPlaying release], nowPlaying = nil;
    [selectedStation release], selectedStation = nil;
    
    PianoDestroy (&ph);
	PianoDestroyPlaylist (songHistory);
	PianoDestroyPlaylist (playlist);
    
    BarSettingsDestroy (&settings);
    
    [super dealloc];
}

- (BOOL)login;
{
    PianoReturn_t pRet;
    WaitressReturn_t wRet;
    PianoRequestDataLogin_t reqData;
    reqData.user = settings.username;
    reqData.password = settings.password;
	
	[self _willLogin];
    if (!BarUiPianoCall (&ph, PIANO_REQUEST_LOGIN, &waith, &reqData, &pRet,
                         &wRet)) {
        return NO;
    }
    [self _didLogin];
	return YES;
}

- (BOOL)loadStations;
{
	// Get rid of any of any existing stations
	PianoStation_t *currentStation = ph.stations;
	while (currentStation) {
		PianoStation_t *next = currentStation->next;
		free(currentStation);
		currentStation = next;
	}
	ph.stations = NULL;
	
    PianoReturn_t pRet;
    WaitressReturn_t wRet;
    
    if (!BarUiPianoCall (&ph, PIANO_REQUEST_GET_STATIONS, &waith, NULL,
                         &pRet, &wRet)) {
        return NO;
    }
    
    NSMutableArray *tempStations = [[NSMutableArray alloc] init];
    PianoStation_t **sortedStations = NULL;
    
	size_t stationCount, i;
	
    /* sort and print stations */
	sortedStations = BarSortedStations (ph.stations, &stationCount);
	for (i = 0; i < stationCount; i++) {
		const PianoStation_t *currStation = sortedStations[i];
		[tempStations addObject:[PPStation stationWithName:[NSString stringWithUTF8String:currStation->name]
												 stationID:i]];
        //
//		BarUiMsg (MSG_LIST, "%2i) %c%c%c %s\n", i,
//                  currStation->useQuickMix ? 'q' : ' ',
//                  currStation->isQuickMix ? 'Q' : ' ',
//                  !currStation->isCreator ? 'S' : ' ',
//                  currStation->name);
	}
    
    self.stations = [NSArray arrayWithArray:tempStations];
    [tempStations release];
    
    free(sortedStations);
    return YES;
}

-(void)playStationWithID:(NSString *)stationID;
{
    [self stop];
    
    pthread_join(playerThread, NULL);

    curStation = BarSelectStation(&ph, [stationID intValue]);
	[self _didBeginPlayingStation:[self.stations objectAtIndex:[stationID intValue]]];
    backgroundPlayer = [[NSThread alloc] initWithTarget:self selector:@selector(startPlayback) object:nil];
    [backgroundPlayer start];
}

- (void)startPlayback;
{
	/* little hack, needed to signal: hey! we need a playlist, but don't
	 * free anything (there is nothing to be freed yet) */
	memset (&player, 0, sizeof (player));
    
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
	while (![[NSThread currentThread] isCancelled]) 
    {
		/* song finished playing, clean up things/scrobble song */
		if (player.mode == PLAYER_FINISHED_PLAYBACK) {
			BarUiStartEventCmd (&settings, "songfinish", curStation, playlist,
                                &player, PIANO_RET_OK, WAITRESS_RET_OK);
			/* FIXME: pthread_join blocks everything if network connection
			 * is hung up e.g. */
			void *threadRet;
			pthread_join (playerThread, &threadRet);
			/* don't continue playback if thread reports error */
			if (threadRet != (void *) PLAYER_RET_OK) {
				curStation = NULL;
			}
			memset (&player, 0, sizeof (player));
		}
        
		/* check whether player finished playing and start playing new
		 * song */
		if (player.mode >= PLAYER_FINISHED_PLAYBACK ||
            player.mode == PLAYER_FREED) {
			if (curStation != NULL) {
				if (playlist != NULL) {
                    [self advancePlaylist];
				}
				if (playlist == NULL) {
                    [self fetchPlaylist];
                }
                
				if (playlist != NULL) {
                    [self playSong];
				}
			}
		}
        else
        {
            //double timeTotalInterval = player.songDuration / 1000.0f;
            //double timePlayed = player.songPlayed / 1000.0f;
            /*[self.nowPlaying setDuration:timeTotalInterval];
			[self.nowPlaying setCurrentTime:timePlayed];
			[self.nowPlaying setTimeLeft:timeTotalInterval-timePlayed];*/
        }

        usleep(100);
    }
    
    [pool drain];
}

-(NSArray *)stationsSimilarToArtist:(NSString *)query
{
	PianoReturn_t pRet;
	WaitressReturn_t wRet;
	PianoRequestDataSearch_t reqData;
	reqData.searchStr = (char *)[query cStringUsingEncoding:NSASCIIStringEncoding];
	BarUiPianoCall(&ph, PIANO_REQUEST_SEARCH, &waith, &reqData, &pRet, &wRet);
	
	PianoSearchResult_t searchResult;
	memcpy(&searchResult, &reqData.searchResult, sizeof(searchResult));
	
	PianoArtist_t *artist = searchResult.artists;
	NSMutableArray *results = [[NSMutableArray alloc] init];
	while (artist != NULL) {
		NSString *artistName = [NSString stringWithCString:artist->name encoding:NSASCIIStringEncoding];
		NSString *musicID = [NSString stringWithCString:artist->musicId encoding:NSASCIIStringEncoding];
		PPSearchResult *result = [PPSearchResult searchResultWithArtist:artistName title:nil musicID:musicID];
		[results addObject:result];
		artist = artist->next;
	}
	PianoDestroySearchResult(&searchResult);
	
	NSArray *returnArray = [NSArray arrayWithArray:results];
	[results release];
	return returnArray;
}

-(NSArray *)stationsSimilarToSong:(NSString *)query
{
	PianoReturn_t pRet;
	WaitressReturn_t wRet;
	PianoRequestDataSearch_t reqData;
	reqData.searchStr = (char *)[query cStringUsingEncoding:NSASCIIStringEncoding];
	BarUiPianoCall(&ph, PIANO_REQUEST_SEARCH, &waith, &reqData, &pRet, &wRet);
	
	PianoSearchResult_t searchResult;
	memcpy(&searchResult, &reqData.searchResult, sizeof(searchResult));
	
	PianoSong_t *song = searchResult.songs;
	NSMutableArray *results = [[NSMutableArray alloc] init];
	while (song != NULL) {
		NSString *artistName = [NSString stringWithCString:song->artist encoding:NSASCIIStringEncoding];
		NSString *songTitle = [NSString stringWithCString:song->title encoding:NSASCIIStringEncoding];
		NSString *musicID = [NSString stringWithCString:song->musicId encoding:NSASCIIStringEncoding];
		PPSearchResult *result = [PPSearchResult searchResultWithArtist:artistName title:songTitle musicID:musicID];
		[results addObject:result];
		song = song->next;
	}
	PianoDestroySearchResult(&searchResult);
	
	NSArray *returnArray = [NSArray arrayWithArray:results];
	[results release];
	return returnArray;
}

-(void)createStationForMusicID:(NSString *)musicID
{
	PianoReturn_t pRet;
	WaitressReturn_t wRet;
	PianoRequestDataCreateStation_t reqData;
	char *stationId = (char *)[musicID cStringUsingEncoding:NSASCIIStringEncoding];
	reqData.id = stationId;
	reqData.type = "mi";
	BarUiPianoCall(&ph, PIANO_REQUEST_CREATE_STATION, &waith, &reqData, &pRet, &wRet);
	BarUiStartEventCmd(&settings, "stationcreate", curStation, playlist, &player, pRet, wRet);
	[self loadStations];
}

-(IBAction)thumbsUpCurrentSong:(id)sender;
{
    PianoReturn_t pRet;
	WaitressReturn_t wRet;

    PianoRequestDataRateSong_t reqData;
	reqData.song = playlist;
	reqData.rating = PIANO_RATE_LOVE;
    
	BarUiPianoCall (&ph, PIANO_REQUEST_RATE_SONG, &waith, &reqData, &pRet,
                    &wRet);
	BarUiStartEventCmd (&settings, "songlove", curStation, playlist, &player,
                        pRet, wRet);
}

-(IBAction)thumbsDownCurrentSong:(id)sender;
{
    PianoReturn_t pRet;
	WaitressReturn_t wRet;
    
    PianoRequestDataRateSong_t reqData;
	reqData.song = playlist;
	reqData.rating = PIANO_RATE_BAN;
    
	BarUiPianoCall (&ph, PIANO_REQUEST_RATE_SONG, &waith, &reqData, &pRet,
                    &wRet);
	BarUiStartEventCmd (&settings, "songban", curStation, playlist, &player,
                        pRet, wRet);
}

-(IBAction)playPauseCurrentSong:(id)sender;
{	
    if (pthread_mutex_trylock (&player.pauseMutex) == EBUSY) {
		pthread_mutex_unlock (&player.pauseMutex);
	}
	[self willChangeValueForKey:@"isPlaying"];
	self.paused = !self.paused;
	[self  didChangeValueForKey:@"isPlaying"];
	
}

-(IBAction)playNextSong:(id)sender;
{
 	player.doQuit = 1;
	pthread_mutex_unlock (&player.pauseMutex);
}

-(void)stop;
{
    [backgroundPlayer cancel];
    [backgroundPlayer release];
    backgroundPlayer = nil;
    
    [self playNextSong:nil];
}

-(IBAction)openInStore:(id)sender
{
	NSURL *link = [self iTunesLink];
#if (TARGET_OS_MAC == 1) && (TARGET_OS_IPHONE == 0)
	if ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) {
		link = [self amazonLink];
	}
#endif
	
#if TARGET_OS_IPHONE
	[[UIApplication sharedApplication] openURL:link];
#else
	[[NSWorkspace sharedWorkspace] openURL:link];
#endif
}

-(NSURL *)iTunesLink
{
	NSString *link = [[[NSString stringWithFormat:@"itms://phobos.apple.com/WebObjects/MZSearch.woa/wa/advancedSearchResults?songTerm=%@&artistTerm=%@", [[self nowPlaying] title], [[self nowPlaying] artist]] copy] autorelease];
	return [NSURL URLWithString:[link stringByReplacingOccurrencesOfString:@" " withString:@"%20"]];
}

-(NSURL *)amazonLink
{
	NSString *searchTerm = [NSString stringWithFormat:@"%@ %@", [[self nowPlaying] title], [[self nowPlaying] artist]];
	searchTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
	return [[[NSURL URLWithString:[NSString stringWithFormat:@"http://www.amazon.com/s/ref=nb_sb_noss?url=search-alias=digital-music&field-keywords=%@", searchTerm]] copy] autorelease];
}

-(void)_willLogin{
	if(self.delegate && [self.delegate respondsToSelector:@selector(pianobarWillLogin:)]){
		[self.delegate pianobarWillLogin:self];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:PPPianobarControllerWillLoginNotification
														object:self];
}

-(void)_didLogin{
	if(self.delegate && [self.delegate respondsToSelector:@selector(pianobarDidLogin:)]){
		[self.delegate pianobarDidLogin:self];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:PPPianobarControllerDidLoginNotification
														object:self];	
}

-(void)_didBeginPlayingTrack:(PPTrack *)track{
	if(self.delegate && [self.delegate respondsToSelector:@selector(pianobar:didBeginPlayingTrack:)]){
		[self.delegate pianobar:self didBeginPlayingTrack:track];
	}else if(self.delegate && [self.delegate respondsToSelector:@selector(pianobar:didBeginPlayingSong:)]){
		NSLog(@" * Calling -[%@<PPPianobarDelegate> pianobar:didBeginPlayingSong:], which is deprecated. Use -[id<PPPianobarDelegate> pianobar:didBeginPlayingTrack:] instead.",[self.delegate class]);
		[self.delegate pianobar:self didBeginPlayingSong:track];
	}
	
	NSDictionary *trackDict = [NSDictionary dictionaryWithObject:track 
														  forKey:@"track"];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:PPPianobarControllerDidBeginPlayingTrackNotification
														object:self
													  userInfo:trackDict];
	
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:PPPianobarControllerDidBeginPlayingTrackDistributedNotification
																   object:self
																 userInfo:trackDict];
}

-(void)_didBeginPlayingStation:(PPStation *)station{
	if(self.delegate && [self.delegate respondsToSelector:@selector(pianobar:didBeginPlayingStation:)]){
		[self.delegate pianobar:self didBeginPlayingStation:station];
	}else if(self.delegate && [self.delegate respondsToSelector:@selector(pianobar:didBeginPlayingChannel:)]){
		NSLog(@" * Calling -[%@<PPPianobarDelegate> pianobar:didBeginPlayingChannel:], which is deprecated. Use -[id<PPPianobarDelegate> pianobar:didBeginPlayingStation:] instead.",[self.delegate class]);
		[self.delegate pianobar:self didBeginPlayingChannel:station];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:PPPianobarControllerDidBeginPlayingStationNotification
														object:self
													  userInfo:[NSDictionary dictionaryWithObject:station 
																						   forKey:@"station"]];	
}

@end
