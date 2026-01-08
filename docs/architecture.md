# Architecture & Design

This document details the internal architecture of `AppCheckCore`, focusing on token storage, lifecycle management, and security mechanisms.

## Token Storage
App Check tokens are sensitive credentials that grant access to your backend resources. `AppCheckCore` treats them with high security.

### Keychain Storage
The `GACAppCheckStorage` class is responsible for persisting App Check tokens.
*   **Mechanism:** It uses the iOS Keychain via `GULKeychainStorage`.
*   **Service Name:** `com.google.app_check_core.token_storage`.
*   **Data Protection:** Tokens are stored as `GACAppCheckStoredToken` objects (conforming to `NSSecureCoding`).
*   **Access Groups:** Supports sharing tokens across apps/extensions via Keychain Access Groups (configurable during initialization).

### Artifact Storage (App Attest)
For the App Attest provider, intermediate artifacts are also stored to maintain a stable device identity.
*   **Class:** `GACAppAttestArtifactStorage`
*   **Storage:** Keychain.
*   **Key Suffix:** Keys are namespaced by the service name and resource name (e.g., `my-sdk.projects/123/apps/abc`) to prevent collisions.

## Token Lifecycle Management
The `GACAppCheck` class acts as the central coordinator.

1.  **Request:** The app requests a token via `token(forcingRefresh:completion:)`.
2.  **Cache Check:**
    *   If `forcingRefresh` is `NO`: Checks `GACAppCheckStorage` for a valid, non-expired token.
    *   **Buffer Time:** Tokens are considered "expired" slightly before their actual expiration time to account for clock skew and network latency.
3.  **Fetch (if needed):**
    *   If the cache is empty or expired, or `forcingRefresh` is `YES`, a request is made to the configured `GACAppCheckProvider`.
4.  **Storage:**
    *   Upon successful retrieval, the new token is written to `GACAppCheckStorage`.
    *   Any old token is overwritten.
5.  **Completion:** The token (cached or new) is returned to the caller.

## Backoff Strategy
To prevent overwhelming the backend or Apple's servers during failures, `AppCheckCore` implements an exponential backoff strategy.
*   **Class:** `GACAppCheckBackoffWrapper`
*   **Usage:** Providers (`GACAppAttestProvider`, `GACDeviceCheckProvider`) wrap their network and attestation calls in this backoff mechanism.
*   **Behavior:** Retries with increasing delays on retryable errors (e.g., network timeouts, temporary server errors 503). Non-retryable errors (e.g., 403 Forbidden, 400 Bad Request) fail immediately.

## Threading Model
*   **Concurrency:** `AppCheckCore` is designed to be thread-safe.
*   **Queues:**
    *   **Main Queue:** Completion handlers are typically dispatched to the main queue (or a user-specified queue if the API supported it, but currently defaults to main for top-level APIs).
    *   **Internal Queues:** Providers use private serial queues (e.g., `com.google.GACAppAttestProvider`) to manage state and sequentialize complex attestation flows (like generating a key, then attesting, then exchanging).
    *   **Background:** Network requests are performed on background queues (`QOS_CLASS_DEFAULT` or `QOS_CLASS_UTILITY`).
