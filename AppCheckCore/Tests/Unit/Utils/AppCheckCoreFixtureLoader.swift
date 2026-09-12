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

import Foundation

class AppCheckCoreFixtureLoader {
  static func loadFixture(named fileName: String) throws -> Data {
    var fileURL: URL?

    let possibleBundles = possibleResourceBundles()
    for bundle in possibleBundles {
      if let url = bundle.url(forResource: fileName, withExtension: nil) {
        fileURL = url
        print(
          "Fixture named: \(fileName) was found at bundle \(bundle.bundleIdentifier ?? "unknown")"
        )
        break
      }
    }

    guard let url = fileURL else {
      print("Fixture named \(fileName) not found")
      throw NSError(
        domain: "AppCheckCoreFixtureLoaderError",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Fixture not found: \(fileName)"]
      )
    }

    return try Data(contentsOf: url)
  }

  private static func possibleResourceBundles() -> [Bundle] {
    let bundleForClass = Bundle(for: self)

    // Swift Package Manager packages resources into separate bundles inside the test bundle.
    var bundlesForResources: [Bundle] = [bundleForClass]
    if let enclosedBundleURLs = bundleForClass.urls(
      forResourcesWithExtension: "bundle",
      subdirectory: nil
    ) {
      for bundleURL in enclosedBundleURLs {
        if let bundle = Bundle(url: bundleURL) {
          bundlesForResources.append(bundle)
        }
      }
    }
    #if SWIFT_PACKAGE
      bundlesForResources.append(Bundle.module)
    #endif

    return bundlesForResources
  }
}
