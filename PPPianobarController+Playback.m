//
//  PPPianoBarController+Playback.m
//  pianobar
//
//  Created by Josh Weinberg on 5/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PPPianobarController+Playback.h"
#import "mac_piano.h"
#import "piano.h"
#import "PPTrack.h"

@implementation PPPianobarController (Playback)

- (void)playSong;
{    
    //Figure out the new track
    self.nowPlaying = [PPTrack trackWithTitle:[NSString stringWithUTF8String:playlist->title]
                                       artist:[NSString stringWithUTF8String:playlist->artist] 
                                        album:[NSString stringWithUTF8String:playlist->album]];
    
    if (playlist->audioUrl == NULL) 
    {
        BarUiMsg (MSG_ERR, "Invalid song url.\n");
    }
    else 
    {
        // setup player
        memset (&player, 0, sizeof (player));
        
        WaitressInit (&player.waith);
        WaitressSetUrl (&player.waith, playlist->audioUrl);
        
        player.gain = playlist->fileGain;
        player.audioFormat = playlist->audioFormat;
        
        // throw event
        BarUiStartEventCmd (&settings, "songstart", curStation,
                            playlist, &player, PIANO_RET_OK,
                            WAITRESS_RET_OK);
        
        // prevent race condition, mode must _not_ be FREED if
        // thread has been started
        player.mode = PLAYER_STARTING;
        // start player
        pthread_create (&playerThread, NULL, BarPlayerThread,
                        &player);
    }
}

- (void)fetchPlaylist;
{
    PianoReturn_t pRet;
    WaitressReturn_t wRet;
    PianoRequestDataGetPlaylist_t reqData;
    reqData.station = curStation;
    reqData.format = settings.audioFormat;
    
    BarUiMsg (MSG_INFO, "Receiving new playlist... ");
    if (!BarUiPianoCall (&ph, PIANO_REQUEST_GET_PLAYLIST,
                         &waith, &reqData, &pRet, &wRet)) 
    {
        curStation = NULL;
    }
    else 
    {
        playlist = reqData.retPlaylist;
        if (playlist == NULL) 
        {
            BarUiMsg (MSG_INFO, "No tracks left.\n");
            curStation = NULL;
        }
    }
    BarUiStartEventCmd (&settings, "stationfetchplaylist",
                        curStation, playlist, &player, pRet, wRet);

}

- (void)updateHistory;
{
    if (settings.history != 0)
    {
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
        while (i < settings.history && tmpSong != NULL) 
        {
            tmpSong = tmpSong->next;
            ++i;
        }
        /* if too many songs in history... */
        if (tmpSong != NULL) 
        {
            PianoSong_t *delSong = tmpSong->next;
            tmpSong->next = NULL;
            if (delSong != NULL) 
            {
                PianoDestroyPlaylist (delSong);
            }
        }
    } 
    else 
    {
        /* don't keep history */
        playlist = playlist->next;
    }
}

- (void)finishSong;
{
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
@end
