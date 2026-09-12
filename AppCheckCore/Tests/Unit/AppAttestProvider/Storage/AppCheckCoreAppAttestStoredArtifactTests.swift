// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import AppCheckCore
import XCTest

class AppCheckCoreAppAttestStoredArtifactTests: XCTestCase {
  // IMMUTABLE TEST: Do not edit, update, or remove under any circumstance.
  // This test locks in an immutable backwards compatibility contract with App Check 11.
  // If this test fails, revert changes to the implementation instead of modifying this test.
  func testKeychainService_MatchesContract() {
    XCTAssertEqual(
      AppCheckCoreAppAttestArtifactStorage.keychainService,
      "com.firebase.app_check.app_attest_artifact_storage",
      "Keychain service name mismatch breaks App Check 11 migration compatibility."
    )
  }

  func testLegacyStoredArtifactCompatibility() throws {
    let fixtureData = try AppCheckCoreFixtureLoader
      .loadFixture(named: "GACAppAttestStoredArtifact.bin")

    let unarchived = try XCTUnwrap(
      NSKeyedUnarchiver.unarchivedObject(
        ofClass: AppCheckCoreAppAttestStoredArtifact.self,
        from: fixtureData
      ),
      "Failed to unarchive legacy GACAppAttestStoredArtifact binary fixture."
    )

    XCTAssertEqual(
      unarchived.keyID,
      "test_legacy_key_id_12345",
      "Key ID mismatch when unarchiving legacy GACAppAttestStoredArtifact."
    )

    let expectedArtifactData = try XCTUnwrap("test_legacy_artifact_data_bytes".data(using: .utf8))
    XCTAssertEqual(
      unarchived.artifact,
      expectedArtifactData,
      "Artifact data mismatch when unarchiving legacy GACAppAttestStoredArtifact."
    )
    XCTAssertEqual(
      unarchived.storageVersion,
      1,
      "Storage version mismatch when unarchiving legacy GACAppAttestStoredArtifact."
    )
  }

  func testStoredArtifactRoundTrip() throws {
    let expectedData = try XCTUnwrap("round_trip_artifact_payload".data(using: .utf8))
    let artifact = AppCheckCoreAppAttestStoredArtifact(
      keyID: "round_trip_key_id",
      artifact: expectedData
    )

    let archivedData = try NSKeyedArchiver.archivedData(
      withRootObject: artifact,
      requiringSecureCoding: true
    )

    let unarchived = try XCTUnwrap(
      NSKeyedUnarchiver.unarchivedObject(
        ofClass: AppCheckCoreAppAttestStoredArtifact.self,
        from: archivedData
      )
    )

    XCTAssertEqual(unarchived.keyID, artifact.keyID)
    XCTAssertEqual(unarchived.artifact, artifact.artifact)
    XCTAssertEqual(unarchived.storageVersion, 1)
  }

  func testSecureCoding_RejectsEmptyKeyID() throws {
    let invalidArtifact = AppCheckCoreAppAttestStoredArtifact(
      keyID: "",
      artifact: Data("valid_payload".utf8)
    )

    let archivedData = try NSKeyedArchiver.archivedData(
      withRootObject: invalidArtifact,
      requiringSecureCoding: true
    )

    let unarchived = try? NSKeyedUnarchiver.unarchivedObject(
      ofClass: AppCheckCoreAppAttestStoredArtifact.self,
      from: archivedData
    )
    XCTAssertNil(unarchived, "Unarchiving must reject empty keyID string.")
  }

  func testSecureCoding_RejectsEmptyArtifactData() throws {
    let invalidArtifact = AppCheckCoreAppAttestStoredArtifact(
      keyID: "valid_key_id",
      artifact: Data()
    )

    let archivedData = try NSKeyedArchiver.archivedData(
      withRootObject: invalidArtifact,
      requiringSecureCoding: true
    )

    let unarchived = try? NSKeyedUnarchiver.unarchivedObject(
      ofClass: AppCheckCoreAppAttestStoredArtifact.self,
      from: archivedData
    )
    XCTAssertNil(unarchived, "Unarchiving must reject zero-byte artifact payload.")
  }

  func testUnarchiving_CorruptedDataFailsGracefully() {
    let corruptedBytes = Data([0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE])
    XCTAssertThrowsError(
      try NSKeyedUnarchiver.unarchivedObject(
        ofClass: AppCheckCoreAppAttestStoredArtifact.self,
        from: corruptedBytes
      )
    )

    let truncatedBytes = Data("bplist00".utf8)
    XCTAssertThrowsError(
      try NSKeyedUnarchiver.unarchivedObject(
        ofClass: AppCheckCoreAppAttestStoredArtifact.self,
        from: truncatedBytes
      )
    )
  }

  func testDowngradeCompatibility_RuntimeClassNameAndEncodedPropertyTypes() throws {
    XCTAssertEqual(
      NSStringFromClass(AppCheckCoreAppAttestStoredArtifact.self),
      "GACAppAttestStoredArtifact",
      "Runtime class name must equal GACAppAttestStoredArtifact for Objective-C 11 unarchiving."
    )

    let artifact = AppCheckCoreAppAttestStoredArtifact(
      keyID: "test_key",
      artifact: Data("test_payload".utf8)
    )

    let archivedData = try NSKeyedArchiver.archivedData(
      withRootObject: artifact,
      requiringSecureCoding: true
    )

    let unarchived = try XCTUnwrap(
      NSKeyedUnarchiver.unarchivedObject(
        ofClass: AppCheckCoreAppAttestStoredArtifact.self,
        from: archivedData
      )
    )
    XCTAssertTrue((unarchived.keyID as Any) is String)
    XCTAssertTrue((unarchived.artifact as Any) is Data)
    XCTAssertTrue((unarchived.storageVersion as Any) is Int)
  }
}
