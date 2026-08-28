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

#import "AppCheckCore/Sources/Core/APIService/GACAppCheckToken+APIResponse.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "AppCheckCore/Sources/Public/AppCheckCore/_GACAppCheckErrorUtil.h"

static NSString *const kResponseFieldToken = @"token";
static NSString *const kResponseFieldTTL = @"ttl";

@implementation GACAppCheckToken (APIResponse)

static NSDate *GACAppCheckTokenExpirationDateFromJWT(NSString *token) {
  NSArray<NSString *> *components = [token componentsSeparatedByString:@"."];
  if (components.count != 3) {
    return nil;
  }

  NSString *payloadBase64 = components[1];

  // Convert base64url to base64
  NSString *padded = [payloadBase64 stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
  padded = [padded stringByReplacingOccurrencesOfString:@"_" withString:@"/"];

  NSUInteger paddingLength = padded.length % 4;
  if (paddingLength > 0) {
    padded = [padded stringByPaddingToLength:padded.length + (4 - paddingLength)
                                  withString:@"="
                             startingAtIndex:0];
  }

  NSData *payloadData = [[NSData alloc] initWithBase64EncodedString:padded options:0];
  if (!payloadData) {
    return nil;
  }

  NSDictionary *payloadDict = [NSJSONSerialization JSONObjectWithData:payloadData
                                                              options:0
                                                                error:nil];
  if (![payloadDict isKindOfClass:[NSDictionary class]]) {
    return nil;
  }

  NSNumber *expValue = payloadDict[@"exp"];
  if (![expValue isKindOfClass:[NSNumber class]]) {
    return nil;
  }

  NSTimeInterval exp = expValue.doubleValue;
  return [NSDate dateWithTimeIntervalSince1970:exp];
}

- (nullable instancetype)initWithTokenExchangeResponse:(NSData *)response
                                           requestDate:(NSDate *)requestDate
                                                 error:(NSError **)outError {
  if (response.length <= 0) {
    GACAppCheckSetErrorToPointer(
        [_GACAppCheckErrorUtil errorWithFailureReason:@"Empty server response body."], outError);
    return nil;
  }

  NSError *JSONError;
  NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:response
                                                               options:0
                                                                 error:&JSONError];

  if (![responseDict isKindOfClass:[NSDictionary class]]) {
    GACAppCheckSetErrorToPointer([_GACAppCheckErrorUtil JSONSerializationError:JSONError],
                                 outError);
    return nil;
  }

  return [self initWithResponseDict:responseDict requestDate:requestDate error:outError];
}

- (nullable instancetype)initWithResponseDict:(NSDictionary<NSString *, id> *)responseDict
                                  requestDate:(NSDate *)requestDate
                                        error:(NSError **)outError {
  NSString *token = responseDict[kResponseFieldToken];
  if (![token isKindOfClass:[NSString class]]) {
    GACAppCheckSetErrorToPointer(
        [_GACAppCheckErrorUtil appCheckTokenResponseErrorWithMissingField:kResponseFieldToken],
        outError);
    return nil;
  }

  NSString *timeToLiveString = responseDict[kResponseFieldTTL];
  if (![timeToLiveString isKindOfClass:[NSString class]] || timeToLiveString.length <= 0) {
    GACAppCheckSetErrorToPointer(
        [_GACAppCheckErrorUtil appCheckTokenResponseErrorWithMissingField:kResponseFieldTTL],
        outError);
    return nil;
  }

  // Expect a string like "3600s" representing a time interval in seconds.
  NSString *timeToLiveValueString = [timeToLiveString stringByReplacingOccurrencesOfString:@"s"
                                                                                withString:@""];
  NSTimeInterval secondsToLive = timeToLiveValueString.doubleValue;

  if (secondsToLive == 0) {
    GACAppCheckSetErrorToPointer(
        [_GACAppCheckErrorUtil appCheckTokenResponseErrorWithMissingField:kResponseFieldTTL],
        outError);
    return nil;
  }

  NSDate *expirationDate = [requestDate dateByAddingTimeInterval:secondsToLive];
  NSDate *jwtExpirationDate = GACAppCheckTokenExpirationDateFromJWT(token);
  if (jwtExpirationDate && [jwtExpirationDate compare:expirationDate] == NSOrderedAscending) {
    expirationDate = jwtExpirationDate;
  }

  return [self initWithToken:token expirationDate:expirationDate receivedAtDate:requestDate];
}

@end
