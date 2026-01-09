# AppAttest Provider (`GACAppAttestProvider`)

The most complex provider, interacting with `DCAppAttestService`. It
maintains a stable key pair on the device to sign assertions.

## Components
*   **Service:** `DCAppAttestService` (Apple's API).
*   **Storage:**
    *   `GACAppAttestKeyIDStorage`: Stores the generated App Attest Key
        ID.
    *   `GACAppAttestArtifactStorage`: Stores the "artifact" returned by
        the Firebase backend after a successful initial handshake. This
        artifact effectively links the on-device key to the backend
        session.
*   **Resiliency:**
    *   **Automatic Retry:** The provider wraps the entire flow in a
        retry loop. If a specific "Rejection Error" occurs (e.g.,
        invalid key), it resets its internal state and retries the flow
        from scratch.

## Decision Logic & State Machine
Before executing a handshake, the provider determines the correct flow
based on the internal state and manages concurrent requests.

**Note on Limited Use:** Limited-use tokens are never reused/coalesced.
If a limited-use token is requested (or if one is currently being
fetched), the new request will "chain" (wait for the ongoing one to
finish) and then start a fresh handshake to ensure a unique token is
generated.

```mermaid
flowchart TD
    Start[getToken call] --> CheckUse{Limited Use Request?}
    
    CheckUse -- Yes --> Chain[Chain Promise]
    CheckUse -- No --> Coalesce{Ongoing Operation?}
    
    Coalesce -- No --> Backoff[Apply Backoff]
    Coalesce -- Yes --> CheckOngoing{Ongoing is Limited?}
    
    CheckOngoing -- Yes --> Chain
    CheckOngoing -- No --> Reuse[Reuse Ongoing Promise]
    
    Chain --> Backoff
    
    Backoff --> StateCheck{Attestation State?}
    
    StateCheck -->|Not Supported| Error[Return Error]
    
    StateCheck -->|Supported| KeyCheck{Key ID Stored?}
    
    KeyCheck -- No --> Flow1[Flow 1: Initial Handshake]
    KeyCheck -- Yes --> ArtifactCheck{Artifact Stored?}
    
    ArtifactCheck -- No --> Flow1
    ArtifactCheck -- Yes --> Flow2[Flow 2: Token Refresh/Assertion]
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
                Provider->>Provider: Store Artifact & Key ID
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
