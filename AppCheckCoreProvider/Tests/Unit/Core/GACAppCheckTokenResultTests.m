/*
 * Copyright 2023 Google LLC
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

#import <XCTest/XCTest.h>

#import "AppCheckCoreProvider/Sources/Public/AppCheckCoreProvider/GACAppCheckToken.h"
#import "AppCheckCoreProvider/Sources/Public/AppCheckCoreProvider/GACAppCheckTokenResult.h"

static NSString *const kTestTokenValue = @"test-token";
/// Placeholder value that indicates failure: `{"error":"UNKNOWN_ERROR"}` encoded as base64
static NSString *const kPlaceholderTokenValue = @"eyJlcnJvciI6IlVOS05PV05fRVJST1IifQ==";
static NSString *const kTestErrorDomain = @"TestErrorDomain";
static NSInteger const kTestErrorCode = 42;

@interface GACAppCheckTokenResult (Tests)

+ (GACAppCheckToken *)placeholderToken;

@end

@interface GACAppCheckTokenResultTests : XCTestCase
@end

@implementation GACAppCheckTokenResultTests

- (void)testInitWithToken {
  NSDate *expectedExpirationDate = [NSDate dateWithTimeIntervalSince1970:1693314000.0];
  NSDate *expectedReceivedAtDate = [NSDate dateWithTimeIntervalSince1970:1693317600.0];
  GACAppCheckToken *expectedToken = [[GACAppCheckToken alloc] initWithToken:kTestTokenValue
                                                             expirationDate:expectedExpirationDate
                                                             receivedAtDate:expectedReceivedAtDate];

  GACAppCheckTokenResult *tokenResult =
      [[GACAppCheckTokenResult alloc] initWithToken:expectedToken];

  XCTAssertEqualObjects(tokenResult.token, expectedToken);
  XCTAssertNil(tokenResult.error);
}

- (void)testInitWithError {
  NSError *expectedError = [NSError errorWithDomain:kTestErrorDomain
                                               code:kTestErrorCode
                                           userInfo:nil];

  GACAppCheckTokenResult *tokenResult =
      [[GACAppCheckTokenResult alloc] initWithError:expectedError];

  XCTAssertEqualObjects(tokenResult.token.token, kPlaceholderTokenValue);
  XCTAssertNotNil(tokenResult.error);
  XCTAssertEqualObjects(tokenResult.error, expectedError);
}

- (void)testInitWithTokenAndError {
  GACAppCheckToken *placeholderToken = [GACAppCheckTokenResult placeholderToken];
  NSError *expectedError = [NSError errorWithDomain:kTestErrorDomain
                                               code:kTestErrorCode
                                           userInfo:nil];

  GACAppCheckTokenResult *tokenResult =
      [[GACAppCheckTokenResult alloc] initWithToken:placeholderToken error:expectedError];

  XCTAssertEqualObjects(tokenResult.token, placeholderToken);
  XCTAssertNotNil(tokenResult.error);
  XCTAssertEqualObjects(tokenResult.error, expectedError);
}

- (void)testPlaceholderToken {
  NSDate *expectedExpirationDate = [NSDate distantPast];
  NSDate *expectedReceivedAtDate = [NSDate date];  // Current time

  GACAppCheckToken *placeholderToken = [GACAppCheckTokenResult placeholderToken];

  XCTAssertEqualObjects(placeholderToken.token, kPlaceholderTokenValue);
  // Verify that the placeholder token's received at time is approximately equal to current time.
  XCTAssertEqualWithAccuracy(
      [placeholderToken.receivedAtDate timeIntervalSinceDate:expectedReceivedAtDate], 0, 5.0);
  XCTAssertEqualObjects(placeholderToken.expirationDate, expectedExpirationDate);
}

@end
