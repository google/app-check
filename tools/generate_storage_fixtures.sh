#!/usr/bin/env bash

# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TAG="${1:-11.0.0}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Extracting legacy source files from git ref ${TAG}..."
mkdir -p "${TMP_DIR}/AppCheckCore/Sources/Core/Storage"
mkdir -p "${TMP_DIR}/AppCheckCore/Sources/AppAttestProvider/Storage"

git -C "${REPO_ROOT}" show "${TAG}:AppCheckCore/Sources/Core/Storage/GACAppCheckStoredToken.h" > "${TMP_DIR}/AppCheckCore/Sources/Core/Storage/GACAppCheckStoredToken.h"
git -C "${REPO_ROOT}" show "${TAG}:AppCheckCore/Sources/Core/Storage/GACAppCheckStoredToken.m" > "${TMP_DIR}/AppCheckCore/Sources/Core/Storage/GACAppCheckStoredToken.m"
git -C "${REPO_ROOT}" show "${TAG}:AppCheckCore/Sources/AppAttestProvider/Storage/GACAppAttestStoredArtifact.h" > "${TMP_DIR}/AppCheckCore/Sources/AppAttestProvider/Storage/GACAppAttestStoredArtifact.h"
git -C "${REPO_ROOT}" show "${TAG}:AppCheckCore/Sources/AppAttestProvider/Storage/GACAppAttestStoredArtifact.m" > "${TMP_DIR}/AppCheckCore/Sources/AppAttestProvider/Storage/GACAppAttestStoredArtifact.m"

cat << 'EOF' > "${TMP_DIR}/main.m"
#import <Foundation/Foundation.h>
#import "AppCheckCore/Sources/Core/Storage/GACAppCheckStoredToken.h"
#import "AppCheckCore/Sources/AppAttestProvider/Storage/GACAppAttestStoredArtifact.h"

int main(int argc, const char * argv[]) {
  @autoreleasepool {
    if (argc < 3) {
      NSLog(@"Usage: %s <token_out_path> <artifact_out_path>", argv[0]);
      return 1;
    }
    NSString *tokenPath = [NSString stringWithUTF8String:argv[1]];
    NSString *artifactPath = [NSString stringWithUTF8String:argv[2]];

    // 1. Generate GACAppCheckStoredToken fixture
    GACAppCheckStoredToken *token = [[GACAppCheckStoredToken alloc] init];
    token.token = @"test_legacy_app_check_token_value";
    token.expirationDate = [NSDate dateWithTimeIntervalSince1970:1800000000];
    token.receivedAtDate = [NSDate dateWithTimeIntervalSince1970:1700000000];

    NSError *error = nil;
    NSData *tokenData = [NSKeyedArchiver archivedDataWithRootObject:token requiringSecureCoding:YES error:&error];
    if (!tokenData || error) {
      NSLog(@"Failed to archive GACAppCheckStoredToken: %@", error);
      return 1;
    }
    if (![tokenData writeToFile:tokenPath atomically:YES]) {
      NSLog(@"Failed to write token data to %@", tokenPath);
      return 1;
    }
    NSLog(@"Wrote GACAppCheckStoredToken fixture to %@", tokenPath);

    // 2. Generate GACAppAttestStoredArtifact fixture
    NSString *keyID = @"test_legacy_key_id_12345";
    NSData *artifactData = [@"test_legacy_artifact_data_bytes" dataUsingEncoding:NSUTF8StringEncoding];
    GACAppAttestStoredArtifact *artifact = [[GACAppAttestStoredArtifact alloc] initWithKeyID:keyID artifact:artifactData];

    NSData *archivedArtifact = [NSKeyedArchiver archivedDataWithRootObject:artifact requiringSecureCoding:YES error:&error];
    if (!archivedArtifact || error) {
      NSLog(@"Failed to archive GACAppAttestStoredArtifact: %@", error);
      return 1;
    }
    if (![archivedArtifact writeToFile:artifactPath atomically:YES]) {
      NSLog(@"Failed to write artifact data to %@", artifactPath);
      return 1;
    }
    NSLog(@"Wrote GACAppAttestStoredArtifact fixture to %@", artifactPath);
  }
  return 0;
}
EOF

echo "Compiling generator with clang..."
clang -fobjc-arc -framework Foundation \
  -I "${TMP_DIR}" \
  "${TMP_DIR}/main.m" \
  "${TMP_DIR}/AppCheckCore/Sources/Core/Storage/GACAppCheckStoredToken.m" \
  "${TMP_DIR}/AppCheckCore/Sources/AppAttestProvider/Storage/GACAppAttestStoredArtifact.m" \
  -o "${TMP_DIR}/generate_fixtures"

echo "Running generator..."
FIXTURES_DIR="${REPO_ROOT}/AppCheckCore/Tests/Fixture"
mkdir -p "${FIXTURES_DIR}"
"${TMP_DIR}/generate_fixtures" \
  "${FIXTURES_DIR}/GACAppCheckStoredToken.bin" \
  "${FIXTURES_DIR}/GACAppAttestStoredArtifact.bin"

echo "Fixture generation complete."
