# Getting Started

## Installation

### CocoaPods
To integrate `AppCheckCore` using CocoaPods, add the following to your `Podfile`:

```ruby
pod 'AppCheckCore'
```

Then, run `pod install` from your terminal.

### Swift Package Manager
You can add `AppCheckCore` to your project using Swift Package Manager in Xcode or by adding it to your `Package.swift` file.

**Xcode:**
1.  In Xcode, go to `File > Add Packages...`
2.  Enter the repository URL: `https://github.com/google/app-check`
3.  Choose the desired version or branch.

**Package.swift:**
Add the following to your `Package.swift` dependencies:

```swift
.package(url: "https://github.com/google/app-check", from: "1.0.0"), // Replace with the latest version
```

And then add `"AppCheckCore"` to your target's dependencies.

## Prerequisites
`AppCheckCore` supports the following minimum OS versions:
*   iOS 12.0+
*   macCatalyst 13.0+
*   macOS 10.15+
*   tvOS 13.0+
*   watchOS 7.0+
