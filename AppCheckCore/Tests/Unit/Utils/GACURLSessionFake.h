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

#import <Foundation/Foundation.h>

@class FBLPromise<ValueType>;
@class _GACURLSessionDataResponse;

NS_ASSUME_NONNULL_BEGIN

typedef BOOL (^FIRRequestValidationBlock)(NSURLRequest *request);

@interface GACURLSessionFake : NSObject

@property(nonatomic, nullable) FBLPromise<_GACURLSessionDataResponse *> *resultPromise;
@property(nonatomic, nullable) NSURLRequest *lastRequest;
@property(nonatomic, copy, nullable) FIRRequestValidationBlock requestValidationBlock;
@property(nonatomic, assign) BOOL isInvoked;

- (FBLPromise<_GACURLSessionDataResponse *> *)gac_dataTaskPromiseWithRequest:
    (NSURLRequest *)URLRequest;

+ (NSHTTPURLResponse *)HTTPResponseWithCode:(NSInteger)statusCode;

@end

NS_ASSUME_NONNULL_END
