/*
 * Copyright 2024 Google LLC
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

#import "AppCheckCore/Tests/Unit/Utils/GACAppCheckProviderFake.h"

@implementation GACAppCheckProviderFake

@synthesize getTokenCallCount = _getTokenCallCount;
@synthesize getLimitedUseTokenCallCount = _getLimitedUseTokenCallCount;

- (NSInteger)getTokenCallCount {
  @synchronized(self) {
    return _getTokenCallCount;
  }
}

- (void)setGetTokenCallCount:(NSInteger)getTokenCallCount {
  @synchronized(self) {
    _getTokenCallCount = getTokenCallCount;
  }
}

- (NSInteger)getLimitedUseTokenCallCount {
  @synchronized(self) {
    return _getLimitedUseTokenCallCount;
  }
}

- (void)setGetLimitedUseTokenCallCount:(NSInteger)getLimitedUseTokenCallCount {
  @synchronized(self) {
    _getLimitedUseTokenCallCount = getLimitedUseTokenCallCount;
  }
}

- (void)getTokenWithCompletion:(void (^)(GACAppCheckToken *_Nullable token,
                                         NSError *_Nullable error))handler {
  GACAppCheckToken *token;
  NSError *error;
  @synchronized(self) {
    self.getTokenCallCount++;
    token = self.tokenToReturn;
    error = self.errorToReturn;
  }
  if (handler) {
    handler(token, error);
  }
}

- (void)getLimitedUseTokenWithCompletion:(void (^)(GACAppCheckToken *_Nullable token,
                                                   NSError *_Nullable error))handler {
  GACAppCheckToken *token;
  NSError *error;
  @synchronized(self) {
    self.getLimitedUseTokenCallCount++;
    token = self.limitedUseTokenToReturn;
    error = self.limitedUseErrorToReturn;
  }
  if (handler) {
    handler(token, error);
  }
}

@end
