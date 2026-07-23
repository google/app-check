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

#import "AppCheckCore/Tests/Unit/Utils/GACAppAttestArtifactStorageFake.h"

#import "FBLPromise.h"

@implementation GACAppAttestArtifactStorageFake

@synthesize setArtifactCallCount = _setArtifactCallCount;
@synthesize setArtifactPromise = _setArtifactPromise;
@synthesize getArtifactCallCount = _getArtifactCallCount;
@synthesize getArtifactPromise = _getArtifactPromise;

- (FBLPromise<NSData *> *)setArtifact:(nullable NSData *)artifact forKey:(NSString *)keyID {
  @synchronized(self) {
    _setArtifactCallCount++;
    return _setArtifactPromise ?: [FBLPromise pendingPromise];
  }
}

- (FBLPromise<NSData *> *)getArtifactForKey:(NSString *)keyID {
  @synchronized(self) {
    _getArtifactCallCount++;
    return _getArtifactPromise ?: [FBLPromise pendingPromise];
  }
}

- (NSInteger)setArtifactCallCount {
  @synchronized(self) {
    return _setArtifactCallCount;
  }
}

- (void)setSetArtifactPromise:(nullable FBLPromise<NSData *> *)promise {
  @synchronized(self) {
    _setArtifactPromise = promise;
  }
}

- (NSInteger)getArtifactCallCount {
  @synchronized(self) {
    return _getArtifactCallCount;
  }
}

- (void)setGetArtifactPromise:(nullable FBLPromise<NSData *> *)promise {
  @synchronized(self) {
    _getArtifactPromise = promise;
  }
}

@end
