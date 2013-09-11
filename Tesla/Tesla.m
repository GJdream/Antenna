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

static NSString * TemporaryDirectory() {
  
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

@interface TeslaStreamChannel : NSObject <TeslaChannel>
- (id)initWithOutputStream:(NSOutputStream *)outputStream;
@end

@interface TeslaHTTPChannel : NSObject <TeslaChannel>
- (id)initWithURL:(NSURL *)url
           method:(NSString *)method;
@end

#ifdef _COREDATADEFINES_H

@interface TeslaCoreDataChannel : NSObject <TeslaChannel>

- (id)initWithEntity:(NSEntityDescription *)entity
    messageAttribute:(NSAttributeDescription *)messageAttribute
  timestampAttribute:(NSAttributeDescription *)timestampAttribute
inManagedObjectContext:(NSManagedObjectContext *)context;

@end

#endif

#pragma mark -

@interface Tesla ()

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
  
  // Generate directory, if not already there
  NSError * error = nil;
  [[NSFileManager defaultManager] createDirectoryAtPath:TemporaryDirectory()
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:&error];
  if (error != nil) {
    NSLog(@"Error creating tmp log directory: %@", error);
  }

  return self;
}

+ (NSArray *)pendingFiles {

  NSError *error = nil;
  NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:TemporaryDirectory()
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

#pragma mark -

- (void)addChannelWithFilePath:(NSString *)path forName:(NSString *)name {
  [self addChannelWithOutputStream:[NSOutputStream outputStreamToFileAtPath:path append:YES] forName:name];
}

- (void)addChannelWithOutputStream:(NSOutputStream *)outputStream forName:(NSString *)name {

  TeslaStreamChannel *channel = [[TeslaStreamChannel alloc] initWithOutputStream:outputStream];
  
  [self addChannel:channel forName:name];
}

- (void)addChannelWithURL:(NSURL *)URL
                   method:(NSString *)method
                  forName:(NSString *)name {

  TeslaHTTPChannel *channel = [[TeslaHTTPChannel alloc] initWithURL:URL method:method];
  
  [self addChannel:channel forName:name];
}

#ifdef _COREDATADEFINES_H

- (void)addChannelWithEntity:(NSEntityDescription *)entity
            messageAttribute:(NSAttributeDescription *)messageAttribute
          timestampAttribute:(NSAttributeDescription *)timestampAttribute
      inManagedObjectContext:(NSManagedObjectContext *)context
                     forName:(NSString *)name {

  TeslaCoreDataChannel *channel = [[TeslaCoreDataChannel alloc] initWithEntity:entity
                                                              messageAttribute:messageAttribute
                                                            timestampAttribute:timestampAttribute
                                                        inManagedObjectContext:context];
  
  [self addChannel:channel forName:name];
}

#endif

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

#pragma mark -

- (void)log:(id)messageOrPayload {

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
  
    [self.channels enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
      [obj log:mutablePayload];
    }];
}

#pragma mark -

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

    [strongSelf log:payload];
  }];
}

- (void)stopLoggingNotificationName:(NSString *)name {
  [self.notificationCenter removeObserver:self name:name object:nil];
}

- (void)stopLoggingAllNotifications {
  [self.notificationCenter removeObserver:self];
}

@end

#pragma mark -

@interface TeslaStreamChannel ()

@property (readwrite, nonatomic, strong) NSOutputStream *outputStream;

@end

@implementation TeslaStreamChannel

@synthesize outputStream = _outputStream;

- (id)initWithOutputStream:(NSOutputStream *)outputStream {

  self = [super init];
  
  if (!self) {
    return nil;
  }

  self.outputStream = outputStream;
  
  [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
  [self.outputStream open];
  
  return self;
}

#pragma mark - TeslaChannel

- (void)log:(NSDictionary *)payload {

  NSData *data = [TeslaLogLineFromPayload(payload) dataUsingEncoding:NSUTF8StringEncoding];
  
  [self.outputStream write:[data bytes] maxLength:[data length]];
}

@end

#pragma mark -

@interface TeslaHTTPChannel ()<NSURLSessionDelegate>

@property (readwrite, nonatomic, copy) NSString *method;
@property (nonatomic, strong) TeslaSession *backGroundSession;

@end

@implementation TeslaHTTPChannel

- (id)initWithURL:(NSURL *)url method:(NSString *)method {

  self = [super init];
  
  if (!self) {
    return nil;
  }
  // Register for background notification
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(appDidEnterBackground)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];

  self.backGroundSession = [TeslaSession backgroundSessionWithDelegate:self];

  return self;
}

