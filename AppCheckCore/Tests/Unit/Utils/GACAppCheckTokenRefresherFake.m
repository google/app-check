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

#import "AppCheckCore/Tests/Unit/Utils/GACAppCheckTokenRefresherFake.h"

@implementation GACAppCheckTokenRefresherFake

@synthesize tokenRefreshHandler = _tokenRefreshHandler;

- (GACAppCheckTokenRefreshBlock)tokenRefreshHandler {
  @synchronized(self) {
    return _tokenRefreshHandler;
  }
}

- (void)setTokenRefreshHandler:(GACAppCheckTokenRefreshBlock)tokenRefreshHandler {
  @synchronized(self) {
    _tokenRefreshHandler = [tokenRefreshHandler copy];
  }
}

- (void)updateWithRefreshResult:(GACAppCheckTokenRefreshResult *)refreshResult {
  @synchronized(self) {
    self.updateWithRefreshResultCallCount++;
    self.lastRefreshResult = refreshResult;
  }
}

@end
