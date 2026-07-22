/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "AppCheckCore/Tests/Unit/Utils/GACDeviceCheckAPIServiceFake.h"

#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckToken.h"
#import "FBLPromise+Testing.h"

NS_ASSUME_NONNULL_BEGIN

@implementation GACDeviceCheckAPIServiceFake

@synthesize appCheckTokenPromise = _appCheckTokenPromise;
@synthesize passedDeviceToken = _passedDeviceToken;
@synthesize passedLimitedUse = _passedLimitedUse;
@synthesize appCheckTokenWithDeviceTokenHandler = _appCheckTokenWithDeviceTokenHandler;

- (instancetype)init {
  self = [super init];
  if (self) {
    _appCheckTokenPromise = [FBLPromise pendingPromise];
  }
  return self;
}

- (FBLPromise<GACAppCheckToken *> *)appCheckTokenWithDeviceToken:(NSData *)deviceToken
                                                      limitedUse:(BOOL)limitedUse {
  FBLPromise<GACAppCheckToken *> *promise;
  void (^handler)(NSData *, BOOL);
  @synchronized(self) {
    _passedDeviceToken = deviceToken;
    _passedLimitedUse = limitedUse;
    promise = _appCheckTokenPromise;
    handler = _appCheckTokenWithDeviceTokenHandler;
  }
  if (handler) {
    handler(deviceToken, limitedUse);
  }
  return promise ?: [FBLPromise pendingPromise];
}

- (FBLPromise<GACAppCheckToken *> *)appCheckTokenPromise {
  @synchronized(self) {
    return _appCheckTokenPromise;
  }
}

- (void)setAppCheckTokenPromise:(FBLPromise<GACAppCheckToken *> *)appCheckTokenPromise {
  @synchronized(self) {
    _appCheckTokenPromise = appCheckTokenPromise;
  }
}

- (nullable NSData *)passedDeviceToken {
  @synchronized(self) {
    return _passedDeviceToken;
  }
}

- (void)setPassedDeviceToken:(nullable NSData *)passedDeviceToken {
  @synchronized(self) {
    _passedDeviceToken = passedDeviceToken;
  }
}

- (BOOL)passedLimitedUse {
  @synchronized(self) {
    return _passedLimitedUse;
  }
}

- (void)setPassedLimitedUse:(BOOL)passedLimitedUse {
  @synchronized(self) {
    _passedLimitedUse = passedLimitedUse;
  }
}

- (nullable void (^)(NSData *, BOOL))appCheckTokenWithDeviceTokenHandler {
  @synchronized(self) {
    return _appCheckTokenWithDeviceTokenHandler;
  }
}

- (void)setAppCheckTokenWithDeviceTokenHandler:(nullable void (^)(NSData *, BOOL))appCheckTokenWithDeviceTokenHandler {
  @synchronized(self) {
    _appCheckTokenWithDeviceTokenHandler = appCheckTokenWithDeviceTokenHandler;
  }
}

@end

NS_ASSUME_NONNULL_END
