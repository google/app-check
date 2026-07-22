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

@synthesize baseURL = _baseURL;
@synthesize sendRequestPromise = _sendRequestPromise;
@synthesize appCheckTokenPromise = _appCheckTokenPromise;
@synthesize requestValidationBlock = _requestValidationBlock;
@synthesize passedRequestURL = _passedRequestURL;
@synthesize passedHTTPMethod = _passedHTTPMethod;
@synthesize passedBody = _passedBody;
@synthesize passedAdditionalHeaders = _passedAdditionalHeaders;
@synthesize passedAPIResponse = _passedAPIResponse;

- (FBLPromise<_GACURLSessionDataResponse *> *)
    sendRequestWithURL:(NSURL *)requestURL
            HTTPMethod:(NSString *)HTTPMethod
                  body:(nullable NSData *)body
     additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders {
  void (^validationBlock)(void);
  FBLPromise *promise;
  @synchronized(self) {
    _passedRequestURL = requestURL;
    _passedHTTPMethod = HTTPMethod;
    _passedBody = body;
    _passedAdditionalHeaders = additionalHeaders;
    promise = _sendRequestPromise;
    validationBlock = _requestValidationBlock;
  }

  if (validationBlock) {
    validationBlock();
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

- (NSString *)baseURL {
  @synchronized(self) {
    return _baseURL;
  }
}

- (void)setBaseURL:(NSString *)baseURL {
  @synchronized(self) {
    _baseURL = baseURL;
  }
}

- (void)setSendRequestPromise:(nullable FBLPromise<_GACURLSessionDataResponse *> *)sendRequestPromise {
  @synchronized(self) {
    _sendRequestPromise = sendRequestPromise;
  }
}

- (nullable FBLPromise<_GACURLSessionDataResponse *> *)sendRequestPromise {
  @synchronized(self) {
    return _sendRequestPromise;
  }
}

- (void)setAppCheckTokenPromise:(nullable FBLPromise<GACAppCheckToken *> *)appCheckTokenPromise {
  @synchronized(self) {
    _appCheckTokenPromise = appCheckTokenPromise;
  }
}

- (nullable FBLPromise<GACAppCheckToken *> *)appCheckTokenPromise {
  @synchronized(self) {
    return _appCheckTokenPromise;
  }
}

- (void)setRequestValidationBlock:(nullable void (^)(void))requestValidationBlock {
  @synchronized(self) {
    _requestValidationBlock = requestValidationBlock;
  }
}

- (nullable void (^)(void))requestValidationBlock {
  @synchronized(self) {
    return _requestValidationBlock;
  }
}

- (nullable NSURL *)passedRequestURL {
  @synchronized(self) {
    return _passedRequestURL;
  }
}

- (void)setPassedRequestURL:(nullable NSURL *)passedRequestURL {
  @synchronized(self) {
    _passedRequestURL = passedRequestURL;
  }
}

- (nullable NSString *)passedHTTPMethod {
  @synchronized(self) {
    return _passedHTTPMethod;
  }
}

- (void)setPassedHTTPMethod:(nullable NSString *)passedHTTPMethod {
  @synchronized(self) {
    _passedHTTPMethod = passedHTTPMethod;
  }
}

- (nullable NSData *)passedBody {
  @synchronized(self) {
    return _passedBody;
  }
}

- (void)setPassedBody:(nullable NSData *)passedBody {
  @synchronized(self) {
    _passedBody = passedBody;
  }
}

- (nullable NSDictionary<NSString *, NSString *> *)passedAdditionalHeaders {
  @synchronized(self) {
    return _passedAdditionalHeaders;
  }
}

- (void)setPassedAdditionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)passedAdditionalHeaders {
  @synchronized(self) {
    _passedAdditionalHeaders = passedAdditionalHeaders;
  }
}

- (nullable _GACURLSessionDataResponse *)passedAPIResponse {
  @synchronized(self) {
    return _passedAPIResponse;
  }
}

- (void)setPassedAPIResponse:(nullable _GACURLSessionDataResponse *)passedAPIResponse {
  @synchronized(self) {
    _passedAPIResponse = passedAPIResponse;
  }
}

@end
