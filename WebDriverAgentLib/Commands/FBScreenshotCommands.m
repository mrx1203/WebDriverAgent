/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBScreenshotCommands.h"
#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "XCUIDevice+FBHelpers.h"

@implementation FBScreenshotCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute GET:@"/screenshot"].withoutSession respondWithTarget:self action:@selector(handleGetScreenshot:)],
    [[FBRoute GET:@"/screenshot"] respondWithTarget:self action:@selector(handleGetScreenshot:)],
  ];
}


#pragma mark - Commands

+ (id<FBResponsePayload>)handleGetScreenshot:(FBRouteRequest *)request
{
  NSError *error;
  NSData *screenshotData = [[XCUIDevice sharedDevice] fb_screenshotWithError:&error];
  if (nil == screenshotData) {
    return FBResponseWithStatus([FBCommandStatus unableToCaptureScreenErrorWithMessage:error.description traceback:nil]);
  }
  CGFloat scale = request.parameters[@"scale"] ? (CGFloat)[request.parameters[@"scale"] doubleValue] : 1;
  if (scale<1){
    @try{
      @autoreleasepool{
        //double stime = [[NSDate date] timeIntervalSince1970];
        UIImage *img = [UIImage imageWithData:screenshotData];
        CGSize size = CGSizeMake((NSUInteger)img.size.width*scale,(NSUInteger)img.size.height*scale);
        CGContextRef context = UIGraphicsGetCurrentContext();
        UIGraphicsBeginImageContext(size);
        [img drawInRect:CGRectMake(0, 0, size.width, size.height)];
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        CGContextRelease(context);
        screenshotData = UIImageJPEGRepresentation(img, 0.1);
        //NSLog(@"--------%f",[[NSDate date] timeIntervalSince1970]-stime);
      }
    }@catch(NSException *e) {
      NSLog(@"%@",e);
    }
  }
  NSString *screenshot = [screenshotData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
  return FBResponseWithObject(screenshot);
}

@end
