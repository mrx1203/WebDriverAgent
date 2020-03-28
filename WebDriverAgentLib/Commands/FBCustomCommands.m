/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBCustomCommands.h"

#import <XCTest/XCUIDevice.h>

#import "FBApplication.h"
#import "FBConfiguration.h"
#import "FBExceptionHandler.h"
#import "FBPasteboard.h"
#import "FBResponsePayload.h"
#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBRunLoopSpinner.h"
#import "FBScreen.h"
#import "FBSession.h"
#import "FBXCodeCompatibility.h"
#import "FBSpringboardApplication.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIDevice+FBHelpers.h"
#import "XCUIElement.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElementQuery.h"
#import "FBUnattachedAppLauncher.h"

//#import <dlfcn.h>
//#include <CoreTelephony/CTCellularData.h>

@implementation FBCustomCommands

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute POST:@"/timeouts"] respondWithTarget:self action:@selector(handleTimeouts:)],
    [[FBRoute POST:@"/wda/homescreen"].withoutSession respondWithTarget:self action:@selector(handleHomescreenCommand:)],
    [[FBRoute POST:@"/wda/deactivateApp"] respondWithTarget:self action:@selector(handleDeactivateAppCommand:)],
    [[FBRoute POST:@"/wda/keyboard/dismiss"] respondWithTarget:self action:@selector(handleDismissKeyboardCommand:)],
    [[FBRoute POST:@"/wda/lock"].withoutSession respondWithTarget:self action:@selector(handleLock:)],
    [[FBRoute POST:@"/wda/lock"] respondWithTarget:self action:@selector(handleLock:)],
    [[FBRoute POST:@"/wda/unlock"].withoutSession respondWithTarget:self action:@selector(handleUnlock:)],
    [[FBRoute POST:@"/wda/unlock"] respondWithTarget:self action:@selector(handleUnlock:)],
    [[FBRoute GET:@"/wda/locked"].withoutSession respondWithTarget:self action:@selector(handleIsLocked:)],
    [[FBRoute GET:@"/wda/locked"] respondWithTarget:self action:@selector(handleIsLocked:)],
    [[FBRoute GET:@"/wda/screen"] respondWithTarget:self action:@selector(handleGetScreen:)],
    [[FBRoute GET:@"/wda/activeAppInfo"] respondWithTarget:self action:@selector(handleActiveAppInfo:)],
    [[FBRoute GET:@"/wda/activeAppInfo"].withoutSession respondWithTarget:self action:@selector(handleActiveAppInfo:)],
#if !TARGET_OS_TV // tvOS does not provide relevant APIs
    [[FBRoute POST:@"/wda/setPasteboard"] respondWithTarget:self action:@selector(handleSetPasteboard:)],
    [[FBRoute POST:@"/wda/getPasteboard"] respondWithTarget:self action:@selector(handleGetPasteboard:)],
    [[FBRoute GET:@"/wda/batteryInfo"] respondWithTarget:self action:@selector(handleGetBatteryInfo:)],
#endif
    [[FBRoute POST:@"/wda/pressButton"] respondWithTarget:self action:@selector(handlePressButtonCommand:)],
    [[FBRoute POST:@"/wda/siri/activate"] respondWithTarget:self action:@selector(handleActivateSiri:)],
    [[FBRoute POST:@"/wda/apps/launchUnattached"].withoutSession respondWithTarget:self action:@selector(handleLaunchUnattachedApp:)],
    [[FBRoute GET:@"/wda/device/info"] respondWithTarget:self action:@selector(handleGetDeviceInfo:)],
    //[[FBRoute GET:@"/wda/getWeaknetInfo"].withoutSession respondWithTarget:self action:@selector(handleGetWeakNetInfo:)],
  ];
}


#pragma mark - Commands

