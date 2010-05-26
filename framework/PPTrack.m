//
//  PPTrack.m
//  pianobar
//
//  Created by Joshua Weinberg on 5/13/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PPTrack.h"


@implementation PPTrack
@synthesize title = _title;
@synthesize artist = _artist;
@synthesize album = _album;
@synthesize currentTime = _currentTime;
@synthesize duration = _duration;
@synthesize timeLeft = _timeLeft;
@synthesize artURL = _artURL;
@synthesize audioURL = _audioURL;
@synthesize itunesURL = _itunesURL;

- (id)initWithTitle:(NSString*)title artist:(NSString*)artist album:(NSString*)album artURL:(NSURL *)artURL audioURL:(NSURL *)audioURL itunesURL:(NSURL *)itunesURL;
{
	if ((self = [super init]))
	{
		_title = [title copy];
		_artist = [artist copy];
		_album = [album copy];
        _artURL = [artURL copy];
		_audioURL = [audioURL copy];
        _itunesURL = [itunesURL copy];
        NSLog(@"%@", _artURL);
	}
	return self;
}

+ (id)trackWithTitle:(NSString*)title artist:(NSString*)artist album:(NSString*)album artURL:(NSURL *)artURL audioURL:(NSURL *)audioURL itunesURL:(NSURL *)itunesURL;
{
    return [[[PPTrack alloc] initWithTitle:title artist:artist album:album artURL:artURL audioURL:audioURL itunesURL:itunesURL] autorelease];
}

- (void)dealloc;
{
	[_title release], _title = nil;
	[_artist release], _artist = nil;
	[_album release], _album = nil;
    [_artURL release], _artURL = nil;
	[_audioURL release], _audioURL = nil;
    [_itunesURL release], _itunesURL = nil;
	[super dealloc];
}

@end
