// ViewController.m
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

#import "ViewController.h"

NSString * const AntennaExampleNotification = @"AntennaExampleNotification";

@implementation ViewController

#pragma mark - IBAction

- (IBAction)triggerNotification:(id)__unused sender {
  
  // testing only
  NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  NSUInteger len = 10;
  NSMutableString *randomString_key = [NSMutableString stringWithCapacity:len];
  NSMutableString *randomString_val = [NSMutableString stringWithCapacity:len];
  
  for (int i=0; i<len; i++) {
    [randomString_key appendFormat: @"%C", [letters characterAtIndex: arc4random() % [letters length]]];
    [randomString_val appendFormat: @"%C", [letters characterAtIndex: arc4random() % [letters length]]];
  }
  
  NSDictionary *notifInfo = @{randomString_key : randomString_val};
  
  [[NSNotificationCenter defaultCenter] postNotificationName:AntennaExampleNotification
                                                      object:nil
                                                    userInfo:notifInfo];
}

@end
