# Architecture & Design

This document details the internal architecture of `AppCheckCore`,
focusing on token storage, lifecycle management, and security
mechanisms.

## Token Storage
App Check tokens are sensitive credentials that grant access to your
backend resources. `AppCheckCore` treats them with high security.

### Keychain Storage
The `GACAppCheckStorage` class is responsible for persisting App Check
tokens.
*   **Mechanism:** It uses the iOS Keychain via `GULKeychainStorage`.
*   **Service Name:** `com.google.app_check_core.token_storage`.
*   **Data Protection:** Tokens are stored as `GACAppCheckStoredToken`
    objects (conforming to `NSSecureCoding`).
*   **Access Groups:** Supports sharing tokens across apps/extensions
    via Keychain Access Groups (configurable during initialization).

### Artifact Storage (App Attest)
For the App Attest provider, intermediate artifacts are also stored to
maintain a stable device identity.
*   **Class:** `GACAppAttestArtifactStorage`
*   **Storage:** Keychain.
*   **Key Suffix:** Keys are namespaced by the service name and resource
    name (e.g., `my-sdk.projects/123/apps/abc`) to prevent collisions.

## Token Lifecycle Management
The `GACAppCheck` class acts as the central coordinator.

1.  **Request:** The app requests a token via
    `token(forcingRefresh:completion:)`.
2.  **Cache Check:**
    *   If `forcingRefresh` is `NO`: Checks `GACAppCheckStorage` for a
        valid, non-expired token.
    *   **Buffer Time:** Tokens are considered "expired" slightly before
        their actual expiration time to account for clock skew and
        network latency.
3.  **Fetch (if needed):**
    *   If the cache is empty or expired, or `forcingRefresh` is `YES`,
        a request is made to the configured `GACAppCheckProvider`.
4.  **Storage:**
    *   Upon successful retrieval, the new token is written to
        `GACAppCheckStorage`.
    *   Any old token is overwritten.
5.  **Completion:** The token (cached or new) is returned to the caller.

## Exponential Backoff Strategy
To prevent overwhelming the backend or Apple's servers during failures,
`AppCheckCore` implements a robust exponential backoff strategy via
`GACAppCheckBackoffWrapper`.

### Algorithm
The backoff interval is calculated as follows:
$$
\text{Interval} = \min(\text{Base} \times \text{Jitter}, \text{MaxInterval})
$$
*   **Base:** $2^{\text{retry\_count}}$ seconds.
*   **Jitter:** A random multiplier between $1.0$ and $1.5$ (to prevent
    thundering herd problems).
*   **MaxInterval:** 4 hours.

### Error Policies
The backoff behavior depends on the error type, specifically HTTP status
codes returned by the backend:

| HTTP Status Code | Backoff Type | Reason |
| :--- | :--- | :--- |
| **< 400** | **None** | Network errors or successful requests do not
    trigger backoff. |
| **400 (Bad Request)**<br>**404 (Not Found)** | **1 Day** | Indicates a
    project misconfiguration or outdated app version. Unlikely to
    resolve quickly. |
| **403 (Forbidden)**<br>**429 (Too Many Requests)**<br>**503 (Service
    Unavailable)** | **Exponential** | Indicates soft deletion, rate
    limiting, or server overload. Retrying later is appropriate. |
| **Other 5xx** | **Exponential** | Standard server errors. |

### Implementation
*   **Class:** `GACAppCheckBackoffWrapper`
*   **Usage:** Providers (`GACAppAttestProvider`, `GACDeviceCheckProvider`)
    wrap their network and attestation calls in this backoff mechanism.
*   **State:** The wrapper tracks the failure count and the last failure
    time. It resets to 0 upon a successful token fetch.

## Threading Model
*   **Concurrency:** `AppCheckCore` is designed to be thread-safe.
*   **Queues:**
    *   **Main Queue:** Completion handlers are typically dispatched to
        the main queue.
    *   **Internal Queues:** Providers use private serial queues (e.g.,
        `com.google.GACAppAttestProvider`) to manage state and
        sequentialize complex attestation flows (like generating a key,
        then attesting, then exchanging).
    *   **Background:** Network requests are performed on background
        queues (`QOS_CLASS_DEFAULT` or `QOS_CLASS_UTILITY`).