+ (id<FBResponsePayload>)handleHomescreenCommand:(FBRouteRequest *)request
{
  NSError *error;
  if (![[XCUIDevice sharedDevice] fb_goToHomescreenWithError:&error]) {
    return FBResponseWithStatus([FBCommandStatus unknownErrorWithMessage:error.description
                                                               traceback:nil]);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleDeactivateAppCommand:(FBRouteRequest *)request
{
  NSNumber *requestedDuration = request.arguments[@"duration"];
  NSTimeInterval duration = (requestedDuration ? requestedDuration.doubleValue : 3.);
  NSError *error;
  if (![request.session.activeApplication fb_deactivateWithDuration:duration error:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleTimeouts:(FBRouteRequest *)request
{
  // This method is intentionally not supported.
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleDismissKeyboardCommand:(FBRouteRequest *)request
{
#if TARGET_OS_TV
  if ([self isKeyboardPresentForApplication:request.session.activeApplication]) {
    [[XCUIRemote sharedRemote] pressButton: XCUIRemoteButtonMenu];
  }
#else
  [request.session.activeApplication dismissKeyboard];
#endif
  NSError *error;
  NSString *errorDescription = @"The keyboard cannot be dismissed. Try to dismiss it in the way supported by your application under test.";
  if ([UIDevice.currentDevice userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
    errorDescription = @"The keyboard on iPhone cannot be dismissed because of a known XCTest issue. Try to dismiss it in the way supported by your application under test.";
  }
  BOOL isKeyboardNotPresent =
  [[[[FBRunLoopSpinner new]
     timeout:5]
    timeoutErrorMessage:errorDescription]
   spinUntilTrue:^BOOL{
     return ![self isKeyboardPresentForApplication:request.session.activeApplication];
   }
   error:&error];
  if (!isKeyboardNotPresent) {
    return FBResponseWithStatus([FBCommandStatus elementNotVisibleErrorWithMessage:error.description traceback:[NSString stringWithFormat:@"%@", NSThread.callStackSymbols]]);
  }
  return FBResponseWithOK();
}

#pragma mark - Helpers

+ (BOOL)isKeyboardPresentForApplication:(XCUIApplication *)application {
  XCUIElement *foundKeyboard = [application.fb_query descendantsMatchingType:XCUIElementTypeKeyboard].fb_firstMatch;
  return foundKeyboard && foundKeyboard.fb_isVisible;
}

+ (id<FBResponsePayload>)handleGetScreen:(FBRouteRequest *)request
{
  FBSession *session = request.session;
  CGSize statusBarSize = [FBScreen statusBarSizeForApplication:session.activeApplication];
  return FBResponseWithObject(
  @{
    @"statusBarSize": @{@"width": @(statusBarSize.width),
                        @"height": @(statusBarSize.height),
                        },
    @"scale": @([FBScreen scale]),
    @"func":@"screen"
    });
}

+ (id<FBResponsePayload>)handleLock:(FBRouteRequest *)request
{
  NSError *error;
  if (![[XCUIDevice sharedDevice] fb_lockScreen:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleIsLocked:(FBRouteRequest *)request
{
  BOOL isLocked = [XCUIDevice sharedDevice].fb_isScreenLocked;
  return FBResponseWithObject(@{
      @"isLocked":isLocked ? @YES : @NO,
      @"func":@"locked"
  });
}

+ (id<FBResponsePayload>)handleUnlock:(FBRouteRequest *)request
{
  NSError *error;
  if (![[XCUIDevice sharedDevice] fb_unlockScreen:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleActiveAppInfo:(FBRouteRequest *)request
{
  XCUIApplication *app = request.session.activeApplication ?: FBApplication.fb_activeApplication;
  return FBResponseWithObject(@{
    @"pid": @(app.processID),
    @"bundleId": app.bundleID,
    @"name": app.identifier,
    @"processArguments": [self processArguments:app],
  });
}

/**
 * Returns current active app and its arguments of active session
 *
 * @return The dictionary of current active bundleId and its process/environment argumens
 *
 * @example
 *
 *     [self currentActiveApplication]
 *     //=> {
 *     //       "processArguments" : {
 *     //       "env" : {
 *     //           "HAPPY" : "testing"
 *     //       },
 *     //       "args" : [
 *     //           "happy",
 *     //           "tseting"
 *     //       ]
 *     //   }
 *
 *     [self currentActiveApplication]
 *     //=> {}
 */
+ (NSDictionary *)processArguments:(XCUIApplication *)app
{
  // Can be nil if no active activation is defined by XCTest
  if (app == nil) {
    return @{};
  }

  return
  @{
    @"args": app.launchArguments,
    @"env": app.launchEnvironment
  };
}

#if !TARGET_OS_TV
+ (id<FBResponsePayload>)handleSetPasteboard:(FBRouteRequest *)request
{
  NSString *contentType = request.arguments[@"contentType"] ?: @"plaintext";
  NSData *content = [[NSData alloc] initWithBase64EncodedString:(NSString *)request.arguments[@"content"]
                                                        options:NSDataBase64DecodingIgnoreUnknownCharacters];
  if (nil == content) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"Cannot decode the pasteboard content from base64" traceback:nil]);
  }
  NSError *error;
  if (![FBPasteboard setData:content forType:contentType error:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleGetPasteboard:(FBRouteRequest *)request
{
  NSString *contentType = request.arguments[@"contentType"] ?: @"plaintext";
  NSError *error;
  id result = [FBPasteboard dataForType:contentType error:&error];
  if (nil == result) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithObject(@{
    @"content":[result base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength],
    @"func":@"getPasteboard"
  });
}

+ (id<FBResponsePayload>)handleGetBatteryInfo:(FBRouteRequest *)request
{
  if (![[UIDevice currentDevice] isBatteryMonitoringEnabled]) {
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
  }
  return FBResponseWithObject(@{
    @"level": @([UIDevice currentDevice].batteryLevel),
    @"state": @([UIDevice currentDevice].batteryState),
    @"func":@"batteryInfo"
  });
}
#endif

+ (id<FBResponsePayload>)handlePressButtonCommand:(FBRouteRequest *)request
{
  NSError *error;
  if (![XCUIDevice.sharedDevice fb_pressButton:(id)request.arguments[@"name"] error:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleActivateSiri:(FBRouteRequest *)request
{
  NSError *error;
  if (![XCUIDevice.sharedDevice fb_activateSiriVoiceRecognitionWithText:(id)request.arguments[@"text"] error:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

+ (id <FBResponsePayload>)handleLaunchUnattachedApp:(FBRouteRequest *)request
{
  NSString *bundle = (NSString *)request.arguments[@"bundleId"];
  if ([FBUnattachedAppLauncher launchAppWithBundleId:bundle]) {
    return FBResponseWithOK();
  }
  return FBResponseWithStatus([FBCommandStatus unknownErrorWithMessage:@"LSApplicationWorkspace failed to launch app" traceback:nil]);
}

+ (id<FBResponsePayload>)handleGetDeviceInfo:(FBRouteRequest *)request
{
  // Returns locale like ja_EN and zh-Hant_US. The format depends on OS
  // Developers should use this locale by default
  // https://developer.apple.com/documentation/foundation/nslocale/1414388-autoupdatingcurrentlocale
  NSString *currentLocale = [[NSLocale autoupdatingCurrentLocale] localeIdentifier];

  return FBResponseWithObject(@{
    @"currentLocale": currentLocale,
    @"timeZone": self.timeZone,
    @"name": UIDevice.currentDevice.name,
    @"model": UIDevice.currentDevice.model,
    @"uuid": [UIDevice.currentDevice.identifierForVendor UUIDString] ?: @"unknown",
    // https://developer.apple.com/documentation/uikit/uiuserinterfaceidiom?language=objc
    @"userInterfaceIdiom": @(UIDevice.currentDevice.userInterfaceIdiom),
#if TARGET_OS_SIMULATOR
    @"isSimulator": @(YES),
#else
    @"isSimulator": @(NO),
#endif
  });
}

/**
 * @return The string of TimeZone. Returns TZ timezone id by default. Returns TimeZone name by Apple if TZ timezone id is not available.
 */
+ (NSString *)timeZone
{
  NSTimeZone *localTimeZone = [NSTimeZone localTimeZone];
  // Apple timezone name like "US/New_York"
  NSString *timeZoneAbb = [localTimeZone abbreviation];
  if (timeZoneAbb == nil) {
    return [localTimeZone name];
  }

  // Convert timezone name to ids like "America/New_York" as TZ database Time Zones format
  // https://developer.apple.com/documentation/foundation/nstimezone
  NSString *timeZoneId = [[NSTimeZone timeZoneWithAbbreviation:timeZoneAbb] name];
  if (timeZoneId != nil) {
    return timeZoneId;
  }

  return [localTimeZone name];
}

/*+ (id<FBResponsePayload>)handleGetWeakNetInfo:(FBRouteRequest *)request
{
  
  void * FTServicesHandle = dlopen("/System/Library/PrivateFrameworks/FTServices.framework/FTServices", RTLD_LAZY);
  Class NetworkSupport = NSClassFromString(@"FTNetworkSupport");
  
#       pragma clang diagnostic push
#       pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  id networkSupport = [NetworkSupport performSelector:NSSelectorFromString(@"sharedInstance")];
  [networkSupport performSelector:NSSelectorFromString(@"dataActiveAndReachable")];
#       pragma clang diagnostic pop
  

  
  CTCellularData *cellularData = [[CTCellularData alloc] init];
  cellularData.cellularDataRestrictionDidUpdateNotifier = ^(CTCellularDataRestrictedState state) {
    switch (state) {
      case kCTCellularDataRestricted:
        NSLog(@"Restricted");
        //2.1权限关闭的情况下 再次请求网络数据会弹出设置网络提示
        //        [self getAppInfo];
        break;
      case kCTCellularDataRestrictedStateUnknown:
        NSLog(@"Unknown");
        //2.2未知情况 （还没有遇到推测是有网络但是连接不正常的情况下）
        //        [self getAppInfo];
        break;
      case kCTCellularDataNotRestricted:
        NSLog(@"NotRestricted");
        //2.3已经开启网络权限 监听网络状态
        //卸载FTServices.framework
        dlclose(FTServicesHandle);
        break;
      default:
        break;
    }
  };
  
  void *CoreTelephonyHandle = dlopen("/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony", RTLD_LAZY);
  //用函数指针来调用私有C函数，用符号名从库里寻找函数地址
  CFTypeRef (*connectionCreateOnTargetQueue)(CFAllocatorRef, NSString *, dispatch_queue_t, void*) = (CFTypeRef (*)(CFAllocatorRef, NSString *, dispatch_queue_t, void*))dlsym(CoreTelephonyHandle, "_CTServerConnectionCreateOnTargetQueue");
  int (*changeCellularPolicy)(CFTypeRef, NSString *, NSDictionary *) = (int (*)(CFTypeRef, NSString *, NSDictionary *))dlsym(CoreTelephonyHandle, "_CTServerConnectionSetCellularUsagePolicy");
  //使用设置app的bundle id进行伪装
  CFTypeRef connection = connectionCreateOnTargetQueue(kCFAllocatorDefault,@"com.apple.Preferences",dispatch_get_main_queue(),NULL);
  //请求修改本app的网络权限为allowed，不会真的修改，只能触发系统更新一下相关的数据
  changeCellularPolicy(connection, @"com.apple.test.WebDriverAgentRunner-Runner", @{@"kCTCellularUsagePolicyDataAllowed":@YES});
  dlclose(CoreTelephonyHandle);
  
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  NSURL *url =[NSURL URLWithString:@"http://172.21.37.124:8000/api/v1/token"];
  NSURLSession *session =[NSURLSession sharedSession];
  __block NSString *err = @"no error";
  __block NSString *res;
  
  NSURLSessionDataTask *dataTask =[session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    NSString *retStr = [[NSString alloc] initWithData:(NSData*)data encoding:NSUTF8StringEncoding];
    res = retStr;
    if (error != nil) {
      err = [error localizedDescription];
    }
    //    NSLog(@"html = %@",retStr);
    dispatch_semaphore_signal(semaphore);
  }];
  [dataTask resume];
  dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
  
  return FBResponseWithObject(@{
                                @"info":res,
                                @"error":err
                              });
}*/


@end
