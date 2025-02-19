/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBSTFCommands.h"

#import "XCUIApplication.h"
#import "FBConfiguration.h"
#import "FBKeyboard.h"
#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBRunLoopSpinner.h"
#import "FBElementCache.h"
#import "FBErrorBuilder.h"
#import "FBSession.h"
#import "FBMacros.h"
#import "FBMathUtils.h"
#import "FBRuntimeUtils.h"
#import "NSPredicate+FBFormat.h"
#import "XCUICoordinate.h"
#import "XCUIDevice.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBPickerWheel.h"
#import "XCUIElement+FBScrolling.h"
//#import "XCUIElement+FBTap.h"
#import "XCUIElement+FBForceTouch.h"
#import "XCUIElement+FBTyping.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCUIElement+FBTVFocuse.h"
#import "FBElementTypeTransformer.h"
#import "XCUIElement.h"
#import "XCUIElementQuery.h"
#import "FBXCodeCompatibility.h"
#import "XCUIApplication+FBTouchAction.h"
#import "FBXMLGenerationOptions.h"

@implementation FBSTFCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute POST:@"/wda/del_key"].withoutSession respondWithTarget:self action:@selector(handleDeleteKey:)],
    [[FBRoute POST:@"/wda/dragfromtoforduration_stf"].withoutSession respondWithTarget:self action:@selector(handleDragCoordinate_stf:)],
    [[FBRoute POST:@"/wda/touch/perform_stf"].withoutSession respondWithTarget:self action:@selector(handlePerformAppiumTouchActions_stf:)],
    [[FBRoute POST:@"/wda/tap_stf"].withoutSession respondWithTarget:self action:@selector(handleTap_stf:)],
    [[FBRoute GET:@"/check_status"].withoutSession respondWithTarget:self action:@selector(handleGetCheckStatus:)],
    [[FBRoute POST:@"/wda/apps/launchapp"].withoutSession respondWithTarget:self action:@selector(handleAppLaunchWithoutSession:)],
    [[FBRoute POST:@"/wda/apps/terminateapp"].withoutSession respondWithTarget:self action:@selector(handleAppTerminateWithoutSession:)],
    [[FBRoute POST:@"/orientation_Control"].withoutSession respondWithTarget:self action:@selector(handleSetOrientation_Control:)],
    [[FBRoute GET:@"/orientation_Control"].withoutSession respondWithTarget:self action:@selector(handleGetOrientation_Control:)],
    [[FBRoute GET:@"/source_stf"].withoutSession respondWithTarget:self action:@selector(handleGetSourceCommand:)],
    ];
}

#pragma mark - Commands

static NSString *const SOURCE_FORMAT_XML = @"xml";
static NSString *const SOURCE_FORMAT_JSON = @"json";
static NSString *const SOURCE_FORMAT_DESCRIPTION = @"description";

+ (id<FBResponsePayload>)handleGetSourceCommand:(FBRouteRequest *)request
{
  XCUIApplication *application = request.session.activeApplication ?: XCUIApplication.fb_activeApplication;
  NSString *sourceType = request.parameters[@"format"] ?: SOURCE_FORMAT_XML;
  NSString *sourceScope = request.parameters[@"scope"];
  id result;
  if ([sourceType caseInsensitiveCompare:SOURCE_FORMAT_XML] == NSOrderedSame) {
    NSArray<NSString *> *excludedAttributes = nil == request.parameters[@"excluded_attributes"]
      ? nil
      : [request.parameters[@"excluded_attributes"] componentsSeparatedByString:@","];
    result = [application fb_xmlRepresentationWithOptions:
        [[[FBXMLGenerationOptions new]
          withExcludedAttributes:excludedAttributes]
         withScope:sourceScope]];
  } else if ([sourceType caseInsensitiveCompare:SOURCE_FORMAT_JSON] == NSOrderedSame) {
    result = application.fb_tree;
  } else if ([sourceType caseInsensitiveCompare:SOURCE_FORMAT_DESCRIPTION] == NSOrderedSame) {
    result = application.fb_descriptionRepresentation;
  } else {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:[NSString stringWithFormat:@"Unknown source format '%@'. Only %@ source formats are supported.",
                                                                                  sourceType, @[SOURCE_FORMAT_XML, SOURCE_FORMAT_JSON, SOURCE_FORMAT_DESCRIPTION]] traceback:nil]);
  }
  if (nil == result) {
    return FBResponseWithUnknownErrorFormat(@"Cannot get '%@' source of the current application", sourceType);
  }
  return FBResponseWithObject(@{
    @"func":@"source_stf",
    @"value":result
  });
}

