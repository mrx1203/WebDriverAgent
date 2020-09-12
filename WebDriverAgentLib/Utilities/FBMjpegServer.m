/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBMjpegServer.h"

#import <mach/mach_time.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import "FBApplication.h"
#import "FBConfiguration.h"
#import "FBLogger.h"
#import "XCTestManager_ManagerInterface-Protocol.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCUIScreen.h"
#import "FBImageIOScaler.h"

#import "FBImageUtils.h"
#import "XCAXClient_iOS.h"
#import "FBMacros.h"

static const NSTimeInterval SCREENSHOT_TIMEOUT = 0.5;
static const NSUInteger MAX_FPS = 60;

static NSString *const SERVER_NAME = @"WDA MJPEG Server";
static const char *QUEUE_NAME = "JPEG Screenshots Provider Queue";
static long count = 0;

@interface FBMjpegServer()

@property (nonatomic, readonly) dispatch_queue_t backgroundQueue;
@property (nonatomic, readonly) NSMutableArray<GCDAsyncSocket *> *listeningClients;
@property (nonatomic, readonly) mach_timebase_info_data_t timebaseInfo;
@property (nonatomic, readonly) FBImageIOScaler *imageScaler;

@property (nonatomic) double startTime;
@property (nonatomic) double totalbytes;
@end


@implementation FBMjpegServer

- (instancetype)init
{
  if ((self = [super init])) {
    _listeningClients = [NSMutableArray array];
    dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
    _backgroundQueue = dispatch_queue_create(QUEUE_NAME, queueAttributes);
    mach_timebase_info(&_timebaseInfo);
    dispatch_async(_backgroundQueue, ^{
      [self streamScreenshot];
    });
    _imageScaler = [[FBImageIOScaler alloc] init];
  }
  self.startTime = [[NSDate date] timeIntervalSince1970];
  self.totalbytes = 0;
  return self;
}

- (void)scheduleNextScreenshotWithInterval:(uint64_t)timerInterval timeStarted:(uint64_t)timeStarted
{
  uint64_t timeElapsed = mach_absolute_time() - timeStarted;
  int64_t nextTickDelta = timerInterval - timeElapsed * self.timebaseInfo.numer / self.timebaseInfo.denom;
  if (nextTickDelta > 0) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, nextTickDelta), self.backgroundQueue, ^{
      [self streamScreenshot];
    });
  } else {
    // Try to do our best to keep the FPS at a decent level
    dispatch_async(self.backgroundQueue, ^{
      [self streamScreenshot];
    });
  }
}

- (void)streamScreenshot
{
  if (![self.class canStreamScreenshots]) {
    [FBLogger log:@"MJPEG server cannot start because the current iOS version is not supported"];
    return;
  }

  NSUInteger framerate = FBConfiguration.mjpegServerFramerate;
  uint64_t timerInterval = (uint64_t)(1.0 / ((0 == framerate || framerate > MAX_FPS) ? MAX_FPS : framerate) * NSEC_PER_SEC);
  uint64_t timeStarted = mach_absolute_time();
  @synchronized (self.listeningClients) {
    if (0 == self.listeningClients.count) {
      [self scheduleNextScreenshotWithInterval:timerInterval timeStarted:timeStarted];
      return;
    }
  }

  __block NSData *screenshotData = nil;

  CGFloat scalingFactor = [FBConfiguration mjpegScalingFactor] / 100.0f;
  //BOOL usesScaling = fabs(FBMaxScalingFactor - scalingFactor) > DBL_EPSILON;
  //NSLog(@"--------framerate=%lu, scaleingFactor=%f",(unsigned long)framerate,scalingFactor);
  //CGFloat compressionQuality = FBConfiguration.mjpegServerScreenshotQuality / 100.0f;
  // If scaling is applied we perform another JPEG compression after scaling
  // To get the desired compressionQuality we need to do a lossless compression here
  CGFloat screenshotCompressionQuality = FBMaxCompressionQuality;//usesScaling ? FBMaxCompressionQuality : compressionQuality;

  id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  if (SYSTEM_VERSION_LESS_THAN(@"11.0")){
    id xcScreen = NSClassFromString((@"XCUIScreen"));
    if(xcScreen){
      screenshotData = [xcScreen valueForKeyPath:@"mainScreen.screenshot.PNGRepresentation"];
    }
    else{
      screenshotData = [[XCAXClient_iOS sharedClient] screenshotData];
    }
    //UIImage *img = [UIImage imageWithData:screenshotData];
    //screenshotData = UIImageJPEGRepresentation(img, 0.1);
    dispatch_semaphore_signal(sem);
  }
  else{
    [proxy _XCT_requestScreenshotOfScreenWithID:[[XCUIScreen mainScreen] displayID]
                                         withRect:CGRectNull
                                              uti:(__bridge id)kUTTypeJPEG
                               compressionQuality:screenshotCompressionQuality
                                        withReply:^(NSData *data, NSError *error) {
      if (error != nil) {
        [FBLogger logFmt:@"Error taking screenshot: %@", [error description]];
      }
      screenshotData = data;
      dispatch_semaphore_signal(sem);
    }];
  }
  dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SCREENSHOT_TIMEOUT * NSEC_PER_SEC)));
  if (nil == screenshotData) {
    [self scheduleNextScreenshotWithInterval:timerInterval timeStarted:timeStarted];
    return;
  }
  @try{
    @autoreleasepool{
      //double stime = [[NSDate date] timeIntervalSince1970];
      UIImage *img = [UIImage imageWithData:screenshotData];
      CGSize size = CGSizeMake((NSUInteger)img.size.width*scalingFactor,(NSUInteger)img.size.height*scalingFactor);
      CGContextRef context = UIGraphicsGetCurrentContext();
      UIGraphicsBeginImageContext(size);
      [img drawInRect:CGRectMake(0, 0, size.width, size.height)];
      img = UIGraphicsGetImageFromCurrentImageContext();
      UIGraphicsEndImageContext();
      CGContextRelease(context);
      screenshotData = UIImageJPEGRepresentation(img, 0.01);
      //NSLog(@"--------%f",[[NSDate date] timeIntervalSince1970]-stime);
      [self sendScreenshot:screenshotData];
    }
  }@catch(NSException *e) {
    NSLog(@"%@",e);
  }
  [self scheduleNextScreenshotWithInterval:timerInterval timeStarted:timeStarted];
}

