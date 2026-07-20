# API Reference

This section provides a high-level overview of the main classes and protocols within `AppCheckCore`. For detailed API documentation, please refer to the header files directly.

## Core Classes

### `GACAppCheck`
The central class for managing App Check tokens. It serves as the primary entry point for your application to interact with the App Check system.

*   **Purpose:** Manages the lifecycle of App Check tokens, including fetching, caching, and refreshing. It delegates attestation logic to an `GACAppCheckProvider` instance.
*   **Key Methods:**
    *   `tokenForcingRefresh:completion:`: Requests an App Check token, with an option to force a refresh, bypassing the cache.
    *   `limitedUseTokenWithCompletion:`: Requests a limited-use App Check token, which does not affect the primary token's refresh cycle.

### `GACAppCheckSettings`
Provides configurable settings for the `AppCheckCore` library.

*   **Purpose:** Allows customization of various behaviors, such as token refresh intervals or logging levels.

### `GACAppCheckToken`
Represents an App Check token received from the App Check backend.

*   **Properties:**
    *   `token` (`NSString *`): The actual App Check token string.
    *   `expirationDate` (`NSDate *`): The date and time when the token expires.

### `GACAppCheckTokenResult`
A wrapper object containing either an `GACAppCheckToken` upon success or an `NSError` upon failure.

*   **Properties:**
    *   `token` (`GACAppCheckToken * _Nullable`): The App Check token if the request was successful.
    *   `error` (`NSError * _Nullable`): An error object if the token request failed.

## Protocols

### `GACAppCheckProvider`
A protocol that defines the interface for App Check providers. Custom providers must conform to this protocol.

*   **Purpose:** Abstracts the specifics of how App Check tokens are obtained. Implementations interact with platform-specific attestation services or provide mock tokens.
*   **Key Methods:**
    *   `getTokenWithCompletion:`: Asynchronously fetches a new App Check token.
    *   `getLimitedUseTokenWithCompletion:`: Asynchronously fetches a new limited-use App Check token.

### `GACAppCheckTokenDelegate`
A protocol for delegates that wish to receive notifications about App Check token updates.

*   **Purpose:** Allows your application to react to changes in the App Check token, such as when a new token is fetched or an existing one is refreshed.
*   **Key Methods:**
    *   `appCheck:didChangeToken:`: Notifies the delegate when the App Check token changes.
