/*
 * Copyright 2021 Google LLC
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

#import "AppCheckCore/Tests/Unit/Utils/GACFakeTimer.h"

@implementation GACFakeTimer

@synthesize createHandler = _createHandler;
@synthesize invalidationHandler = _invalidationHandler;
@synthesize handler = _handler;

- (GACTimerProvider)fakeTimerProvider {
  __weak __typeof__(self) weakSelf = self;
  return ^id<GACAppCheckTimerProtocol> _Nullable(NSDate *fireDate, dispatch_queue_t queue,
                                                 dispatch_block_t handler) {
    __typeof__(self) strongSelf = weakSelf;
    if (!strongSelf) {
      return nil;
    }

    @synchronized(strongSelf) {
      strongSelf->_handler = handler;
      void (^createHandler)(NSDate *) = strongSelf->_createHandler;
      if (createHandler) {
        createHandler(fireDate);
      }
    }

    return strongSelf;
  };
}

- (void)invalidate {
  void (^invalidationHandler)(void);
  @synchronized(self) {
    invalidationHandler = _invalidationHandler;
  }
  if (invalidationHandler) {
    invalidationHandler();
  }
}

- (nullable GACFakeTimerCreateHandler)createHandler {
  @synchronized(self) {
    return _createHandler;
  }
}

- (void)setCreateHandler:(nullable GACFakeTimerCreateHandler)createHandler {
  @synchronized(self) {
    _createHandler = createHandler;
  }
}

- (nullable dispatch_block_t)invalidationHandler {
  @synchronized(self) {
    return _invalidationHandler;
  }
}

- (void)setInvalidationHandler:(nullable dispatch_block_t)invalidationHandler {
  @synchronized(self) {
    _invalidationHandler = invalidationHandler;
  }
}

- (nullable dispatch_block_t)handler {
  @synchronized(self) {
    return _handler;
  }
}

- (void)setHandler:(nullable dispatch_block_t)handler {
  @synchronized(self) {
    _handler = handler;
  }
}

@end