- (void)sendScreenshot:(NSData *)screenshotData {
  //NSString *chunkHeader = [NSString stringWithFormat:@"--BoundaryString\r\nContent-type: image/jpg\r\nContent-Length: %@\r\n\r\n", @(screenshotData.length)];
  UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
  @try {
    FBApplication *systemApp = FBApplication.fb_activeApplication;
    orientation = systemApp.interfaceOrientation;
  }@catch(NSException *e) {
    NSLog(@"%@",e);
  }
  NSString *chunkHeader = [NSString stringWithFormat:@"--BoundaryString--Content-type: image/jpg--=%ld=",(long)orientation];
  NSMutableData *chunk = [[chunkHeader dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
  [chunk appendData:screenshotData];
  self.totalbytes += screenshotData.length;
  count+=1;
  double losttime = [[NSDate date] timeIntervalSince1970]-self.startTime;
  if(losttime>=1){
    //NSLog(@"===================framerate is %f, total bytes is %f",count/losttime,self.totalbytes/1024);
    self.totalbytes = 0;
    count = 0;
    self.startTime = [[NSDate date] timeIntervalSince1970];
  }
  //[chunk appendData:(id)[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
  @synchronized (self.listeningClients) {
    for (GCDAsyncSocket *client in self.listeningClients) {
      [client writeData:chunk withTimeout:-1 tag:0];
    }
  }
}

+ (BOOL)canStreamScreenshots
{
  static dispatch_once_t onceCanStream;
  static BOOL result;
  dispatch_once(&onceCanStream, ^{
    result = [(NSObject *)[FBXCTestDaemonsProxy testRunnerProxy] respondsToSelector:@selector(_XCT_requestScreenshotOfScreenWithID:withRect:uti:compressionQuality:withReply:)];
  });
  if(!result){
    id xcScreen = NSClassFromString((@"XCUIScreen"));
    if(xcScreen){
      result = [xcScreen valueForKeyPath:@"mainScreen.screenshot.PNGRepresentation"];
    }
    else{
      result = [[XCAXClient_iOS sharedClient] screenshotData];
    }
  }
  return result;
}

- (void)didClientConnect:(GCDAsyncSocket *)newClient
{
  [FBLogger logFmt:@"Got screenshots broadcast client connection at %@:%d", newClient.connectedHost, newClient.connectedPort];
  // Start broadcast only after there is any data from the client
  [newClient readDataWithTimeout:-1 tag:0];
}

- (void)didClientSendData:(GCDAsyncSocket *)client
{
  @synchronized (self.listeningClients) {
    if ([self.listeningClients containsObject:client]) {
      return;
    }
  }

  [FBLogger logFmt:@"Starting screenshots broadcast for the client at %@:%d", client.connectedHost, client.connectedPort];
  //NSString *streamHeader = [NSString stringWithFormat:@"HTTP/1.0 200 OK\r\nServer: %@\r\nConnection: close\r\nMax-Age: 0\r\nExpires: 0\r\nCache-Control: no-cache, private\r\nPragma: no-cache\r\nContent-Type: multipart/x-mixed-replace; boundary=--BoundaryString\r\n\r\n", SERVER_NAME];
  //[client writeData:(id)[streamHeader dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
  @synchronized (self.listeningClients) {
    [self.listeningClients addObject:client];
  }
}

- (void)didClientDisconnect:(GCDAsyncSocket *)client
{
  @synchronized (self.listeningClients) {
    [self.listeningClients removeObject:client];
  }
  [FBLogger log:@"Disconnected a client from screenshots broadcast"];
}

@end
