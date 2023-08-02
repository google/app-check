// swift-tools-version:5.7.1
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
      "2.1.0" ..< "3.0.0"
    ),
    .package(
      url: "https://github.com/google/GoogleUtilities.git",
      "7.11.0" ..< "8.0.0"
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
                .when(platforms: [.iOS, .macCatalyst, .macOS, .tvOS])
              ),
            ]),
    // TODO(andrewheard): Add unit test targets after removing Firebase dependencies.
  ],
  cLanguageStandard: .c99
)
