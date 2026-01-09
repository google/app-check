# App Check Providers: Deep Dive

This document details the internal design and detailed flows of each
App Check provider, including error handling, retries, and state
resets.

## AppAttest Provider (`GACAppAttestProvider`)
The most complex provider, interacting with `DCAppAttestService`. It
maintains a stable key pair on the device to sign assertions.

### Components
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

### Decision Logic & State Machine
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

### Flow 1: Initial Handshake (Attestation)
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

### Flow 2: Token Refresh (Assertion)
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

---

## DeviceCheck Provider (`GACDeviceCheckProvider`)
A simpler provider for older devices.

### Components
*   **Service:** `DCDevice` (Apple's API).
*   **Generator:** `DCDevice.currentDevice`.

### Flow
```mermaid
sequenceDiagram
    participant App
    participant Provider as GACDeviceCheckProvider
    participant Apple as DCDevice<br/><br/>(Apple's DeviceCheck Framework)
    participant API as GACDeviceCheckAPIService
    participant Backend as Firebase Backend

    App->>Provider: getToken(limitedUse)
    
    Note right of Provider: Wrapped in Backoff Wrapper
    Provider->>Apple: generateToken()
    Apple-->>Provider: Device Token (Ephemeral)

    Provider->>API: appCheckTokenWithDeviceToken(deviceToken, limitedUse)
    API->>Backend: POST /exchangeDeviceCheckToken<br/>{ limited_use: true/false }
    Note right of Backend: Verifies device token with Apple.
    
    alt Error (e.g., 503)
        Backend-->>API: 503 Service Unavailable
        Provider->>Provider: Record Failure (Backoff)
        Provider-->>App: Error
    else Success
        Backend-->>API: { "token": "..." }
        Provider-->>App: App Check Token
    end
```

---

## Debug Provider (`GACAppCheckDebugProvider`)
Used for local development and CI.

### Configuration
The provider looks for a debug secret in the following order:
1.  **Environment Variable:** `AppCheckDebugToken` (or legacy
    `FIRAAppCheckDebugToken`).
2.  **Local Storage:** `NSUserDefaults` key `GACAppCheckDebugToken`.
3.  **Generation:** If neither exists, it generates a new UUID, stores it
    in `NSUserDefaults`, and logs it to the console (warning level).

### Flow
```mermaid
sequenceDiagram
    participant App
    participant Provider as GACAppCheckDebugProvider
    participant API as GACAppCheckDebugProviderAPIService
    participant Backend as Firebase Backend

    App->>Provider: getToken(limitedUse)
    Provider->>Provider: Determine Debug Secret (Env Var or UUID)
    
    Provider->>API: appCheckTokenWithDebugToken(debugToken, limitedUse)
    API->>Backend: POST /exchangeDebugToken<br/>{ limited_use: true/false }
    Note right of Backend: Checks if debug token is <br/>registered in Console.
    Backend-->>API: { "token": "..." }
    
    Provider-->>App: App Check Token
```
