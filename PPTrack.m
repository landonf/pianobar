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

- (id)initWithTitle:(NSString*)title artist:(NSString*)artist album:(NSString*)album artURL:(NSString*)url audioURL:(NSURL *)audioURL;
{
	if ((self = [super init]))
	{
		_title = [title copy];
		_artist = [artist copy];
		_album = [album copy];
        _artURL = [url copy];
		_audioURL = [audioURL copy];
        NSLog(@"%@", _artURL);
	}
	return self;
}

+ (id)trackWithTitle:(NSString*)title artist:(NSString*)artist album:(NSString*)album artURL:(NSString*)url audioURL:(NSURL *)audioURL;
{
    return [[[PPTrack alloc] initWithTitle:title artist:artist album:album artURL:url audioURL:audioURL] autorelease];
}

- (void)dealloc;
{
	[_title release], _title = nil;
	[_artist release], _artist = nil;
	[_album release], _album = nil;
    [_artURL release], _artURL = nil;
	[_audioURL release], _audioURL = nil;
	[super dealloc];
}

@end
