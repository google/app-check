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
  platforms: [.iOS(.v11), .macCatalyst(.v13), .macOS(.v10_13), .tvOS(.v12), .watchOS(.v7)],
  products: [
    .library(
      name: "AppCheckCore",
      targets: ["AppCheckCore"]
    ),
  ],
  dependencies: [
    .package(
      url: "https://github.com/google/promises.git",
      "2.3.1" ..< "3.0.0"
    ),
    .package(
      url: "https://github.com/google/GoogleUtilities.git",
      "7.11.5" ..< "8.0.0"
    ),
  ],
  targets: [
    .target(name: "AppCheckCore",
            dependencies: [
              .product(name: "FBLPromises", package: "Promises"),
              .product(name: "GULEnvironment", package: "GoogleUtilities"),
            ],
            path: "AppCheckCore/Sources",
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
    // TODO(andrewheard): Add unit test targets after removing Firebase dependencies.
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
