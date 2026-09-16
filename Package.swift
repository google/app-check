// swift-tools-version:6.0
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
  platforms: [.iOS(.v15), .macCatalyst(.v15), .macOS(.v11), .tvOS(.v15), .watchOS(.v8)],
  products: [
    .library(
      name: "AppCheckCore",
      targets: ["AppCheckCore"]
    ),

    .library(
      name: "AppCheckRecaptchaProvider",
      targets: ["AppCheckRecaptchaProvider"]
    ),

  ],
  dependencies: [
    .package(
      url: "https://github.com/google/GoogleUtilities.git",
      "8.1.0" ..< "9.0.0"
    ),
    .package(
      url: "https://github.com/google/interop-ios-for-google-sdks.git",
      "101.0.0" ..< "102.0.0"
    ),
  ],
  targets: [
    .target(name: "AppCheckCore",
            dependencies: [
              .product(name: "GULEnvironment", package: "GoogleUtilities"),
              .product(name: "GULUserDefaults", package: "GoogleUtilities"),
            ],
            path: "AppCheckCore/Sources",
            publicHeadersPath: "Public",
            cSettings: [
              .headerSearchPath("../.."),
            ],
            linkerSettings: [
              .linkedFramework(
                "DeviceCheck",
                .when(platforms: [.iOS, .macCatalyst, .macOS, .tvOS, .visionOS])
              ),
            ]),
    .target(name: "AppCheckRecaptchaProvider",
            dependencies: [
              "AppCheckCore",
              .product(name: "RecaptchaInterop", package: "interop-ios-for-google-sdks"),
            ],
            path: "AppCheckRecaptchaProvider/Sources"),
    .testTarget(
      name: "AppCheckCoreUnit",
      dependencies: [
        "AppCheckCore",
      ],
      path: "AppCheckCore/Tests",
      exclude: [
        // Swift tests and ObjC tests are separated since mixed language targets are
        // not supported.
        "Unit/Swift",
        "Unit/ObjC",
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
    .testTarget(
      name: "AppCheckCoreUnitObjC",
      dependencies: ["AppCheckCore"],
      path: "AppCheckCore/Tests/Unit/ObjC",
      cSettings: [
        .headerSearchPath("../.."),
        .headerSearchPath("../../../Sources/Public"),
      ]
    ),
    .testTarget(
      name: "AppCheckRecaptchaProviderUnit",
      dependencies: [
        "AppCheckRecaptchaProvider",
      ],
      path: "AppCheckRecaptchaProvider/Tests"
    ),
  ],
  swiftLanguageModes: [.v5]
)
