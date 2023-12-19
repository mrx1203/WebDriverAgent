/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSession.h"
#import "FBSession-Private.h"

#import <objc/runtime.h>

#import "FBXCAccessibilityElement.h"
#import "FBAlertsMonitor.h"
#import "FBApplication.h"
#import "FBConfiguration.h"
#import "FBElementCache.h"
#import "FBExceptions.h"
#import "FBMacros.h"
#import "FBXCodeCompatibility.h"
#import "XCUIApplication+FBQuiescence.h"
#import "XCUIElement.h"

/*!
 The intial value for the default application property.
 Setting this value to `defaultActiveApplication` property forces WDA to use the internal
 automated algorithm to determine the active on-screen application
 */
NSString *const FBDefaultApplicationAuto = @"auto";

@interface FBSession ()
@property (nonatomic) NSString *testedApplicationBundleId;
@property (nonatomic) BOOL isTestedApplicationExpectedToRun;
@property (nonatomic) BOOL shouldAppsWaitForQuiescence;
@property (nonatomic, nullable) FBAlertsMonitor *alertsMonitor;
@property (nonatomic, readwrite) NSMutableDictionary<NSNumber *, NSMutableDictionary<NSString *, NSNumber *> *> *elementsVisibilityCache;
@end

@interface FBSession (FBAlertsMonitorDelegate)

- (void)didDetectAlert:(FBAlert *)alert;

@end

@implementation FBSession (FBAlertsMonitorDelegate)

- (void)didDetectAlert:(FBAlert *)alert
{
  if (nil == self.defaultAlertAction) {
    return;
  }

  NSError *error;
  if ([self.defaultAlertAction isKindOfClass:[NSArray class]]){
    if (![alert actionWithAction:self.defaultAlertAction error:&error]) {
      [FBLogger logFmt:@"Cannot action the alert. Original error: %@", error.description];
    }
  }
  else if ([self.defaultAlertAction isEqualToString:@"accept"]) {
    if (![alert acceptWithError:&error]) {
      [FBLogger logFmt:@"Cannot accept the alert. Original error: %@", error.description];
    }
  } else if ([self.defaultAlertAction isEqualToString:@"dismiss"]) {
    if (![alert dismissWithError:&error]) {
      [FBLogger logFmt:@"Cannot dismiss the alert. Original error: %@", error.description];
    }
  } else if ([self.defaultAlertAction hasPrefix:@"["] && [self.defaultAlertAction hasSuffix:@"]"]) {
    NSError *jsonError;
    NSData *objectData = [self.defaultAlertAction dataUsingEncoding:NSUTF8StringEncoding];
    NSArray<NSDictionary *> *actions = [NSJSONSerialization JSONObjectWithData:objectData options:NSJSONReadingMutableContainers error:&jsonError];
    if (jsonError) {
      return ;
    }
    self.defaultAlertAction = (NSString*)actions;
    if (![alert actionWithAction:self.defaultAlertAction error:&error]) {
      [FBLogger logFmt:@"Cannot action the alert. Original error: %@", error.description];
    }
  }
  else {
    [FBLogger logFmt:@"'%@' default alert action is unsupported", self.defaultAlertAction];
  }
}

@end

@implementation FBSession

static FBSession *_activeSession = nil;

+ (instancetype)activeSession
{
  return _activeSession;
}

+ (void)markSessionActive:(FBSession *)session
{
  if (_activeSession) {
    [_activeSession kill];
  }
  _activeSession = session;
}

+ (instancetype)sessionWithIdentifier:(NSString *)identifier
{
  if (!identifier) {
    return nil;
  }
  if (![identifier isEqualToString:_activeSession.identifier]) {
    return nil;
  }
  return _activeSession;
}

+ (instancetype)initWithApplication:(FBApplication *)application
{
  FBSession *session = [FBSession new];
  session.useNativeCachingStrategy = YES;
  session.alertsMonitor = nil;
  session.defaultAlertAction = nil;
  session.elementsVisibilityCache = [NSMutableDictionary dictionary];
  session.identifier = [[NSUUID UUID] UUIDString];
  session.defaultActiveApplication = FBDefaultApplicationAuto;
  session.testedApplicationBundleId = nil;
  session.isTestedApplicationExpectedToRun = nil != application && application.running;
  if (application) {
    session.testedApplicationBundleId = application.bundleID;
    session.shouldAppsWaitForQuiescence = application.fb_shouldWaitForQuiescence;
  }
  session.elementCache = [FBElementCache new];
  [FBSession markSessionActive:session];
  return session;
}

+ (instancetype)initWithApplication:(nullable FBApplication *)application
                 defaultAlertAction:(NSString *)defaultAlertAction
{
  FBSession *session = [self.class initWithApplication:application];
  session.alertsMonitor = [[FBAlertsMonitor alloc] init];
  session.alertsMonitor.delegate = (id<FBAlertsMonitorDelegate>)session;
  session.defaultAlertAction = [defaultAlertAction lowercaseString];
  [session.alertsMonitor enable];
  return session;
}

