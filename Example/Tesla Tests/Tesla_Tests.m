//
//  Tesla_Tests.m
//  Tesla Tests
//
//  Created by Cory D. Wiles on 9/3/13.
//  Copyright (c) 2013 Mattt Thompson. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "Tesla.h"

static NSString * const TeslaTestsExampleNotification = @"TeslaTestsExampleNotification";

@interface Tesla_Tests : SenTestCase

- (void)channelWasAddedNotification:(NSNotification *)aNotif;
- (void)channelWasRemovedNotification:(NSNotification *)aNotif;

@end

@implementation Tesla_Tests

- (void)setUp {
  
    [super setUp];
  
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(channelWasAddedNotification:)
                                                 name:TeslaChannelAddedNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(channelWasRemovedNotification:)
                                                 name:TeslaChannelRemovedNotification
                                               object:nil];

    [[Tesla sharedLogger] startLoggingApplicationLifecycleNotifications];
    [[Tesla sharedLogger] startLoggingNotificationName:TeslaTestsExampleNotification];
}

- (void)tearDown {

    [super tearDown];
  
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)test_000_Successfully_Add_Channel {
  
    [[Tesla sharedLogger] addChannelWithURL:[NSURL URLWithString:@"http://localhost:5000"]
                                       method:@"LOG"
                                      forName:@"defaultTestLog"];
}

- (void)test_001_Successfully_Remove_Channel {
    [[Tesla sharedLogger] removeChannelForName:@"defaultTestLog"];
}

#pragma mark - Notification Handlers

- (void)channelWasAddedNotification:(NSNotification *)aNotif {

  NSString *channelName = [aNotif userInfo][TeslaChannelNotificationDictKey];
  
  STAssertNotNil(channelName, @"Channel name can't be nil");
}

- (void)channelWasRemovedNotification:(NSNotification *)aNotif {
  
  NSString *deletedChannelName = [aNotif userInfo][TeslaChannelNotificationDictKey];
  NSString *errorMsg           = [NSString stringWithFormat:@"The channel (%@) should have been deleted", deletedChannelName];

  id<TeslaChannel> channelObj = [[Tesla sharedLogger] channelForName:deletedChannelName];

  STAssertNil(channelObj, errorMsg);
}

@end
