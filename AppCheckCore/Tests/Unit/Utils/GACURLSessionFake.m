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

#import "AppCheckCore/Tests/Unit/Utils/GACURLSessionFake.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/_GACURLSessionDataResponse.h"
#import "FBLPromise+Testing.h"

@implementation GACURLSessionFake

- (FBLPromise<_GACURLSessionDataResponse *> *)gac_dataTaskPromiseWithRequest:
    (NSURLRequest *)URLRequest {
  FIRRequestValidationBlock validationBlock;
  FBLPromise *promise;
  @synchronized(self) {
    _isInvoked = YES;
    _lastRequest = URLRequest;
    validationBlock = _requestValidationBlock;
    promise = _resultPromise;
  }
  if (validationBlock) {
    validationBlock(URLRequest);
  }
  if (promise) {
    return promise;
  }
  return [FBLPromise pendingPromise];
}

+ (NSHTTPURLResponse *)HTTPResponseWithCode:(NSInteger)statusCode {
  return [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://url.com"]
                                     statusCode:statusCode
                                    HTTPVersion:@"HTTP/1.1"
                                   headerFields:nil];
}

@end
