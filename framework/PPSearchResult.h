//
//  PPSearchResult.h
//  pianobar
//
//  Created by Matt Ball on 5/22/10.
//

#import <Cocoa/Cocoa.h>


@interface PPSearchResult : NSObject {
	NSString *_artist;
	NSString *_title;
	NSString *_musicID;
}

+ (PPSearchResult *)searchResultWithArtist:(NSString *)artist title:(NSString *)title musicID:(NSString *)musicID;

@property (nonatomic, copy, readonly) NSString *artist;
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *musicID;

@end
