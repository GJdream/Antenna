// Tesla.h
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

#import <Foundation/Foundation.h>

extern NSString * const TeslaChannelAddedNotification;
extern NSString * const TeslaChannelRemovedNotification;
extern NSString * const TeslaChannelNotificationDictKey;
extern NSString * const TeslaFilesSubDirectoryName;

#pragma mark - Tesla Channel Protocol

@protocol TeslaChannel <NSObject>

/**
 
 */
- (void)log:(NSDictionary *)payload;

@optional

- (void)logEvent:(NSString *)eventMessage;

@end

/**
 
 */
@interface Tesla : NSObject

/**
 
 */
@property (readonly, nonatomic, strong) NSMutableDictionary *defaultPayload;

/**
 
 */
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;

/**
 
 */
@property (readonly, nonatomic, strong) NSOperationQueue *operationQueue;

/**
 
 */
+ (instancetype)sharedLogger;

+ (NSString *)logTempDirectory;

///======================
/// @name Adding Channels
///======================

/**
 
 */
- (void)addChannel:(id <TeslaChannel>)channel forName:(NSString *)name;

/**
 
 */
- (void)removeChannelForName:(NSString *)name;

/**
 
 */
- (BOOL)channelExists:(NSString *)name;

/**
 
 */
- (id <TeslaChannel>)channelForName:(NSString *)name;

/**
 
 */
+ (NSArray *)pendingFiles;

/**
 
 */
- (void)addChannelWithURL:(NSURL *)URL method:(NSString *)method forName:(NSString *)name;

/**
 * @name logEventMessage
 * @param id messageOrPayload
 *
 * This is the _main_ log method for Tesla. It check and see
 * `[obj respondsToSelector:@selector(log:)]` to make sure that the channel obj
 * will call the delegate method `log`. Due to the confusing nature of method
 * names this should be refactored.
 *
 * @todo
 * We give a channel by name, but yet we log to all channels. This method should
 * ideally accept a payload and array of channels names. If not then what's the
 * point of having names or this _could_ be used as general message to just log
 * all channels
 */
- (void)logEventMessage:(id)messageOrPayload;

/**
 
 */
- (void)logEventMessage:(id)messageOrPayload forChannelNames:(NSArray *)names;

/**
 
 */
- (void)logEventMessage:(id)messageOrPayload forChannelName:(NSString *)name;

///===========================
/// @name Notification Logging
///===========================

/**
 
 */
- (void)startLoggingApplicationLifecycleNotifications;

/**
 
 */
- (void)startLoggingNotificationName:(NSString *)name;

/**

 */
- (void)startLoggingNotificationName:(NSString *)name
                              object:(id)object;

/**
 
 */
- (void)startLoggingNotificationName:(NSString *)name
                              object:(id)object
        constructingPayLoadFromBlock:(NSDictionary * (^)(NSNotification *notification))block;

/**
 
 */
- (void)stopLoggingNotificationName:(NSString *)name;

/**
 
 */
- (void)stopLoggingAllNotifications;


@end

