//
//  PPStation.m
//  pianobar
//
//  Created by Joshua Weinberg on 5/13/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PPStation.h"


@implementation PPStation
@synthesize name = _name;
@synthesize stationID = _stationID;

- (id)initWithName:(NSString*)name stationID:(NSUInteger)stationID;
{
	if ((self = [super init]))
	{
		_name = [name copy];
		_stationID = [[NSNumber alloc] initWithInteger:stationID];
	}
	return self;
}

+ (id)stationWithName:(NSString*)name stationID:(NSUInteger)stationID;
{
	return [[[PPStation alloc] initWithName:name stationID:stationID] autorelease];
}

- (void)dealloc;
{
	[_name release], _name = nil;
	[_stationID release], _stationID = nil;
	[super dealloc];
}

@end
