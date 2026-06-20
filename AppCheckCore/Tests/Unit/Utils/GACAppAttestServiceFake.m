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

#import "AppCheckCore/Tests/Unit/Utils/GACAppAttestServiceFake.h"

@implementation GACAppAttestServiceFake

- (instancetype)init {
  self = [super init];
  if (self) {
    _isSupported = YES;
  }
  return self;
}

- (BOOL)supported {
  return self.isSupported;
}

- (void)generateKeyWithCompletionHandler:(void (^)(NSString *keyId,
                                                   NSError *error))completionHandler {
  self.generateKeyCallCount++;
  if (completionHandler) {
    completionHandler(self.keyIdToReturn, self.generateKeyErrorToReturn);
  }
}

- (void)attestKey:(NSString *)keyId
       clientDataHash:(NSData *)clientDataHash
    completionHandler:(void (^)(NSData *attestationObject, NSError *error))completionHandler {
  self.attestKeyCallCount++;
  if (completionHandler) {
    completionHandler(self.attestationToReturn, self.attestKeyErrorToReturn);
  }
}

- (void)generateAssertion:(NSString *)keyId
           clientDataHash:(NSData *)clientDataHash
        completionHandler:(void (^)(NSData *assertionObject, NSError *error))completionHandler {
  self.generateAssertionCallCount++;
  if (completionHandler) {
    completionHandler(self.assertionToReturn, self.generateAssertionErrorToReturn);
  }
}

@end
