//
//  PPSearchResult.m
//  pianobar
//
//  Created by Matt Ball on 5/22/10.
//

#import "PPSearchResult.h"

@interface PPSearchResult ()
@property (nonatomic, copy, readwrite) NSString *artist;
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, copy, readwrite) NSString *musicID;
@end

@implementation PPSearchResult

@synthesize artist=_artist, title=_title, musicID=_musicID;

+ (PPSearchResult *)searchResultWithArtist:(NSString *)artist title:(NSString *)title musicID:(NSString *)musicID
{
	PPSearchResult *result = [[PPSearchResult alloc] init];
	result.artist = artist;
	result.title = title;
	result.musicID = musicID;
	return [result autorelease];
}

- (void)dealloc
{
	[_artist release];
	_artist = nil;
	[_title release];
	_title = nil;
	[_musicID release];
	_musicID = nil;
	[super dealloc];
}

@end
