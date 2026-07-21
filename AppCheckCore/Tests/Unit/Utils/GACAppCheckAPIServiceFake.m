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

#import "AppCheckCore/Tests/Unit/Utils/GACAppCheckAPIServiceFake.h"
#import "FBLPromise+Testing.h"

@implementation GACAppCheckAPIServiceFake

- (FBLPromise<_GACURLSessionDataResponse *> *)
    sendRequestWithURL:(NSURL *)requestURL
            HTTPMethod:(NSString *)HTTPMethod
                  body:(nullable NSData *)body
     additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders {
  FBLPromise *promise;
  @synchronized(self) {
    _passedRequestURL = requestURL;
    _passedHTTPMethod = HTTPMethod;
    _passedBody = body;
    _passedAdditionalHeaders = additionalHeaders;
    promise = _sendRequestPromise;
  }

  if (promise) {
    return promise;
  }
  return [FBLPromise pendingPromise];
}

- (FBLPromise<GACAppCheckToken *> *)appCheckTokenWithAPIResponse:
    (_GACURLSessionDataResponse *)response {
  FBLPromise *promise;
  @synchronized(self) {
    _passedAPIResponse = response;
    promise = _appCheckTokenPromise;
  }

  if (promise) {
    return promise;
  }
  return [FBLPromise pendingPromise];
}

@end
