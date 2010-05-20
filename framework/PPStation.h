//
//  PPStation.h
//  pianobar
//
//  Created by Joshua Weinberg on 5/13/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface PPStation : NSObject {
	NSString * _name;
	NSNumber * _stationID;
}	

- (id)initWithName:(NSString*)name stationID:(NSUInteger)stationID;
+ (id)stationWithName:(NSString*)name stationID:(NSUInteger)stationID;

@property (nonatomic, readonly) NSString * name;
@property (nonatomic, readonly) NSNumber * stationID;

@end
