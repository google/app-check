import Foundation

class AppCheckCoreFixtureLoader {
  static func loadFixture(named fileName: String) throws -> Data {
    var fileURL: URL?
    
    let possibleBundles = self.possibleResourceBundles()
    for bundle in possibleBundles {
      if let url = bundle.url(forResource: fileName, withExtension: nil) {
        fileURL = url
        print("Fixture named: \(fileName) was found at bundle \(bundle.bundleIdentifier ?? "unknown")")
        break
      }
    }
    
    guard let url = fileURL else {
      print("Fixture named \(fileName) not found")
      throw NSError(domain: "AppCheckCoreFixtureLoaderError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Fixture not found: \(fileName)"])
    }
    
    return try Data(contentsOf: url)
  }
  
  private static func possibleResourceBundles() -> [Bundle] {
    let bundleForClass = Bundle(for: self)
    
    // Swift Package Manager packages resources into separate bundles inside the test bundle.
    var bundlesForResources: [Bundle] = [bundleForClass]
    if let enclosedBundleURLs = bundleForClass.urls(forResourcesWithExtension: "bundle", subdirectory: nil) {
      for bundleURL in enclosedBundleURLs {
        if let bundle = Bundle(url: bundleURL) {
          bundlesForResources.append(bundle)
        }
      }
    }
    
    return bundlesForResources
  }
}
