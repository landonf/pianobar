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

@implementation PPPianobarController

@synthesize stations, selectedStation, nowPlaying, paused;

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
	[self willChangeValueForKey:@"nowPlayingAttributedDescription"];
	[nowPlaying autorelease];
	nowPlaying = [aTrack retain];
	[self didChangeValueForKey:@"nowPlayingAttributedDescription"];
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


-(NSAttributedString *)nowPlayingAttributedDescription{
	NSMutableAttributedString *description = [[[NSMutableAttributedString alloc] initWithString:@""] autorelease];
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
    [stations release], stations = nil;
    [nowPlaying release], nowPlaying = nil;
    [selectedStation release], selectedStation = nil;
    
    free(settings.username);
    free(settings.password);
    
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
    
    if (!BarUiPianoCall (&ph, PIANO_REQUEST_LOGIN, &waith, &reqData, &pRet,
                         &wRet)) {
        return NO;
    }
    return YES;
}

- (BOOL)loadStations;
{
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
    
    stations = [[NSArray alloc] initWithArray:tempStations];
    [tempStations release];
    
    free(sortedStations);
    return YES;
}

-(void)playStationWithID:(NSString *)stationID;
{
    [self stop];
    
    while (player.mode != PLAYER_FINISHED_PLAYBACK && player.mode != PLAYER_FREED)
    {
        usleep(10);
    }
    curStation = BarSelectStation(&ph, [stationID intValue]);
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
				/* what's next? */
				if (playlist != NULL) {
					if (settings.history != 0) {
						/* prepend song to history list */
						PianoSong_t *tmpSong = songHistory;
						songHistory = playlist;
						/* select next song */
						playlist = playlist->next;
						songHistory->next = tmpSong;
                        
						/* limit history's length */
						/* start with 1, so we're stopping at n-1 and have the
						 * chance to set ->next = NULL */
						unsigned int i = 1;
						tmpSong = songHistory;
						while (i < settings.history && tmpSong != NULL) {
							tmpSong = tmpSong->next;
							++i;
						}
						/* if too many songs in history... */
						if (tmpSong != NULL) {
							PianoSong_t *delSong = tmpSong->next;
							tmpSong->next = NULL;
							if (delSong != NULL) {
								PianoDestroyPlaylist (delSong);
							}
						}
					} else {
						/* don't keep history */
						playlist = playlist->next;
					}
				}
				if (playlist == NULL) {
					PianoReturn_t pRet;
					WaitressReturn_t wRet;
					PianoRequestDataGetPlaylist_t reqData;
					reqData.station = curStation;
					reqData.format = settings.audioFormat;
                    
					BarUiMsg (MSG_INFO, "Receiving new playlist... ");
					if (!BarUiPianoCall (&ph, PIANO_REQUEST_GET_PLAYLIST,
                                         &waith, &reqData, &pRet, &wRet)) {
						curStation = NULL;
					} else {
						playlist = reqData.retPlaylist;
						if (playlist == NULL) {
							BarUiMsg (MSG_INFO, "No tracks left.\n");
							curStation = NULL;
						}
					}
					BarUiStartEventCmd (&settings, "stationfetchplaylist",
                                        curStation, playlist, &player, pRet, wRet);
				}
				/* song ready to play */
				if (playlist != NULL) {
/*					BarUiPrintSong (playlist, curStation->isQuickMix ?
                                    PianoFindStationById (ph.stations,
                                                          playlist->stationId) : NULL);*/
                    self.nowPlaying = [PPTrack trackWithTitle:[NSString stringWithUTF8String:playlist->title]
													   artist:[NSString stringWithUTF8String:playlist->artist] 
														album:[NSString stringWithUTF8String:playlist->album]];
				    
					if (playlist->audioUrl == NULL) {
						BarUiMsg (MSG_ERR, "Invalid song url.\n");
					} else {
						/* setup player */
						memset (&player, 0, sizeof (player));
                        
						WaitressInit (&player.waith);
						WaitressSetUrl (&player.waith, playlist->audioUrl);
                        
						player.gain = playlist->fileGain;
						player.audioFormat = playlist->audioFormat;
                        
						/* throw event */
						BarUiStartEventCmd (&settings, "songstart", curStation,
                                            playlist, &player, PIANO_RET_OK,
                                            WAITRESS_RET_OK);
                        
						/* prevent race condition, mode must _not_ be FREED if
						 * thread has been started */
						player.mode = PLAYER_STARTING;
						/* start player */
						pthread_create (&playerThread, NULL, BarPlayerThread,
                                        &player);
					} /* end if audioUrl == NULL */
				} /* end if playlist != NULL */
			} /* end if curStation != NULL */
		}
        else
        {
            double timeTotalInterval = player.songDuration / 1000.0f;
            double timePlayed = player.songPlayed / 1000.0f;
			[self.nowPlaying setDuration:timeTotalInterval];
			[self.nowPlaying setCurrentTime:timePlayed];
			[self.nowPlaying setTimeLeft:timeTotalInterval-timePlayed];
            /*NSMutableDictionary *dict = [[self.nowPlaying mutableCopy] autorelease];
            [dict setObject:[NSNumber numberWithDouble:timePlayed] forKey:@"timeSoFar"];
            [dict setObject:[NSNumber numberWithDouble:timeTotalInterval] forKey:@"timeTotal"];
            [dict setObject:[NSNumber numberWithDouble:timeTotalInterval - timePlayed ] forKey:@"timeLeft" ];*/
            //self.nowPlaying = dict;
        }

        
    }
    
    [pool drain];
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
}

-(IBAction)playNextSong:(id)sender;
{
 	player.doQuit = 1;
	pthread_mutex_unlock (&player.pauseMutex);
}

-(void)stop;
{
    [backgroundPlayer cancel];
    [self playNextSong:nil];
}

@end
