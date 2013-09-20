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

typedef NSDictionary *(^TeslaPayloadConstructionBlock)(NSNotification *notification);

extern NSString * const TeslaChannelAddedNotification;
extern NSString * const TeslaChannelRemovedNotification;
extern NSString * const TeslaChannelNotificationDictKey;
extern NSString * const TeslaFilesSubDirectoryName;
extern NSString * const TeslaEventTypeException;

#pragma mark - Tesla Channel Protocol

@protocol TeslaChannel <NSObject>

/**
 * Should perform transformation of dictionary data into a json string and passes it to
 * logEvent:
 *
 * @see logEvent:
 */

- (void)log:(NSDictionary *)payload;

@optional

/**
 * Should log the string to whatever medium that the class wants
 */

- (void)logEvent:(NSString *)eventMessage;

@end

/**
 * An instance of Tesla provides the gateway to centralized event logging.
 * After registering an adapter (any class that conforms to TeslaChannel) 
 * all the user has to do is then call any of the logEventMessage* methods.
 *
 * There is built in support for application lifecycle notifications.
 */

@interface Tesla : NSObject

/**
 * Standard key/value pairs that are added to the log. These include:
 * - uuid
 * - locale
 * - currentTimestamp
 * - channelName
 */

@property (readonly, nonatomic, strong) NSMutableDictionary *defaultPayload;

/**
 * System notification center
 */

@property (nonatomic, strong) NSNotificationCenter *notificationCenter;

/**
 * Operation queue that notifications are returned on
 */

@property (readonly, nonatomic, strong) NSOperationQueue *operationQueue;

/**
 * Api Key used to 'authenticate' a Tesla instance to a backend
 */

@property (nonatomic, copy) NSString *apiKey;


/**
 * Salesforce user id. This should be reset if the logged in user changes.
 */

@property (nonatomic, copy) NSString *userId;


/**
 * Default URL to which all logged events will be POSTed
 */

@property (nonatomic, copy) NSString *defaultURL;

/**
 * Singleton instance of Tesla class
 * @return Tesla
 */

+ (instancetype)sharedLogger;

/**
 * Class method that returns the path to the log directory for Tesla.
 * This is subdirectory inside of /tmp so it is never backed up to iTunes or 
 * iCloud.
 *
 * @return NSString
 */

+ (NSString *)logTempDirectory;


/**
 * Adds channel to list of avaiable channels that can be logged to. The name of the 
 * channel is the key in the channels dictionary.
 *
 * @param id object that conforms to the TeslaChannel protocol
 * @param string name of the channel
 */

- (void)addChannel:(id <TeslaChannel>)channel forName:(NSString *)name;

/**
 * Removes channel from list of avaiable channels that can be logged to. The name of the
 * channel is the key in the channels dictionary.
 *
 * @param string name of the channel to add
 */

- (void)removeChannelForName:(NSString *)name;

/**
 * Checks for channel existance
 *
 * @return BOOL
 * @param string name of the channel to remove
 */
- (BOOL)channelExists:(NSString *)name;

/**
 * Channel object for a given name
 *
 * @return id channel that conforms to TeslaChannel protocol
 * @param string name of channel
 */

- (id <TeslaChannel>)channelForName:(NSString *)name;

/**
 * Iterates over the Tesla temp directory and returns list of all the files.
 *
 * @return NSArray
 */

+ (NSArray *)pendingFiles;

/**
 * Adds a channel that will connect with url. This is usually used inconjunction 
 * with a webservices, but could be file url.
 *
 * @param nsurl url to resource
 * @param string name of channel to "write" to
 */

- (void)addChannelWithURL:(NSURL *)URL forName:(NSString *)name;


/**
 * This is the default log method for the shared Tesla instance.
 *
 * @param id NSDictionary or string that should be logged
 * @param string eventType sets channel parameter in the default payload. This
 * should be set if you want to search logs for a certain type of event
 */

- (void)logEventMessage:(id)messageOrPayload forEventType:(NSString*)eventType;


/**
 * This is the _main_ log method for Tesla. It check and see
 * `[obj respondsToSelector:@selector(log:)]` to make sure that the channel obj
 * will call the delegate method `log`. Due to the confusing nature of method
 * names this should be refactored.
 *
 * @param id object or NSDictionary that should be logged
 */

- (void)logEventMessage:(id)messageOrPayload;

/**
 * This is the _main_ log method for Tesla. It check and see
 * `[obj respondsToSelector:@selector(log:)]` to make sure that the channel obj
 * will call the delegate method `log`. Due to the confusing nature of method
 * names this should be refactored.
 *
 * @param id messageOrPayload
 * @param nsarray list of channel names
 */

- (void)logEventMessage:(id)messageOrPayload forChannelNames:(NSArray *)names;

/**
 * This is the _main_ log method for Tesla. It check and see
 * `[obj respondsToSelector:@selector(log:)]` to make sure that the channel obj
 * will call the delegate method `log`. Due to the confusing nature of method
 * names this should be refactored.
 *
 * @param id messageOrPayload
 * @param string channel name
 */

- (void)logEventMessage:(id)messageOrPayload forChannelName:(NSString *)name;

/**
 * Method that kicks off logging for app delegate lifecycle notifications
 */

- (void)startLoggingApplicationLifecycleNotifications;

/**
 * Method that kicks off logging for app delegate lifecycle notifications for a 
 * given name
 *
 * @param string Notification name
 */

- (void)startLoggingNotificationName:(NSString *)name;

/**
 * Method that kicks off logging for app delegate lifecycle notifications for a
 * given name and object
 *
 * @param string Notification name
 * @param object
 */

- (void)startLoggingNotificationName:(NSString *)name object:(id)object;

/**
 * Method that kicks off logging for app delegate lifecycle notifications for a
 * given name, object and notification payload
 *
 * @param string Notification name
 * @param object
 * @param TeslaPayloadConstructionBlock returns an NSDictionary
 */

- (void)startLoggingNotificationName:(NSString *)name
                              object:(id)object
        constructingPayLoadFromBlock:(TeslaPayloadConstructionBlock)block;

/**
 * Removes notification for a given name
 *
 * @param string name of notification
 */

- (void)stopLoggingNotificationName:(NSString *)name;

/**
 * Removes all notifications
 */

- (void)stopLoggingAllNotifications;


@end

