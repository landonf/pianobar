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
	
	NSTimeInterval _duration;
	NSTimeInterval _currentTime;
	NSTimeInterval _timeLeft;
	
}

- (id)initWithTitle:(NSString*)title artist:(NSString*)artist album:(NSString*)album;
+ (id)trackWithTitle:(NSString*)title artist:(NSString*)artist album:(NSString*)album;

@property (nonatomic, readonly) NSString * title;
@property (nonatomic, readonly) NSString * artist;
@property (nonatomic, readonly) NSString * album;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) NSTimeInterval currentTime;
@property (nonatomic, assign) NSTimeInterval timeLeft;
@end
