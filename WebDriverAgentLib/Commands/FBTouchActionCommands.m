/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBTouchActionCommands.h"

#import "FBApplication.h"
#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBSession.h"
#import "XCUIApplication+FBTouchAction.h"

@implementation FBTouchActionCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute POST:@"/wda/touch/perform"] respondWithTarget:self action:@selector(handlePerformAppiumTouchActions:)],
    [[FBRoute POST:@"/wda/touch/multi/perform"] respondWithTarget:self action:@selector(handlePerformAppiumTouchActions:)],
    [[FBRoute POST:@"/actions"] respondWithTarget:self action:@selector(handlePerformW3CTouchActions:)],
    [[FBRoute POST:@"/wda/touch/perform_stf"].withoutSession respondWithTarget:self action:@selector(handlePerformAppiumTouchActions:)],
  ];
}

#pragma mark - Commands

+ (id<FBResponsePayload>)handlePerformAppiumTouchActions:(FBRouteRequest *)request
{
  XCUIApplication *application = [FBApplication fb_activeApplication];
  FBElementCache *elementCache = nil;
  if(request.session){
    application = request.session.activeApplication;
    elementCache = request.session.elementCache;
  }
  NSArray *actions = (NSArray *)request.arguments[@"actions"];
  NSError *error;
  if (![application fb_performAppiumTouchActions:actions elementCache:elementCache error:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handlePerformW3CTouchActions:(FBRouteRequest *)request
{
  XCUIApplication *application = request.session.activeApplication;
  NSArray *actions = (NSArray *)request.arguments[@"actions"];
  NSError *error;
  if (![application fb_performW3CTouchActions:actions elementCache:request.session.elementCache error:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

@end
