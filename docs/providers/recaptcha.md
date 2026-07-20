# reCAPTCHA Provider (`AppCheckRecaptchaProvider` / `GACRecaptchaProvider`)

A provider that verifies app integrity using the reCAPTCHA Enterprise API.

## Components
*   **Token Generator:** `RecaptchaTokenGenerator` (Wraps the `RCARecaptchaClientProtocol` to fetch reCAPTCHA tokens).
*   **Service:** `RecaptchaAPIService` (Exchanges the reCAPTCHA token for an App Check token).

## Flow
```mermaid
sequenceDiagram
    participant App
    participant Provider as AppCheckRecaptchaProvider
    participant Generator as RecaptchaTokenGenerator
    participant ReCAPTCHA as reCAPTCHA Enterprise SDK
    participant API as RecaptchaAPIService
    participant Backend as Firebase Backend

    App->>Provider: getToken(limitedUse)
    
    Provider->>Generator: getRecaptchaToken()
    Note right of Generator: Wrapped in Backoff Wrapper
    Generator->>ReCAPTCHA: execute(withAction: "app_check_ios")
    ReCAPTCHA-->>Generator: reCAPTCHA Token
    Generator-->>Provider: reCAPTCHA Token
    
    Provider->>API: appCheckToken(with: recaptchaToken, limitedUse)
    API->>Backend: POST /exchangeRecaptchaEnterpriseToken<br/>{ limited_use: true/false }
    Note right of Backend: Verifies token with reCAPTCHA Enterprise.

    alt Error (e.g., 503)
        Backend-->>API: 503 Service Unavailable
        API-->>Provider: Error
        Provider-->>App: Error
    else Success
        Backend-->>API: { "token": "..." }
        API-->>Provider: App Check Token
        Provider-->>App: App Check Token
    end
```
