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

#import "AppCheckCore/Tests/Unit/Utils/GACKeychainStorageFake.h"

@implementation GACKeychainStorageFake

@synthesize keychainError = _keychainError;

- (instancetype)init {
  self = [super init];
  if (self) {
    _storage = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)getObjectForKey:(NSString *)key
            objectClass:(Class)objectClass
            accessGroup:(nullable NSString *)accessGroup
      completionHandler:(void (^)(id<NSSecureCoding> _Nullable, NSError *_Nullable))handler {
  NSError *error;
  @synchronized(self) {
    error = _keychainError;
  }
  if (error) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      handler(nil, error);
    });
    return;
  }

  id<NSSecureCoding> object;
  @synchronized(self) {
    object = _storage[key];
  }
  if (object && ![(id)object isKindOfClass:objectClass]) {
    object = nil;
  }
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    handler(object, nil);
  });
}

- (void)setObject:(id<NSSecureCoding>)object
               forKey:(NSString *)key
          accessGroup:(nullable NSString *)accessGroup
    completionHandler:(void (^)(id<NSSecureCoding> _Nullable, NSError *_Nullable))handler {
  NSError *error;
  @synchronized(self) {
    error = _keychainError;
  }
  if (error) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      handler(nil, error);
    });
    return;
  }

  @synchronized(self) {
    _storage[key] = object;
  }
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    handler(object, nil);
  });
}

- (void)removeObjectForKey:(NSString *)key
               accessGroup:(nullable NSString *)accessGroup
         completionHandler:(void (^)(NSError *_Nullable))handler {
  NSError *error;
  @synchronized(self) {
    error = _keychainError;
  }
  if (error) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      handler(error);
    });
    return;
  }

  @synchronized(self) {
    [_storage removeObjectForKey:key];
  }
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    handler(nil);
  });
}

- (nullable NSError *)keychainError {
  @synchronized(self) {
    return _keychainError;
  }
}

- (void)setKeychainError:(nullable NSError *)keychainError {
  @synchronized(self) {
    _keychainError = keychainError;
  }
}

@end
