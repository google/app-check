# App Check Providers: Deep Dive

This document details the internal design and detailed flows of each App Check provider.

## AppAttest Provider (`GACAppAttestProvider`)
The most complex provider, interacting with `DCAppAttestService`. It maintains a stable key pair on the device to sign assertions.

### Components
*   **Service:** `DCAppAttestService` (Apple's API).
*   **Storage:**
    *   `GACAppAttestKeyIDStorage`: Stores the generated App Attest Key ID.
    *   `GACAppAttestArtifactStorage`: Stores the "artifact" returned by the Firebase backend after a successful initial handshake. This artifact effectively links the on-device key to the backend session.

### Flow 1: Initial Handshake (Attestation)
Occurs when the app runs for the first time or if the stored artifact is missing/corrupted.

```mermaid
sequenceDiagram
    participant App
    participant Provider as GACAppAttestProvider
    participant Apple as DCAppAttestService
    participant API as GACAppAttestAPIService
    participant Backend as Firebase Backend

    App->>Provider: getToken()
    Provider->>API: getRandomChallenge()
    API->>Backend: POST /generateAppAttestChallenge
    Backend-->>API: { "challenge": "..." }
    
    par Parallel Execution
        Provider->>Apple: generateKey()
        Apple-->>Provider: Key ID
    and
        Provider->>API: (Challenge received)
    end

    Provider->>Apple: attestKey(keyId, clientDataHash=SHA256(challenge))
    Apple-->>Provider: Attestation Object

    Provider->>API: attestKeyWithAttestation(attestation, keyID, challenge)
    API->>Backend: POST /exchangeAppAttestAttestation
    Note right of Backend: Verifies attestation validity <br/>and app integrity.
    Backend-->>API: { "token": "...", "artifact": "..." }
    
    Provider->>Provider: Store Artifact & Key ID
    Provider-->>App: App Check Token
```

### Flow 2: Token Refresh (Assertion)
Occurs for subsequent requests. It's faster and uses the established key pair.

```mermaid
sequenceDiagram
    participant App
    participant Provider as GACAppAttestProvider
    participant Apple as DCAppAttestService
    participant API as GACAppAttestAPIService
    participant Backend as Firebase Backend

    App->>Provider: getToken()
    Provider->>API: getRandomChallenge()
    API->>Backend: POST /generateAppAttestChallenge
    Backend-->>API: { "challenge": "..." }

    Provider->>Provider: Retrieve stored Artifact
    Provider->>Provider: ClientData = Artifact + Challenge
    Provider->>Apple: generateAssertion(keyId, clientDataHash=SHA256(ClientData))
    Apple-->>Provider: Assertion Object

    Provider->>API: getAppCheckTokenWithArtifact(artifact, challenge, assertion)
    API->>Backend: POST /exchangeAppAttestAssertion
    Note right of Backend: Verifies assertion signature <br/>matches stored public key.
    Backend-->>API: { "token": "..." }
    
    Provider-->>App: App Check Token
```

---

## DeviceCheck Provider (`GACDeviceCheckProvider`)
A simpler provider for older devices.

### Components
*   **Service:** `DCDevice` (Apple's API).
*   **Generator:** `DCDevice.currentDevice` (can be mocked for testing).

### Flow
```mermaid
sequenceDiagram
    participant App
    participant Provider as GACDeviceCheckProvider
    participant Apple as DCDevice
    participant API as GACDeviceCheckAPIService
    participant Backend as Firebase Backend

    App->>Provider: getToken()
    Provider->>Apple: generateToken()
    Apple-->>Provider: Device Token (Ephemeral)

    Provider->>API: appCheckTokenWithDeviceToken(deviceToken)
    API->>Backend: POST /exchangeDeviceCheckToken
    Note right of Backend: Verifies device token with Apple.
    Backend-->>API: { "token": "..." }
    
    Provider-->>App: App Check Token
```

---

## Debug Provider (`GACAppCheckDebugProvider`)
Used for local development and CI.

### Configuration
The provider looks for a debug secret in the following order:
1.  **Environment Variable:** `AppCheckDebugToken` (or legacy `FIRAAppCheckDebugToken`).
2.  **Local Storage:** `NSUserDefaults` key `GACAppCheckDebugToken`.
3.  **Generation:** If neither exists, it generates a new UUID, stores it in `NSUserDefaults`, and logs it to the console (warning level).

### Flow
```mermaid
sequenceDiagram
    participant App
    participant Provider as GACAppCheckDebugProvider
    participant API as GACAppCheckDebugProviderAPIService
    participant Backend as Firebase Backend

    App->>Provider: getToken()
    Provider->>Provider: Determine Debug Secret (Env Var or UUID)
    
    Provider->>API: appCheckTokenWithDebugToken(debugToken)
    API->>Backend: POST /exchangeDebugToken
    Note right of Backend: Checks if debug token is <br/>registered in Console.
    Backend-->>API: { "token": "..." }
    
    Provider-->>App: App Check Token
```