#pragma mark - TeslaChannel

// Write an event to file in tmp/tesla directory
- (void)logEvent:(NSString *)eventMessage {
  
  // Write file to tmp dir
  NSError *error;
  NSString *date = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                  dateStyle:NSDateFormatterFullStyle
                                                  timeStyle:NSDateFormatterFullStyle];
  
  NSString *fileName = [NSString stringWithFormat:@"log_%@.txt", date];
  NSString *filePath = [TemporaryDirectory() stringByAppendingPathComponent:fileName];
  
  BOOL success = [eventMessage writeToFile:filePath
                                atomically:YES
                                  encoding:NSUTF8StringEncoding
                                     error:&error];
  if(error) {
    NSLog(@"Error writing to file %@ %@",filePath,error);
  } else if (!success) {
    NSLog(@"Couldn't write to file");
  } else {
    NSLog(@"Logged %@ (%@)",eventMessage,filePath);
  }
}

- (void)log:(NSDictionary *)payload {
  
  /**
   * NSDictionary does have an instance method for writing to file, but does so 
   * via plist. Calling `description` method will return a string to write out
   * via txt file.
   */

  [self logEvent:payload.description];
}

#pragma mark - Background Notification

- (void)appDidEnterBackground {

  NSLog(@"App entered background");
  
  // Check for log files to send
  NSArray *pendingFiles = [Tesla pendingFiles];

  if ([pendingFiles count]) {
    
    NSLog(@"Sending files...");
    
    [self.backGroundSession sendFilesInBackground:pendingFiles];
  }
}

#pragma mark - NSURLSession* Delegate Methods

/**
 * These _might_ not be needed for our purposes
 */

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task needNewBodyStream:(void (^)(NSInputStream *bodyStream))completionHandler {
  NSLog(@"session: %@ task: %@", session, task);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
  NSLog(@"session only: %@", session);
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
  NSLog(@"did finish");
}

@end

#ifdef _COREDATADEFINES_H
@interface TeslaCoreDataChannel ()

@property (readwrite, nonatomic, strong) NSEntityDescription *entity;
@property (readwrite, nonatomic, strong) NSManagedObjectContext *context;
@property (readwrite, nonatomic, strong) NSAttributeDescription *messageAttribute;
@property (readwrite, nonatomic, strong) NSAttributeDescription *timestampAttribute;

@end

@implementation TeslaCoreDataChannel

@synthesize entity             = _entity;
@synthesize context            = _context;
@synthesize messageAttribute   = _messageAttribute;
@synthesize timestampAttribute = _timestampAttribute;

- (id)initWithEntity:(NSEntityDescription *)entity
    messageAttribute:(NSAttributeDescription *)messageAttribute
  timestampAttribute:(NSAttributeDescription *)timestampAttribute
inManagedObjectContext:(NSManagedObjectContext *)context {

  self = [super init];
  
  if (!self) {
    return nil;
  }

  self.entity             = entity;
  self.context            = context;
  self.messageAttribute   = messageAttribute;
  self.timestampAttribute = timestampAttribute;

  return self;
}

#pragma mark - TeslaChannel

- (void)log:(NSDictionary *)payload {

  [self.context performBlock:^{

    NSManagedObjectContext *entry = [NSEntityDescription insertNewObjectForEntityForName:self.entity.name inManagedObjectContext:self.context];
    
    [entry setValue:TeslaLogLineFromPayload(payload) forKey:self.messageAttribute.name];
    [entry setValue:[NSDate date] forKey:self.timestampAttribute.name];

    NSError *error = nil;

    if (![self.context save:&error]) {
      NSLog(@"Logging Error: %@", error);
    }
  }];
}

@end

#endif
