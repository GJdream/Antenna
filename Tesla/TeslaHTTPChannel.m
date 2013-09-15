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

  self.backGroundSession.urlString = [url.absoluteString copy];
  self.backGroundSession.apiKey = [[Tesla sharedLogger] apiKey];
  
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
  
  NSString * (^parseToJSON)(NSDictionary *dict) = ^ NSString *(NSDictionary *dict){

    NSString *jsonString = nil;
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    if (jsonData) {

      jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
      
    } else {
      
      NSLog(@"error parsing data: %@", error);
    }

    return jsonString;
  };
  
  NSString *jsonPayload = parseToJSON(payload);
  
  [self logEvent:jsonPayload];
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

#pragma mark - Task Cleanup Ops


/**
 * Delete finished tasks
 */

- (void)performTaskCleanup:(NSURLSessionTask *)task {
  
  if(!task) return;
  
  NSHTTPURLResponse * resp = (NSHTTPURLResponse *)task.response;
  NSLog(@"response status: %d",[resp statusCode]);
  
  if([resp statusCode] != 201) {
    // Leave in queue if bad insert?
    return;
  }
  
  NSFileManager * fm = [NSFileManager defaultManager];
  NSString      * path = task.taskDescription;
  NSURL         * url = [NSURL fileURLWithPath:path];
  NSError       * error = nil;
  
  if([fm fileExistsAtPath:[url path]]) {
    [fm removeItemAtPath:path error:&error];
    if (error) {
      NSLog(@"Error removing file (%@)",path);
    }
  }
}

#pragma mark - NSURLSession* Delegate Methods

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task needNewBodyStream:(void (^)(NSInputStream *bodyStream))completionHandler {
  NSLog(@"session: %@ task: %@", session, task);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
  NSLog(@"session didSendBodyData: %qi (of %qi)", bytesSent,totalBytesExpectedToSend);
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
  NSLog(@"did finish %@",[task.taskDescription lastPathComponent]);
  [self performTaskCleanup:task];
}

@end
