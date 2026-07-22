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

#import "AppCheckCore/Tests/Unit/Utils/GACAppAttestKeyIDStorageFake.h"

#import "FBLPromise.h"

@implementation GACAppAttestKeyIDStorageFake

@synthesize setAppAttestKeyIDCallCount = _setAppAttestKeyIDCallCount;
@synthesize setAppAttestKeyIDPromise = _setAppAttestKeyIDPromise;
@synthesize getAppAttestKeyIDCallCount = _getAppAttestKeyIDCallCount;
@synthesize getAppAttestKeyIDPromise = _getAppAttestKeyIDPromise;

- (FBLPromise<NSString *> *)setAppAttestKeyID:(nullable NSString *)keyID {
  @synchronized(self) {
    _setAppAttestKeyIDCallCount++;
    return _setAppAttestKeyIDPromise ?: [FBLPromise pendingPromise];
  }
}

- (FBLPromise<NSString *> *)getAppAttestKeyID {
  @synchronized(self) {
    _getAppAttestKeyIDCallCount++;
    return _getAppAttestKeyIDPromise ?: [FBLPromise pendingPromise];
  }
}

- (NSInteger)setAppAttestKeyIDCallCount {
  @synchronized(self) {
    return _setAppAttestKeyIDCallCount;
  }
}

- (void)setSetAppAttestKeyIDPromise:(nullable FBLPromise<NSString *> *)promise {
  @synchronized(self) {
    _setAppAttestKeyIDPromise = promise;
  }
}

- (NSInteger)getAppAttestKeyIDCallCount {
  @synchronized(self) {
    return _getAppAttestKeyIDCallCount;
  }
}

- (void)setGetAppAttestKeyIDPromise:(nullable FBLPromise<NSString *> *)promise {
  @synchronized(self) {
    _getAppAttestKeyIDPromise = promise;
  }
}

@end
