//
//  PPTrack.h
//  pianobar
//
//  Created by Joshua Weinberg on 5/13/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface PPTrack : NSObject {
	NSString * _title;
	NSString * _artist;
	NSString * _album;
	
    NSURL * _artURL;
	NSURL * _audioURL;
    NSURL * _itunesURL;
	NSTimeInterval _duration;
	NSTimeInterval _currentTime;
	NSTimeInterval _timeLeft;
	
}

- (id)initWithTitle:(NSString*)title artist:(NSString*)artist album:(NSString*)album artURL:(NSURL *)artURL audioURL:(NSURL *)audioURL itunesURL:(NSURL *)itunesURL;
+ (id)trackWithTitle:(NSString*)title artist:(NSString*)artist album:(NSString*)album artURL:(NSURL *)artURL audioURL:(NSURL *)audioURL itunesURL:(NSURL *)itunesURL;

@property (nonatomic, readonly) NSString * title;
@property (nonatomic, readonly) NSString * artist;
@property (nonatomic, readonly) NSString * album;
@property (nonatomic, readonly) NSURL * artURL;
@property (nonatomic, readonly) NSURL * audioURL;
@property (nonatomic, readonly) NSURL * itunesURL;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) NSTimeInterval currentTime;
@property (nonatomic, assign) NSTimeInterval timeLeft;
@end
