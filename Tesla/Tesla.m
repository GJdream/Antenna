// Tesla.m
// 
// Copyright (c) 2013 Mattt Thompson
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "Tesla.h"
#import "TeslaSession.h"
#import "TeslaHTTPChannel.h"
#import <CoreData/CoreData.h>

typedef NSDictionary *(^TeslaPayloadConstructionBlock)(NSNotification *notification);

static char const *channelsThreadQueueName = "com.theforce.channels.queue";

static dispatch_queue_t _channelsThreadQueue;

NSString * const TeslaChannelAddedNotification   = @"TeslaChannelAddedNotification";
NSString * const TeslaChannelRemovedNotification = @"TeslaChannelRemovedNotification";
NSString * const TeslaChannelNotificationDictKey = @"channelName";
NSString * const TeslaFilesSubDirectoryName      = @"tesla";

static NSString * const TeslaLogFilePrefix = @"log_";

static NSString * TeslaLogLineFromPayload(NSDictionary *payload) {

  NSMutableArray *mutableComponents = [NSMutableArray arrayWithCapacity:[payload count]];
  
  [payload enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    [mutableComponents addObject:[NSString stringWithFormat:@"\"%@\"=\"%@\"", key, obj]];
  }];

  return [mutableComponents componentsJoinedByString:@" "];
}

#pragma mark -

@interface Tesla()

@property (readwrite, nonatomic, strong) NSMutableDictionary *channels;
@property (readwrite, nonatomic, strong) NSMutableDictionary *defaultPayload;
@property (readwrite, nonatomic, strong) NSOperationQueue *operationQueue;

@end

@implementation Tesla

@synthesize channels = _channels;

+ (void)initialize {
  _channelsThreadQueue = dispatch_queue_create(channelsThreadQueueName, DISPATCH_QUEUE_CONCURRENT);
}

+ (instancetype)sharedLogger {

  static id _sharedTesla = nil;
  static dispatch_once_t onceToken;
  
  dispatch_once(&onceToken, ^{
      _sharedTesla = [[self alloc] init];
  });

  return _sharedTesla;
}

- (id)init {

  self = [super init];
  
  if (!self) {
    return nil;
  }

  self.channels       = [NSMutableDictionary new];
  self.defaultPayload = [NSMutableDictionary dictionary];

  if ([[UIDevice currentDevice] respondsToSelector:@selector(identifierForVendor)]) {
    [self.defaultPayload setValue:[[[UIDevice currentDevice] identifierForVendor] UUIDString] forKey:@"uuid"];
  }

  [self.defaultPayload setValue:[[NSLocale currentLocale] localeIdentifier] forKey:@"locale"];
  [self.defaultPayload setValue:[[NSDate date] description] forKey:@"currentTimestamp"];

  self.notificationCenter = [NSNotificationCenter defaultCenter];
  self.operationQueue     = [[NSOperationQueue alloc] init];
  
  [Tesla logTempDirectory];

  return self;
}

+ (NSString *)logTempDirectory {
  
	static NSString *__tempPath = nil;
	static dispatch_once_t onceToken;
  
	dispatch_once(&onceToken, ^{
		__tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:TeslaFilesSubDirectoryName];
    
    NSFileManager *manager = [[NSFileManager alloc] init];
    
    NSError *error;
    
		[manager createDirectoryAtPath:__tempPath
		   withIntermediateDirectories:YES
                        attributes:nil
                             error:&error];
    
    if (error) {
      NSLog(@"error setting the temp directory: %@", error);
    }
	});
  
	return __tempPath;
}

+ (NSArray *)pendingFiles {

  NSError *error = nil;
  NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[Tesla logTempDirectory]
                                                                       error:&error];
  if (files == nil || ![files count] || error) {
    return nil;
  }
  
  return files;
}

- (void)setChannels:(NSMutableDictionary *)channels {
  
  dispatch_barrier_async(_channelsThreadQueue, ^{
      _channels = channels;
  });
}

- (NSMutableDictionary *)channels {

  __block NSMutableDictionary *__channels;
  
  dispatch_sync(_channelsThreadQueue, ^{
    __channels = _channels;
  });
  
  return __channels;
}

- (void)addChannelWithURL:(NSURL *)URL
                   method:(NSString *)method
                  forName:(NSString *)name {
  
  TeslaHTTPChannel *channel = [[TeslaHTTPChannel alloc] initWithURL:URL method:method];
  
  [self addChannel:channel forName:name];
}

- (void)addChannel:(id <TeslaChannel>)channel forName:(NSString *)name {

    /**
     * Has this channel already been added?
     */
    if ([self channelExists:name]) {
      return;
    }

    NSDictionary *notifInfo = @{TeslaChannelNotificationDictKey : name};
  
    self.channels[name] = channel;
  
    [[NSNotificationCenter defaultCenter] postNotificationName:TeslaChannelAddedNotification
                                                        object:nil
                                                      userInfo:notifInfo];
}

