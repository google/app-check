# Debug Provider (`GACAppCheckDebugProvider`)

Used for local development and CI.

## Configuration
The provider looks for a debug secret in the following order:
1.  **Environment Variable:** `AppCheckDebugToken` (or legacy
    `FIRAAppCheckDebugToken`).
2.  **Local Storage:** `NSUserDefaults` key `GACAppCheckDebugToken`.
3.  **Generation:** If neither exists, it generates a new UUID, stores it
    in `NSUserDefaults`, and logs it to the console (warning level).

## Flow
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
