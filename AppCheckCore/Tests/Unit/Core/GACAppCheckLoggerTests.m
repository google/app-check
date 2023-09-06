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

@import XCTest;

#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckLogger.h"

@interface GACAppCheckLoggerTests : XCTestCase
@end

@implementation GACAppCheckLoggerTests

- (void)testDefaultLogLevel {
  GACAppCheckLogLevel defaultLogLevel = GACAppCheckLogger.logLevel;

  XCTAssertEqual(defaultLogLevel, GACAppCheckLogLevelWarning);
}

- (void)testSetLogLevel {
  GACAppCheckLogLevel expectedLogLevel = GACAppCheckLogLevelDebug;

  GACAppCheckLogger.logLevel = expectedLogLevel;

  XCTAssertEqual(GACAppCheckLogger.logLevel, expectedLogLevel);
}

@end