- (void)removeChannelForName:(NSString *)name {
  
    /**
     * Has this channel already been removed?
     */
    if (![self channelExists:name]) {
      return;
    }
  
    [self.channels removeObjectForKey:name];
  
    NSDictionary *notifInfo = @{TeslaChannelNotificationDictKey : name};
  
    [[NSNotificationCenter defaultCenter] postNotificationName:TeslaChannelRemovedNotification
                                                        object:nil
                                                      userInfo:notifInfo];
}

- (BOOL)channelExists:(NSString *)name {
  
  if ([self channelForName:name]) {
    return YES;
  }
  
  return NO;
}

- (id <TeslaChannel>)channelForName:(NSString *)name {

  id <TeslaChannel> channelObject = self.channels[name];
  
  return channelObject;
}

#pragma mark - Default log method

- (void)logEventMessage:(id)messageOrPayload {

  [self.channels enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
    [[Tesla sharedLogger] logEventMessage:messageOrPayload forChannelName:key];
  }];
}

- (void)logEventMessage:(id)messageOrPayload forChannelNames:(NSArray *)names {

  NSAssert(messageOrPayload != nil, @"messageOrPayload is required");
  NSAssert(names != nil, @"Log channels can't be nil");
  
  /**
   * Iterate over channel names so that we just log to them
   */
  
  [names enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSString *channelName, NSUInteger idx, BOOL *stop){
    [[Tesla sharedLogger] logEventMessage:messageOrPayload forChannelName:channelName];
  }];
}

- (void)logEventMessage:(id)messageOrPayload forChannelName:(NSString *)name {

  NSAssert(messageOrPayload != nil, @"messageOrPayload is required");
  NSAssert(name != nil, @"channel is required");
  
  id channelObj = self.channels[name];
  
  if (!channelObj) {
    return;
  }
  
  NSMutableDictionary *mutablePayload = nil;
  
  if ([messageOrPayload isKindOfClass:[NSDictionary class]]) {
    
    mutablePayload = [messageOrPayload mutableCopy];
    
  } else if (messageOrPayload) {
    
    mutablePayload = [NSMutableDictionary dictionaryWithObject:messageOrPayload forKey:@"message"];
  }
  
  [self.defaultPayload enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    
    if (obj && ![mutablePayload valueForKey:key]) {
      [mutablePayload setObject:obj forKey:key];
    }
  }];

  if ([channelObj conformsToProtocol:@protocol(TeslaChannel)]) {
    
    if ([channelObj respondsToSelector:@selector(log:)]) {
      
      [mutablePayload setObject:name forKey:@"channelName"];
      
      [channelObj log:mutablePayload];
      
    } else {
      
      NSLog(@"doesn't respond to protocol");
    }
  }
}

#pragma mark - Application Lifecycle Notifications

- (void)startLoggingApplicationLifecycleNotifications {
  
  NSArray *names = @[UIApplicationDidFinishLaunchingNotification,
                     UIApplicationDidEnterBackgroundNotification,
                     UIApplicationDidBecomeActiveNotification,
                     UIApplicationDidReceiveMemoryWarningNotification];

  for (NSString *name in names) {
    [self startLoggingNotificationName:name];
  }
}

- (void)startLoggingNotificationName:(NSString *)name {
  [self startLoggingNotificationName:name object:nil];
}

- (void)startLoggingNotificationName:(NSString *)name
                              object:(id)object {

  __weak __typeof(self)weakSelf = self;

  [self startLoggingNotificationName:name
                              object:nil
        constructingPayLoadFromBlock:^NSDictionary *(NSNotification *notification) {

    __strong __typeof(weakSelf)strongSelf = weakSelf;

    NSMutableDictionary *mutablePayload = [strongSelf.defaultPayload mutableCopy];
    
    if (notification.userInfo) {

      [notification.userInfo enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [mutablePayload setObject:obj forKey:key];
      }];
    }

    [mutablePayload setObject:name forKey:@"notification"];

    return mutablePayload;
  }];
}

- (void)startLoggingNotificationName:(NSString *)name
                              object:(id)object
        constructingPayLoadFromBlock:(TeslaPayloadConstructionBlock)block {

  __weak __typeof(self)weakSelf = self;

  [[NSNotificationCenter defaultCenter] addObserverForName:name
                                                    object:object
                                                     queue:self.operationQueue
                                                usingBlock:^(NSNotification *notification) {

    __strong __typeof(weakSelf)strongSelf = weakSelf;
    
    NSDictionary *payload = nil;
    
    if (block) {
      payload = block(notification);
    }

    [strongSelf logEventMessage:payload];
  }];
}

- (void)stopLoggingNotificationName:(NSString *)name {
  [self.notificationCenter removeObserver:self name:name object:nil];
}

- (void)stopLoggingAllNotifications {
  [self.notificationCenter removeObserver:self];
}

@end
