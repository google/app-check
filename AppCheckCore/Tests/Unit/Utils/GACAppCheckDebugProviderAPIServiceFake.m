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

#import "AppCheckCore/Tests/Unit/Utils/GACAppCheckDebugProviderAPIServiceFake.h"
#import "FBLPromise+Testing.h"

@implementation GACAppCheckDebugProviderAPIServiceFake

- (FBLPromise<GACAppCheckToken *> *)appCheckTokenWithDebugToken:(NSString *)debugToken
                                                     limitedUse:(BOOL)limitedUse {
  FBLPromise *promise;
  @synchronized(self) {
    _passedDebugToken = debugToken;
    _passedLimitedUse = limitedUse;
    if (limitedUse) {
      promise = _limitedUseTokenPromise;
    } else {
      promise = _tokenPromise;
    }
  }
  if (promise) {
    return promise;
  }
  return [FBLPromise pendingPromise];
}

@end
