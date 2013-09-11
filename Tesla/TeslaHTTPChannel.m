//
//  TeslaHTTPChannel.m
//  Tesla Example
//
//  Created by Cory D. Wiles on 9/11/13.
//  Copyright (c) 2013 Mattt Thompson. All rights reserved.
//

#import "TeslaHTTPChannel.h"
#import "TeslaSession.h"

@interface TeslaHTTPChannel()<NSURLSessionDelegate>

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

#pragma mark - TeslaChannel Protocol Methods

// Write an event to file in tmp/tesla directory
- (void)logEvent:(NSString *)eventMessage {
  
  // Write file to tmp dir
  NSError *error;
  NSString *date = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                  dateStyle:NSDateFormatterFullStyle
                                                  timeStyle:NSDateFormatterFullStyle];
  
  NSString *fileName = [NSString stringWithFormat:@"log_%@.txt", date];
  NSString *filePath = [[Tesla logTempDirectory] stringByAppendingPathComponent:fileName];
  
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
