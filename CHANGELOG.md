# 11.3.0
- [changed] Add a retry for 401 failures. (https://github.com/firebase/firebase-ios-sdk/issues/15372)

# 11.2.0
- [changed] To prevent reusing expired artifacts, skip local cache when making
  network requests.

# 11.1.0
- [changed] Fall back to App Attest attestation phase if assertion phase fails
  with DeviceCheck error.

# 11.0.1 (SwiftPM Only)
- [changed] Lowered the minimum supported Mac Catalyst version to 13.0.
  This aligns with the minimum supported Mac Catalyst version for the
  CocoaPods distribution.

# 11.0.0
- [changed] **Breaking change**: AppCheckCore's minimum supported versions have
  updated for the following platforms:
    - | Platform  | AppCheckCore 11 |
      | ------------- | ------------- |
      | iOS  | **12.0**  |
      | tvOS  | **13.0**  |
      | macOS  | **10.15**  |
      | watchOS  | 7.0  |

# 10.19.2
- [fixed] Addressed possible nil pointer crash. (https://github.com/firebase/firebase-ios-sdk/issues/12365)

# 10.19.1
- [fixed] Added invalid input error handling in App Attest key attestation. (#54)

# 10.19.0
- [changed] Removed usages of user defaults API to eliminate required reason impact.

# 10.18.2
- [changed] Added data hashes and system version to App Attest error messages. (#50)

# 10.18.1
- [changed] Added underlying `DCError` descriptions to App Attest error messages. (#47)

# 10.18.0
- Initial release.
- Core functionality extracted from
  [FirebaseAppCheck 10.17.0](https://github.com/firebase/firebase-ios-sdk/tree/10.17.0/FirebaseAppCheck).