- (void)setAlertAction:(NSString *)alertAction
{
  if([alertAction isKindOfClass:[NSArray class]]){
    self.defaultAlertAction = alertAction;
  }
  else if ([alertAction hasPrefix:@"["] && [alertAction hasSuffix:@"]"]) {
    NSError *jsonError;
    NSData *objectData = [alertAction dataUsingEncoding:NSUTF8StringEncoding];
    NSArray<NSDictionary *> *actions = [NSJSONSerialization JSONObjectWithData:objectData options:NSJSONReadingMutableContainers error:&jsonError];
    if (jsonError) {
      return ;
    }
    self.defaultAlertAction = (NSString*)actions;
  }
  else{
    self.defaultAlertAction = [alertAction lowercaseString];
  }
  if(!self.alertsMonitor){
    self.alertsMonitor = [[FBAlertsMonitor alloc] init];
    self.alertsMonitor.delegate = (id<FBAlertsMonitorDelegate>)self;
  }
  [self.alertsMonitor enable];
}

- (void)kill
{
  if (nil == _activeSession) {
    return;
  }

  if (nil != self.alertsMonitor) {
    [self.alertsMonitor disable];
    self.alertsMonitor = nil;
  }

  if (self.testedApplicationBundleId && [FBConfiguration shouldTerminateApp]
      && ![self.testedApplicationBundleId isEqualToString:FBApplication.fb_systemApplication.bundleID]) {
    FBApplication *app = [[FBApplication alloc] initWithBundleIdentifier:self.testedApplicationBundleId];
    if ([app running]) {
      @try {
        [app terminate];
      } @catch (NSException *e) {
        [FBLogger logFmt:@"%@", e.description];
      }
    }
  }

  _activeSession = nil;
}

- (FBApplication *)activeApplication
{
  NSString *defaultBundleId = [self.defaultActiveApplication isEqualToString:FBDefaultApplicationAuto]
    ? nil
    : self.defaultActiveApplication;
  FBApplication *application = [FBApplication fb_activeApplicationWithDefaultBundleId:defaultBundleId];
  FBApplication *testedApplication = nil;
  if (self.testedApplicationBundleId && self.isTestedApplicationExpectedToRun) {
    testedApplication = nil != application.bundleID && [application.bundleID isEqualToString:self.testedApplicationBundleId]
      ? application
      : [[FBApplication alloc] initWithBundleIdentifier:self.testedApplicationBundleId];
  }
  if (testedApplication && !testedApplication.running) {
    NSString *description = [NSString stringWithFormat:@"The application under test with bundle id '%@' is not running, possibly crashed", self.testedApplicationBundleId];
    [[NSException exceptionWithName:FBApplicationCrashedException reason:description userInfo:nil] raise];
  }
  return application;
}

- (FBApplication *)launchApplicationWithBundleId:(NSString *)bundleIdentifier
                         shouldWaitForQuiescence:(nullable NSNumber *)shouldWaitForQuiescence
                                       arguments:(nullable NSArray<NSString *> *)arguments
                                     environment:(nullable NSDictionary <NSString *, NSString *> *)environment
{
  FBApplication *app = [[FBApplication alloc] initWithBundleIdentifier:bundleIdentifier];
  if (nil == shouldWaitForQuiescence) {
    // Iherit the quiescence check setting from the main app under test by default
    app.fb_shouldWaitForQuiescence = nil != self.testedApplicationBundleId && self.shouldAppsWaitForQuiescence;
  } else {
    app.fb_shouldWaitForQuiescence = [shouldWaitForQuiescence boolValue];
  }
  if (app.fb_state < 2) {
    app.launchArguments = arguments ?: @[];
    app.launchEnvironment = environment ?: @{};
    [app launch];
  } else {
    [app fb_activate];
  }
  if (nil != self.testedApplicationBundleId
      && [bundleIdentifier isEqualToString:(NSString *)self.testedApplicationBundleId]) {
    self.isTestedApplicationExpectedToRun = YES;
  }
  return app;
}

- (FBApplication *)activateApplicationWithBundleId:(NSString *)bundleIdentifier
{
  FBApplication *app = [[FBApplication alloc] initWithBundleIdentifier:bundleIdentifier];
  [app fb_activate];
  return app;
}

- (BOOL)terminateApplicationWithBundleId:(NSString *)bundleIdentifier
{
  FBApplication *app = [[FBApplication alloc] initWithBundleIdentifier:bundleIdentifier];
  if (nil != self.testedApplicationBundleId
      && [bundleIdentifier isEqualToString:(NSString *)self.testedApplicationBundleId]) {
    self.isTestedApplicationExpectedToRun = NO;
  }
  if (app.fb_state >= 2) {
    [app terminate];
    return YES;
  }
  return NO;
}

- (NSUInteger)applicationStateWithBundleId:(NSString *)bundleIdentifier
{
  return [[FBApplication alloc] initWithBundleIdentifier:bundleIdentifier].fb_state;
}

@end
