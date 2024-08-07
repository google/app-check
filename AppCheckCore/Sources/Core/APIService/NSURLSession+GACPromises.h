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

@class FBLPromise<Value>;
@class GACURLSessionDataResponse;

NS_ASSUME_NONNULL_BEGIN

/** Promise based API for `NSURLSession`. */
@interface NSURLSession (GACPromises)

/** Creates a promise wrapping `-[NSURLSession dataTaskWithRequest:completionHandler:]` method.
 * @param URLRequest The request to create a data task with.
 * @return A promise that is fulfilled when an HTTP response is received (with any response code),
 * or is rejected with the error passed to the task completion.
 */
- (FBLPromise<GACURLSessionDataResponse *> *)gac_dataTaskPromiseWithRequest:
    (NSURLRequest *)URLRequest;

@end

NS_ASSUME_NONNULL_END
