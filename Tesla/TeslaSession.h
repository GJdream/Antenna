//
//  TeslaSession.h
//  Tesla Example
//
//  Created by Cory D. Wiles on 9/10/13.
//  Copyright (c) 2013 Mattt Thompson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TeslaSession : NSObject

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, copy) NSString *urlString;

+ (instancetype)sharedSessionWithDelegate:(id <NSURLSessionDelegate>)delegate
                                    queue:(NSOperationQueue *)aQueue;

+ (instancetype)backgroundSessionWithDelegate:(id <NSURLSessionDelegate>)delegate;

- (void)sendFilesInBackground:(NSArray *)files;
@end
