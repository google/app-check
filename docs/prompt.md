Create a comprehensive documentation website structure in a `docs/` directory for the **App Check Core** library. The documentation should be written in Markdown and include the following pages. Use Mermaid diagrams where appropriate to illustrate architecture and flows.

### 1. `docs/index.md` (Home/Overview)
*   **Title:** App Check Core - Documentation
*   **Introduction:** Explain that `AppCheckCore` is the underlying engine for app attestation and token management, primarily used by the Firebase iOS SDK but designed for broader internal Google use. Mention it supports iOS, macOS, tvOS, and watchOS.
*   **Key Features:**
    *   Manages App Check tokens (caching, refreshing).
    *   Abstracts different attestation providers (DeviceCheck, AppAttest, Debug).
    *   Handles limited-use tokens.
*   **Architecture Diagram (Mermaid):** Create a class diagram showing the relationship between:
    *   `GACAppCheck` (The core manager)
    *   `GACAppCheckProvider` (The protocol)
    *   Implementations: `GACAppAttestProvider`, `GACDeviceCheckProvider`, `GACAppCheckDebugProvider`.
    *   `GACAppCheckToken` (The result).

### 2. `docs/getting-started.md`
*   **Installation:**
    *   **CocoaPods:** Explain how to add `pod 'AppCheckCore'` to the Podfile.
    *   **Swift Package Manager:** Explain how to add the package via Xcode or `Package.swift` (URL: `https://github.com/google/app-check`).
*   **Prerequisites:** List minimum OS versions (iOS 12.0+, macOS 10.15+, etc., based on `Package.swift`).

### 3. `docs/usage.md` (Core Integration)
*   **Initialization:**
    *   Show how to initialize a provider (e.g., `GACAppAttestProvider`).
    *   Show how to initialize `GACAppCheck` with that provider, a service name, and a resource name.
    *   *Code Example (Swift & Obj-C):*
        ```swift
        let provider = AppCheckCoreAppAttestProvider(serviceName: "my-sdk", resourceName: "projects/123/apps/abc", ...)
        let appCheck = AppCheckCore(serviceName: "my-sdk", resourceName: "...", appCheckProvider: provider, ...)
        ```
*   **Fetching Tokens:**
    *   Explain `token(forcingRefresh:completion:)`.
    *   Explain `limitedUseToken(completion:)`.
    *   *Code Example:* How to call these methods and handle the `GACAppCheckTokenResult`.
*   **Sequence Diagram (Mermaid):** A sequence diagram showing the flow:
    1.  App asks `GACAppCheck` for a token.
    2.  `GACAppCheck` checks cache.
    3.  If missing/expired, `GACAppCheck` asks `GACAppCheckProvider` for a token.
    4.  Provider contacts Apple/Backend.
    5.  Token returned and cached.

### 4. `docs/providers.md`
*   **Overview:** Explain the concept of providers.
*   **AppAttest Provider (`GACAppAttestProvider`):**
    *   Best for modern iOS devices (A11 chip+).
    *   Wraps `DCAppAttestService`.
    *   Requires `DeviceCheck` framework linkage.
*   **DeviceCheck Provider (`GACDeviceCheckProvider`):
    *   Uses Apple's older `DCDevice` API.
    *   Good fallback for older devices.
*   **Debug Provider (`GACAppCheckDebugProvider`):
    *   Explain its use for local development and CI (simulators).
    *   Mention it generates a local debug secret that needs to be registered in the backend.

### 5. `docs/api-reference.md`
*   **Core Classes:**
    *   `GACAppCheck`: The main entry point.
    *   `GACAppCheckSettings`: Managing settings.
    *   `GACAppCheckToken`: Properties (token string, expiration date).
    *   `GACAppCheckTokenResult`: Wrapper for token + error.
*   **Protocols:**
    *   `GACAppCheckProvider`: The interface for creating custom providers.
    *   `GACAppCheckTokenDelegate`: For listening to token changes.

### 6. `docs/contributing.md`
*   Link to the root `CONTRIBUTING.md`.
*   Briefly mention the development setup (running `setup-scripts.sh`, generating project files).

### General Guidelines
*   Use clear, professional language.
*   Provide Swift and Objective-C code snippets where relevant (the library is Obj-C but Swift-friendly).
*   Ensure the directory structure matches the requested `docs/` layout.
