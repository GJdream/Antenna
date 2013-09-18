//
//  TeslaHTTPChannel.h
//  Tesla Example
//
//  Created by Cory D. Wiles on 9/11/13.
//  Copyright (c) 2013 Mattt Thompson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Tesla.h"

@interface TeslaHTTPChannel : NSObject <TeslaChannel>

- (id)initWithURL:(NSURL *)url;

@end
