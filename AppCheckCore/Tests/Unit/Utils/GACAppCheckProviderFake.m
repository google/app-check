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

#import "AppCheckCore/Tests/Unit/Utils/GACAppCheckProviderFake.h"

@implementation GACAppCheckProviderFake

@synthesize tokenToReturn = _tokenToReturn;
@synthesize errorToReturn = _errorToReturn;
@synthesize getTokenCallCount = _getTokenCallCount;
@synthesize limitedUseTokenToReturn = _limitedUseTokenToReturn;
@synthesize limitedUseErrorToReturn = _limitedUseErrorToReturn;
@synthesize getLimitedUseTokenCallCount = _getLimitedUseTokenCallCount;

- (nullable GACAppCheckToken *)tokenToReturn {
  @synchronized(self) {
    return _tokenToReturn;
  }
}

- (void)setTokenToReturn:(nullable GACAppCheckToken *)tokenToReturn {
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

- (nullable GACAppCheckToken *)limitedUseTokenToReturn {
  @synchronized(self) {
    return _limitedUseTokenToReturn;
  }
}

- (void)setLimitedUseTokenToReturn:(nullable GACAppCheckToken *)limitedUseTokenToReturn {
  @synchronized(self) {
    _limitedUseTokenToReturn = limitedUseTokenToReturn;
  }
}

- (nullable NSError *)limitedUseErrorToReturn {
  @synchronized(self) {
    return _limitedUseErrorToReturn;
  }
}

- (void)setLimitedUseErrorToReturn:(nullable NSError *)limitedUseErrorToReturn {
  @synchronized(self) {
    _limitedUseErrorToReturn = limitedUseErrorToReturn;
  }
}

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
    _getTokenCallCount++;
    token = _tokenToReturn;
    error = _errorToReturn;
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
    _getLimitedUseTokenCallCount++;
    token = _limitedUseTokenToReturn;
    error = _limitedUseErrorToReturn;
  }
  if (handler) {
    handler(token, error);
  }
}

@end
