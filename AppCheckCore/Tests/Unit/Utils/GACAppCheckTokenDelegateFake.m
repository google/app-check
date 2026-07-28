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

#import "AppCheckCore/Tests/Unit/Utils/GACAppCheckTokenDelegateFake.h"

@implementation GACAppCheckTokenDelegateFake

@synthesize tokenDidUpdateCallCount = _tokenDidUpdateCallCount;
@synthesize lastToken = _lastToken;
@synthesize lastServiceName = _lastServiceName;

- (void)tokenDidUpdate:(GACAppCheckToken *)token serviceName:(NSString *)serviceName {
  @synchronized(self) {
    _tokenDidUpdateCallCount++;
    _lastToken = token;
    _lastServiceName = serviceName;
  }
}

- (NSInteger)tokenDidUpdateCallCount {
  @synchronized(self) {
    return _tokenDidUpdateCallCount;
  }
}

- (void)setTokenDidUpdateCallCount:(NSInteger)tokenDidUpdateCallCount {
  @synchronized(self) {
    _tokenDidUpdateCallCount = tokenDidUpdateCallCount;
  }
}

- (nullable GACAppCheckToken *)lastToken {
  @synchronized(self) {
    return _lastToken;
  }
}

- (void)setLastToken:(nullable GACAppCheckToken *)lastToken {
  @synchronized(self) {
    _lastToken = lastToken;
  }
}

- (nullable NSString *)lastServiceName {
  @synchronized(self) {
    return _lastServiceName;
  }
}

- (void)setLastServiceName:(nullable NSString *)lastServiceName {
  @synchronized(self) {
    _lastServiceName = lastServiceName;
  }
}

@end
