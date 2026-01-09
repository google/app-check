# DeviceCheck Provider (`GACDeviceCheckProvider`)

A simpler provider for older devices.

## Components
*   **Service:** `DCDevice` (Apple's API).
*   **Generator:** `DCDevice.currentDevice`.

## Flow
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
