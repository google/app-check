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
    _supported = YES;
  }
  return self;
}

@synthesize supported = _supported;
@synthesize generateKeyCallCount = _generateKeyCallCount;
@synthesize keyIdToReturn = _keyIdToReturn;
@synthesize generateKeyErrorToReturn = _generateKeyErrorToReturn;
@synthesize attestKeyCallCount = _attestKeyCallCount;
@synthesize attestationToReturn = _attestationToReturn;
@synthesize attestKeyErrorToReturn = _attestKeyErrorToReturn;
@synthesize generateAssertionCallCount = _generateAssertionCallCount;
@synthesize assertionToReturn = _assertionToReturn;
@synthesize generateAssertionErrorToReturn = _generateAssertionErrorToReturn;

- (void)generateKeyWithCompletionHandler:(void (^)(NSString *keyId,
                                                   NSError *error))completionHandler {
  NSString *keyId;
  NSError *error;
  @synchronized(self) {
    _generateKeyCallCount++;
    keyId = _keyIdToReturn;
    error = _generateKeyErrorToReturn;
  }
  if (completionHandler) {
    completionHandler(keyId, error);
  }
}

- (void)attestKey:(NSString *)keyId
       clientDataHash:(NSData *)clientDataHash
    completionHandler:(void (^)(NSData *attestationObject, NSError *error))completionHandler {
  NSData *attestation;
  NSError *error;
  @synchronized(self) {
    _attestKeyCallCount++;
    attestation = _attestationToReturn;
    error = _attestKeyErrorToReturn;
  }
  if (completionHandler) {
    completionHandler(attestation, error);
  }
}

- (void)generateAssertion:(NSString *)keyId
           clientDataHash:(NSData *)clientDataHash
        completionHandler:(void (^)(NSData *assertionObject, NSError *error))completionHandler {
  NSData *assertion;
  NSError *error;
  @synchronized(self) {
    _generateAssertionCallCount++;
    assertion = _assertionToReturn;
    error = _generateAssertionErrorToReturn;
  }
  if (completionHandler) {
    completionHandler(assertion, error);
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

- (NSInteger)generateKeyCallCount {
  @synchronized(self) {
    return _generateKeyCallCount;
  }
}

- (void)setGenerateKeyCallCount:(NSInteger)generateKeyCallCount {
  @synchronized(self) {
    _generateKeyCallCount = generateKeyCallCount;
  }
}

- (NSString *)keyIdToReturn {
  @synchronized(self) {
    return _keyIdToReturn;
  }
}

- (void)setKeyIdToReturn:(nullable NSString *)keyIdToReturn {
  @synchronized(self) {
    _keyIdToReturn = keyIdToReturn;
  }
}

- (NSError *)generateKeyErrorToReturn {
  @synchronized(self) {
    return _generateKeyErrorToReturn;
  }
}

- (void)setGenerateKeyErrorToReturn:(nullable NSError *)generateKeyErrorToReturn {
  @synchronized(self) {
    _generateKeyErrorToReturn = generateKeyErrorToReturn;
  }
}

- (NSInteger)attestKeyCallCount {
  @synchronized(self) {
    return _attestKeyCallCount;
  }
}

- (void)setAttestKeyCallCount:(NSInteger)attestKeyCallCount {
  @synchronized(self) {
    _attestKeyCallCount = attestKeyCallCount;
  }
}

- (NSData *)attestationToReturn {
  @synchronized(self) {
    return _attestationToReturn;
  }
}

- (void)setAttestationToReturn:(nullable NSData *)attestationToReturn {
  @synchronized(self) {
    _attestationToReturn = attestationToReturn;
  }
}

- (NSError *)attestKeyErrorToReturn {
  @synchronized(self) {
    return _attestKeyErrorToReturn;
  }
}

- (void)setAttestKeyErrorToReturn:(nullable NSError *)attestKeyErrorToReturn {
  @synchronized(self) {
    _attestKeyErrorToReturn = attestKeyErrorToReturn;
  }
}

- (NSInteger)generateAssertionCallCount {
  @synchronized(self) {
    return _generateAssertionCallCount;
  }
}

- (void)setGenerateAssertionCallCount:(NSInteger)generateAssertionCallCount {
  @synchronized(self) {
    _generateAssertionCallCount = generateAssertionCallCount;
  }
}

- (NSData *)assertionToReturn {
  @synchronized(self) {
    return _assertionToReturn;
  }
}

- (void)setAssertionToReturn:(nullable NSData *)assertionToReturn {
  @synchronized(self) {
    _assertionToReturn = assertionToReturn;
  }
}

- (NSError *)generateAssertionErrorToReturn {
  @synchronized(self) {
    return _generateAssertionErrorToReturn;
  }
}

- (void)setGenerateAssertionErrorToReturn:(nullable NSError *)generateAssertionErrorToReturn {
  @synchronized(self) {
    _generateAssertionErrorToReturn = generateAssertionErrorToReturn;
  }
}

@end
