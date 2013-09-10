//
//  TeslaSession.m
//  Tesla Example
//
//  Created by Cory D. Wiles on 9/10/13.
//  Copyright (c) 2013 Mattt Thompson. All rights reserved.
//

#import "TeslaSession.h"

@interface TeslaSession()

@property (nonatomic, weak) NSOperationQueue *sessionQueue;
@property (nonatomic, weak) id <NSURLSessionDelegate> delegate;

@end

@implementation TeslaSession

+ (instancetype)sharedSessionWithDelegate:(id <NSURLSessionDelegate>)delegate
                                    queue:(NSOperationQueue *)aQueue {

  static TeslaSession *__sharedSession = nil;
  static dispatch_once_t oncePredicate;
  
  dispatch_once(&oncePredicate, ^{
    __sharedSession = [[self alloc] initWithDelegate:delegate withQueue:aQueue];
  });
  
  return __sharedSession;
}

- (instancetype)initWithDelegate:(id <NSURLSessionDelegate>)delegate withQueue:(NSOperationQueue *)queue {
  
  self = [super init];
  
  if (self) {
    
    _delegate     = delegate;
    _sessionQueue = queue;

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
    
    _session = [NSURLSession sessionWithConfiguration:sessionConfiguration
                                             delegate:self.delegate
                                        delegateQueue:self.sessionQueue];
    
    _session.sessionDescription = @"Testing upload of logging information";
  }
  
  return self;
}

@end
