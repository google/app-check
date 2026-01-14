# AppAttest Provider (`GACAppAttestProvider`)

The most complex provider, interacting with `DCAppAttestService`. It
maintains a stable key pair on the device to sign assertions.

## Components
*   **Service:** `DCAppAttestService` (Apple's API).
*   **Storage:**
    *   `GACAppAttestKeyIDStorage`: Stores the generated App Attest Key
        ID.
        *   **Location:** `UserDefaults` (Suite: `com.firebase.GACAppAttestKeyIDStorage`).
    *   `GACAppAttestArtifactStorage`: Stores the "artifact" returned by
        the Firebase backend after a successful initial handshake. This
        artifact effectively links the on-device key to the backend
        session.
        *   **Location:** Keychain (Service: `com.firebase.app_check.app_attest_artifact_storage`).
*   **Resiliency:**
    *   **Automatic Retry (Internal):** The provider includes an internal
        retry loop (max 1 attempt) with a 0-second delay. This loop is
        specifically triggered if an error wrapped as
        `GACAppAttestRejectionError` occurs.
        *   **Triggers for Reset & Internal Retry:**
            *   `DCErrorInvalidKey` / `DCErrorInvalidInput` (Apple DeviceCheck error).
            *   HTTP 403 (Attestation Rejected) from the backend during handshake.
        *   **Transient Error Handling (No Reset):** If `DCErrorServerUnavailable`
            (indicating a temporary issue reaching Apple's App Attest service) occurs,
            the request fails, but the App Attest key and artifact are **preserved**.
            This allows the app to retry the request later using the same key,
            aligning with Apple's recommendation to preserve the device's risk metric.
    *   **Backoff Strategy (External):** An outer `GACAppCheckBackoffWrapper`
        protects the backend from traffic spikes by enforcing delays on subsequent
        attempts based on the error type.
        *   **No Backoff (Immediately Permitted):** For non-HTTP errors (e.g.,
            Apple's `DCError` like `serverUnavailable`), network connectivity issues,
            storage failures, or parsing errors, the backoff wrapper **does not** enforce
            a delay. Subsequent `getToken` calls by the app are immediately permitted.
        *   **Exponential Backoff:** Applied to retryable server errors.
            *   HTTP 403 (Project/App Deleted) *if internal retry fails*.
            *   HTTP 429 (Too Many Requests).
            *   HTTP 503 (Server Overloaded).
            *   Other HTTP 5xx (Server Errors) or 4xx not listed above or handled by 1 day backoff.
        *   **1 Day Backoff:** Applied to configuration errors unlikely to resolve quickly.
            *   HTTP 400 (Bad Request).
            *   HTTP 404 (Not Found).

## Decision Logic & State Machine
Before executing a handshake, the provider determines the correct flow
based on the internal state and manages concurrent requests.

**Note on Limited Use:** Limited-use tokens are never reused/coalesced.
If a limited-use token is requested (or if one is currently being
fetched), the new request will "chain" (wait for the ongoing one to
finish) and then start a fresh handshake to ensure a unique token is
generated.

```mermaid
%%{init: {"flowchart": {"diagramPadding": 130}}}%%
flowchart LR
    Start[getToken] --> CheckUse{Limited Use?}
    
    CheckUse -- Yes --> Queue1[Queue New Request]
    CheckUse -- No --> Coalesce{Ongoing Op?}
    
    Coalesce -- No --> StartNew[Start New Request]
    Coalesce -- Yes --> CheckOngoing{Ongoing Limited?}
    
    CheckOngoing -- Yes --> Queue2[Queue New Request]
    CheckOngoing -- No --> Reuse[Reuse Existing Request]
    
    subgraph Execution ["Backoff Wrapped Execution"]
        direction LR
        Backoff[Check Backoff]
        StateCheck{Attestation State?}
        
        Backoff --> StateCheck
        
        StateCheck -->|Yes| KeyCheck{Key ID?}
        
        KeyCheck -- No --> Flow1[Flow 1: Initial]
        KeyCheck -- Yes --> ArtifactCheck{Artifact?}
        
        ArtifactCheck -- No --> Flow1
        ArtifactCheck -- Yes --> Flow2[Flow 2: Refresh]

        StateCheck -->|No| Error[Error]
    end

    Queue1 --> Backoff
    Queue2 --> Backoff
    StartNew --> Backoff

    Reuse -.- Footnote["Note: The 'ongoingGetTokenOperation' tracks the active fetch.<br/>Standard requests reuse it (unless the active fetch is Limited-use).<br/>Limited-use requests always queue a new, sequential fetch."]
    Queue1 -.- Footnote
    Queue2 -.- Footnote
    StartNew -.- Footnote
```

## Concurrent Request Handling
The `GACAppAttestProvider` carefully manages concurrent calls to
`getToken(limitedUse:)` to ensure correctness and efficiency:

*   **No Ongoing Operation:** If no token fetching operation is in
    progress, a new one is started, and its promise is stored as the
    `ongoingGetTokenOperation`.
*   **Reuse (Standard Tokens Only):** If a standard (non-limited use)
    token is requested, and there's an `ongoingGetTokenOperation` that
    is also for a standard token, the existing promise is reused. This
    ensures only one actual token fetch occurs for multiple concurrent
    standard requests.
*   **Chaining (Limited-Use or Mismatched Requests):**
    *   If a limited-use token is requested, *or*
    *   If a standard token is requested but the `ongoingGetTokenOperation`
        is for a limited-use token (or vice versa),
    the new request will **chain**. This means it waits for the currently
    `ongoingGetTokenOperation` to complete, and then initiates a *new*, separate
    token fetching sequence. This prevents limited-use tokens from being
    accidentally reused and ensures distinct token types are handled
    independently.

```mermaid
sequenceDiagram
    participant AppA as App (Standard)
    participant AppB as App (Limited)
    participant AppC as App (Standard)
    participant Provider as GACAppAttestProvider
    
    AppA->>Provider: getToken(false)
    activate Provider
    Note right of Provider: No ongoing op.<br/>Start new op (standard).<br/>Set ongoingGetTokenOperation.
    Provider-->>Provider: Start Flow 1/2 sequence
    
    AppB->>Provider: getToken(true)
    activate Provider
    Note right of Provider: Ongoing op (standard) exists.<br/>New request is limited-use.<br/>Chain: Wait for ongoing, then start new op.
    Provider->>Provider: Await ongoing op completion
    deactivate Provider

    AppC->>Provider: getToken(false)
    activate Provider
    Note right of Provider: Ongoing op (standard) exists.<br/>New request is standard.<br/>Reuse ongoing op's promise.
    Provider-->>AppC: App Check Token (from ongoing op)
    deactivate Provider

    Provider-->>AppA: App Check Token (from completed op)
    deactivate Provider

    Provider-->>Provider: Start new Flow 1/2 for AppB
    activate Provider
    Provider-->>AppB: App Check Token (from new op)
    deactivate Provider
```

## Flow 1: Initial Handshake (Attestation)
Occurs when the app runs for the first time, or if the stored artifact
is missing, or **after a reset**.

```mermaid
sequenceDiagram
    participant App
    participant Provider as GACAppAttestProvider
    participant Apple as DCAppAttestService<br/><br/>(Apple's DeviceCheck Framework)
    participant AppleServer as Apple Server
    participant API as GACAppAttestAPIService
    participant Backend as Firebase Backend

    App->>Provider: getToken(limitedUse)
    
    loop Retry Loop (Max 1 Retry)
        par Parallel Execution
            Provider->>API: getRandomChallenge()
            API->>Backend: POST /generateAppAttestChallenge
            Backend-->>API: { "challenge": "..." }
            API-->>Provider: Challenge
        and
            Provider->>Apple: generateKey() (If needed)
            Apple-->>Provider: Key ID
        end

        Provider->>Apple: attestKey(keyId, clientDataHash=SHA256(challenge))
        Apple->>AppleServer: Contact App Attest Service
        AppleServer-->>Apple: Attestation Result
        
        alt Attestation Failed (Invalid Key/Input)
            Apple-->>Provider: DCErrorInvalidKey / Input
            Provider->>Provider: RESET: Delete KeyID & Artifact
            Note right of Provider: Throws RejectionError,<br/>Triggering Loop Retry
        else Attestation Success
            Apple-->>Provider: Attestation Object
            Provider->>API: attestKeyWithAttestation(..., limitedUse)
            API->>Backend: POST /exchangeAppAttestAttestation<br/>{ limited_use: true/false }
            
            alt Backend Rejection (403)
                Backend-->>API: 403 Forbidden
                Provider->>Provider: RESET: Delete KeyID & Artifact
                Note right of Provider: Throws RejectionError,<br/>Triggering Loop Retry
            else Success
                Backend-->>API: { "token": "...", "artifact": "..." }
                Provider-->>Provider: Store Artifact & Key ID
                Provider-->>App: App Check Token
            end
        end
    end
```

## Flow 2: Token Refresh (Assertion)
Occurs for subsequent requests using the established key pair.

```mermaid
sequenceDiagram
    participant App
    participant Provider as GACAppAttestProvider
    participant Apple as DCAppAttestService<br/><br/>(Apple's DeviceCheck Framework)
    participant API as GACAppAttestAPIService
    participant Backend as Firebase Backend

    App->>Provider: getToken(limitedUse)
    
    loop Retry Loop (Max 1 Retry)
        Provider->>API: getRandomChallenge()
        API->>Backend: POST /generateAppAttestChallenge
        Backend-->>API: { "challenge": "..." }

        Provider->>Provider: Retrieve stored Artifact
        Provider->>Provider: ClientData = Artifact + Challenge
        Provider->>Apple: generateAssertion(keyId, clientDataHash=SHA256(ClientData))
        
        alt Assertion Failed (Invalid Key/Input)
            Apple-->>Provider: DCErrorInvalidKey / Input
            Provider->>Provider: RESET: Delete KeyID & Artifact
            Note right of Provider: Throws RejectionError,<br/>Triggering Loop Retry<br/>(Will fall back to Initial Handshake)
        else Assertion Success
            Apple-->>Provider: Assertion Object
            
            Provider->>API: getAppCheckTokenWithArtifact(..., limitedUse)
            API->>Backend: POST /exchangeAppAttestAssertion<br/>{ limited_use: true/false }
            Backend-->>API: { "token": "..." }
            
            Provider-->>App: App Check Token
        end
    end
```
