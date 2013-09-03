//
//  Antenna_Tests.m
//  Antenna Tests
//
//  Created by Cory D. Wiles on 9/3/13.
//  Copyright (c) 2013 Mattt Thompson. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "Antenna.h"

static NSString * const AntennaTestsExampleNotification = @"AntennaTestsExampleNotification";

@interface Antenna_Tests : SenTestCase

- (void)channelWasAddedNotification:(NSNotification *)aNotif;
- (void)channelWasRemovedNotification:(NSNotification *)aNotif;

@end

@implementation Antenna_Tests

- (void)setUp {
  
    [super setUp];
  
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(channelWasAddedNotification:)
                                                 name:AntennaChannelAddedNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(channelWasRemovedNotification:)
                                                 name:AntennaChannelRemovedNotification
                                               object:nil];

    [[Antenna sharedLogger] startLoggingApplicationLifecycleNotifications];
    [[Antenna sharedLogger] startLoggingNotificationName:AntennaTestsExampleNotification];
}

- (void)tearDown {

    [super tearDown];
  
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)test_000_Successfully_Add_Channel {
  
    [[Antenna sharedLogger] addChannelWithURL:[NSURL URLWithString:@"http://localhost:5000"]
                                       method:@"LOG"
                                      forName:@"defaultTestLog"];
}

- (void)test_001_Successfully_Remove_Channel {
    [[Antenna sharedLogger] removeChannelForName:@"defaultTestLog"];
}

#pragma mark - Notification Handlers

- (void)channelWasAddedNotification:(NSNotification *)aNotif {

  NSString *channelName = [aNotif userInfo][AntennaChannelNotificationDictKey];
  
  STAssertNotNil(channelName, @"Channel name can't be nil");
}

- (void)channelWasRemovedNotification:(NSNotification *)aNotif {
  
  NSString *deletedChannelName = [aNotif userInfo][AntennaChannelNotificationDictKey];
  NSString *errorMsg           = [NSString stringWithFormat:@"The channel (%@) should have been deleted", deletedChannelName];

  id<AntennaChannel> channelObj = [[Antenna sharedLogger] channelForName:deletedChannelName];

  STAssertNil(channelObj, errorMsg);
}

@end
