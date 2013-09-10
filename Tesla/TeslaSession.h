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

+ (instancetype)sharedSessionWithDelegate:(id <NSURLSessionDelegate>)delegate
                                    queue:(NSOperationQueue *)aQueue;

@end
