// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

// Copyright 2023 Google LLC
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

import PackageDescription

let package = Package(
  name: "AppCheck",
  platforms: [.iOS(.v12), .macCatalyst(.v13), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v7)],
  products: [
    .library(
      name: "AppCheckCore",
      targets: ["AppCheckCore","RecaptchaEnterpriseProvider"]
    ),
    .library(
        name: "AppCheckShared",
        targets: ["AppCheckShared"]
    ),
  ],
  dependencies: [
    .package(
      url: "https://github.com/google/promises.git",
      "2.4.0" ..< "3.0.0"
    ),
    .package(
      url: "https://github.com/google/GoogleUtilities.git",
      "8.0.0" ..< "9.0.0"
    ),
    .package(
      url: "https://github.com/erikdoe/ocmock.git",
      revision: "2c0bfd373289f4a7716db5d6db471640f91a6507"
    ),
    .package(
      url: "https://github.com/google/interop-ios-for-google-sdks.git",
      "101.0.0" ..< "102.0.0"
    ),
  ],
  targets: [
    .target(name: "AppCheckCore",
            dependencies: [
              .product(name: "FBLPromises", package: "Promises"),
              .product(name: "GULEnvironment", package: "GoogleUtilities"),
              .product(name: "GULUserDefaults", package: "GoogleUtilities"),
            ],
            path: "AppCheckCore/Sources",
            exclude: ["RecaptchaEnterpriseProvider","Shared"],
            publicHeadersPath: "Public",
            cSettings: [
              .headerSearchPath("../.."),
            ],
            linkerSettings: [
              .linkedFramework(
                "DeviceCheck",
                .when(platforms: [.iOS, .macCatalyst, .macOS, .tvOS, .appCheckVisionOS])
              ),
            ]),
    .target(name: "RecaptchaEnterpriseProvider",
           dependencies: [
            "AppCheckShared",
            .product(name:"RecaptchaInterop",package:"interop-ios-for-google-sdks")
           ],
           path: "AppCheckCore/Sources/RecaptchaEnterpriseProvider"),
    .target(name: "AppCheckShared",
           dependencies: [
            .product(name: "FBLPromises", package: "Promises"),
            .product(name: "GULEnvironment", package: "GoogleUtilities"),
           ],
            path:"AppCheckCore/Sources/Shared",
            publicHeadersPath: "Public",
            cSettings: [
              .headerSearchPath("../.."),
            ],
            linkerSettings: [
              .linkedFramework(
                "DeviceCheck",
                .when(platforms: [.iOS, .macCatalyst, .macOS, .tvOS, .appCheckVisionOS])
              ),
            ]),
    .testTarget(
      name: "AppCheckCoreUnit",
      dependencies: [
        "AppCheckCore",
        .product(name: "OCMock", package: "ocmock"),
      ],
      path: "AppCheckCore/Tests",
      exclude: [
        // Swift tests are in the target `AppCheckCoreUnitSwift` since mixed language targets are
        // not supported (as of Xcode 14.3).
        "Unit/Swift",
      ],
      resources: [
        .process("Fixture"),
      ],
      cSettings: [
        .headerSearchPath("../.."),
      ]
    ),
    .testTarget(
      name: "AppCheckCoreUnitSwift",
      dependencies: ["AppCheckCore"],
      path: "AppCheckCore/Tests/Unit/Swift",
      cSettings: [
        .headerSearchPath("../.."),
      ]
    ),
  ]
)

extension Platform {
  // Xcode dependent value for the visionOS platform. Namespaced with an "appCheck" prefix to
  // prevent any API collisions (such issues should not arise as the manifest APIs should be
  // confined to the `Package.swift`).
  static var appCheckVisionOS: Self {
    #if swift(>=5.9)
      // For Xcode 15, return the available `visionOS` platform.
      return .visionOS
    #else
      // For Xcode 14, return `iOS` as `visionOS` is unavailable. Since all targets support iOS,
      // this acts as a no-op.
      return .iOS
    #endif // swift(>=5.9)
  }
}