+ (id<FBResponsePayload>)handleTap_stf:(FBRouteRequest *)request
{
  XCUIApplication* application = XCUIApplication.fb_activeApplication;
  CGPoint tapPoint = CGPointMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue]);
  NSArray<NSDictionary<NSString *, id> *> *tapGesture =
  @[@{
      @"action": @"tap",
      @"options": @{
          @"x": @(tapPoint.x),
          @"y": @(tapPoint.y),
          }
      }
    ];
  [application fb_performW3CActions:tapGesture elementCache:nil error:nil];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handlePerformAppiumTouchActions_stf:(FBRouteRequest *)request
{
  XCUIApplication *application = [XCUIApplication fb_activeApplication];
  NSArray *actions = (NSArray *)request.arguments[@"actions"];
  NSError *error;
  if (![application fb_performW3CActions:actions elementCache:nil error:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleDragCoordinate_stf:(FBRouteRequest *)request
{
  XCUIApplication* application = XCUIApplication.fb_activeApplication;
  CGVector startOffset = CGVectorMake([request.arguments[@"fromX"] doubleValue],
                                      [request.arguments[@"fromY"] doubleValue]);
  XCUICoordinate *startCoordinate = [self.class gestureCoordinateWithOffset:startOffset
                                                                    element:application];
  CGVector endOffset = CGVectorMake([request.arguments[@"toX"] doubleValue],
                                    [request.arguments[@"toY"] doubleValue]);
  XCUICoordinate *endCoordinate = [self.class gestureCoordinateWithOffset:endOffset
                                                                  element:application];
  NSTimeInterval duration = [request.arguments[@"duration"] doubleValue];
  [startCoordinate pressForDuration:duration thenDragToCoordinate:endCoordinate];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleDeleteKey:(FBRouteRequest *)request
{
  NSError * error ;
  NSData *encodedSequence = [@"\\u0008\\u007F" dataUsingEncoding:NSASCIIStringEncoding];
  NSString *backspaceDeleteSequence = [[NSString alloc] initWithData:encodedSequence encoding:NSNonLossyASCIIStringEncoding];
  NSMutableString *textToType = @"".mutableCopy;
  [textToType appendString:backspaceDeleteSequence];
  if (textToType.length > 0 && ![FBKeyboard typeText:textToType error:&error]) {
    return FBResponseWithStatus([FBCommandStatus invalidElementStateErrorWithMessage:error.description traceback:nil]);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleGetCheckStatus:(FBRouteRequest *)request
{
  return FBResponseWithObject(@{@"func":@"check_status"});
}

+ (id<FBResponsePayload>)handleAppLaunchWithoutSession:(FBRouteRequest *)request
{
  NSDictionary *requirements = request.arguments[@"desiredCapabilities"];
  NSString *bundleID = requirements[@"bundleId"];
  NSString *appPath = requirements[@"app"];
  if (!bundleID) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"bundleId is required" traceback:nil]);
  }
  
//  [FBConfiguration setShouldWaitForQuiescence:[requirements[@"shouldWaitForQuiescence"] boolValue]];
  XCUIApplication *app = [[XCUIApplication alloc] initPrivateWithPath:appPath bundleID:bundleID];
  if (app.state < 2) {
//    app.fb_shouldWaitForQuiescence = FBConfiguration.shouldWaitForQuiescence;
    app.launchArguments = (NSArray<NSString *> *)requirements[@"arguments"] ?: @[];
    app.launchEnvironment =  @{};//(NSDictionary <NSString *, NSString *> *)requirements[@"environment"] ?: @{};
    [app launch];
  } else {
    [app activate];
  }
  if (app.processID == 0) {
    return FBResponseWithUnknownErrorFormat(@"Failed to launch %@ application", bundleID);
  }
  
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleAppTerminateWithoutSession:(FBRouteRequest *)request
{
  NSString *bundleIdentifier = request.arguments[@"bundleId"];
  XCUIApplication* app = [[XCUIApplication alloc] initPrivateWithPath:nil bundleID:bundleIdentifier];
  BOOL result = NO;
  if (app.running) {
    [app terminate];
    result = YES;
  }
  return FBResponseWithObject(@(result));
}

+ (id<FBResponsePayload>)handleSetOrientation_Control:(FBRouteRequest *)request
{
  [XCUIDevice sharedDevice].orientation = [request.arguments[@"orientation"] integerValue];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleGetOrientation_Control:(FBRouteRequest *)request
{
  UIDeviceOrientation orientation = [XCUIDevice sharedDevice].orientation ;
  return FBResponseWithObject( @{
                                 @"func":@"orientation_Control",
                                 @"orientation":[NSString stringWithFormat:@"%ld",(long)orientation]
                                 });
}


+ (XCUICoordinate *)gestureCoordinateWithOffset:(CGVector)offset
                                        element:(XCUIElement *)element
{
  return [[element coordinateWithNormalizedOffset:CGVectorMake(0, 0)] coordinateWithOffset:offset];
}

@end
