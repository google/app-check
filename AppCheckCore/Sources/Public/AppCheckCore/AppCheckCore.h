/*
 * Copyright 2020 Google LLC
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

#import "GACAppCheckAvailability.h"
#import "GACAppCheckErrors.h"
#import "_GACAppCheckErrorUtil.h"

#import <Foundation/Foundation.h>

@protocol GACAppCheckTimerProtocol;
@class GACAppCheckTokenRefreshResult;

typedef id<GACAppCheckTimerProtocol> _Nullable (^GACTimerProvider)(NSDate *_Nonnull fireDate,
                                                                   dispatch_queue_t _Nonnull queue,
                                                                   dispatch_block_t _Nonnull block);
typedef void (^GACAppCheckTokenRefreshCompletion)(
    GACAppCheckTokenRefreshResult *_Nonnull refreshResult);
typedef void (^GACAppCheckTokenRefreshBlock)(
    void (^_Nonnull completion)(GACAppCheckTokenRefreshResult *_Nonnull refreshResult));

@class FBLPromise;
typedef FBLPromise *_Nonnull (^GACAppCheckBackoffOperationProvider)(void);
typedef NSInteger (^GACAppCheckBackoffErrorHandler)(NSError *_Nonnull error);
typedef void (^GACAppCheckAPIRequestHook)(NSMutableURLRequest *_Nonnull request);
