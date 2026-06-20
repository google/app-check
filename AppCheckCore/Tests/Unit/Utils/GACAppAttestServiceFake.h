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

#import <Foundation/Foundation.h>
#import "AppCheckCore/Sources/AppAttestProvider/GACAppAttestService.h"

NS_ASSUME_NONNULL_BEGIN

@interface GACAppAttestServiceFake : NSObject <GACAppAttestService>

@property(nonatomic) BOOL isSupported;

@property(nonatomic) NSInteger generateKeyCallCount;
@property(nonatomic, copy, nullable) NSString *keyIdToReturn;
@property(nonatomic, nullable) NSError *generateKeyErrorToReturn;

@property(nonatomic) NSInteger attestKeyCallCount;
@property(nonatomic, copy, nullable) NSData *attestationToReturn;
@property(nonatomic, nullable) NSError *attestKeyErrorToReturn;

@property(nonatomic) NSInteger generateAssertionCallCount;
@property(nonatomic, copy, nullable) NSData *assertionToReturn;
@property(nonatomic, nullable) NSError *generateAssertionErrorToReturn;

@end

NS_ASSUME_NONNULL_END
