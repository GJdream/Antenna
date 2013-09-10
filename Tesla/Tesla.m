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
#import <CoreData/CoreData.h>

typedef NSDictionary *(^TeslaPayloadConstructionBlock)(NSNotification *notification);

static char const *channelsThreadQueueName = "com.theforce.channels.queue";

static dispatch_queue_t _channelsThreadQueue;

NSString * const TeslaChannelAddedNotification   = @"TeslaChannelAddedNotification";
NSString * const TeslaChannelRemovedNotification = @"TeslaChannelRemovedNotification";
NSString * const TeslaChannelNotificationDictKey = @"channelName";

static NSString * TeslaLogLineFromPayload(NSDictionary *payload) {

  NSMutableArray *mutableComponents = [NSMutableArray arrayWithCapacity:[payload count]];
  
  [payload enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    [mutableComponents addObject:[NSString stringWithFormat:@"\"%@\"=\"%@\"", key, obj]];
  }];

  return [mutableComponents componentsJoinedByString:@" "];
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

  self.notificationCenter = [NSNotificationCenter defaultCenter];
  self.operationQueue     = [[NSOperationQueue alloc] init];

  return self;
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

@end

@implementation TeslaHTTPChannel

- (id)initWithURL:(NSURL *)url method:(NSString *)method {

  self = [super init];
  
  if (!self) {
    return nil;
  }

  return self;
}

#pragma mark - TeslaChannel

- (void)log:(NSDictionary *)payload {

  /**
   * Basic implementation of saving log information to backend using NSURLSession
   * This is setup for localhost at the moment but will be configurable at a 
   * later date.
   */

  NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
  
  sessionConfiguration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
  
  /**
   * @todo
   * Need to create custom background queue to pass in
   */

  NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration
                                                        delegate:self
                                                   delegateQueue:[NSOperationQueue mainQueue]];
  
  session.sessionDescription = @"Testing upload of logging information";

  //NSData *data = [TeslaLogLineFromPayload(payload) dataUsingEncoding:NSUTF8StringEncoding];
  
  NSError * error = nil;
  NSData * jsonData = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:&error];
  if(error) {
    NSLog(@"error creating jsonData");
  }
  
  NSAssert(jsonData, @"Data can't be nil");
    
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:5000/items"]];
  
  request.HTTPMethod = @"POST";
  [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
  
  NSURLSessionUploadTask *uploadTask = [session uploadTaskWithRequest:request
                                                             fromData:jsonData
                                                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
  
    NSString *str = [[NSString alloc] initWithData:data
                                          encoding:NSUTF8StringEncoding];

    NSLog(@"response: %@ error: %@ body: %@", response, error, str);
  }];

  uploadTask.taskDescription = @"POSTing log item";
  
  [uploadTask resume];
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
