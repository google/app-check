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

#import "AppCheckCore/Tests/Unit/Utils/GACDeviceCheckTokenGeneratorFake.h"

NS_ASSUME_NONNULL_BEGIN

@implementation GACDeviceCheckTokenGeneratorFake

@synthesize supported = _supported;
@synthesize tokenToReturn = _tokenToReturn;
@synthesize errorToReturn = _errorToReturn;
@synthesize generateTokenCalled = _generateTokenCalled;

- (void)generateTokenWithCompletionHandler:(void (^)(NSData *_Nullable token,
                                                     NSError *_Nullable error))completion {
  NSData *token;
  NSError *error;
  @synchronized(self) {
    _generateTokenCalled = YES;
    token = _tokenToReturn;
    error = _errorToReturn;
  }
  if (completion) {
    completion(token, error);
  }
}

- (BOOL)isSupported {
  @synchronized(self) {
    return _supported;
  }
}

- (void)setSupported:(BOOL)supported {
  @synchronized(self) {
    _supported = supported;
  }
}

- (nullable NSData *)tokenToReturn {
  @synchronized(self) {
    return _tokenToReturn;
  }
}

- (void)setTokenToReturn:(nullable NSData *)tokenToReturn {
  @synchronized(self) {
    _tokenToReturn = tokenToReturn;
  }
}

- (nullable NSError *)errorToReturn {
  @synchronized(self) {
    return _errorToReturn;
  }
}

- (void)setErrorToReturn:(nullable NSError *)errorToReturn {
  @synchronized(self) {
    _errorToReturn = errorToReturn;
  }
}

- (BOOL)generateTokenCalled {
  @synchronized(self) {
    return _generateTokenCalled;
  }
}

- (void)setGenerateTokenCalled:(BOOL)generateTokenCalled {
  @synchronized(self) {
    _generateTokenCalled = generateTokenCalled;
  }
}

@end

NS_ASSUME_NONNULL_END
