# Recaptcha Provider Integration Paths

This document outlines two possible paths for integrating the new
`RecaptchaEnterpriseProvider` into the `FirebaseAppCheck` SDK within the
`firebase-ios-sdk` repository.

## Background

`AppCheckCore` is an internal dependency of `FirebaseAppCheck`. Customers do
not depend on `AppCheckCore` directly; they consume `FirebaseAppCheck`.

Currently, all other providers (`DeviceCheck`, `AppAttest`, `Debug`) are
bundled within the monolithic `AppCheckCore` product in the `app-check` repo
and the `FirebaseAppCheck` target in the `firebase-ios-sdk` repo.

---

## Path A: Consistent Path (Current Choice)

This path follows the existing pattern used by other providers.

### In `app-check` Repository

*   **Approach**: Bundle `RecaptchaEnterpriseProvider` target into the existing
    `AppCheckCore` library product.
*   **`Package.swift` Changes**:
    ```swift
    products: [
      .library(
        name: "AppCheckCore",
        targets: ["AppCheckCore", "RecaptchaEnterpriseProvider"]
      ),
    ]
    ```

### In `firebase-ios-sdk` Repository

*   **Integration**: `FirebaseAppCheck` target will automatically get the core
    reCAPTCHA glue code because it depends on `AppCheckCore`.
*   **Wrapper**: Add `FIRRecaptchaEnterpriseProvider` wrapper files directly
    into `FirebaseAppCheck/Sources`.

### Developer Experience

*   **Opt-in**: The customer just imports `FirebaseAppCheck`. The glue code is
    present but inert. To make it work, they must manually add the
    `RecaptchaEnterprise` SDK to their project.
*   **Pros**: Consistent with existing architecture; lowest friction for users
    who want reCAPTCHA (no new product dependency).
*   **Cons**: All users get the glue code, even if not used (though size is
    negligible).

---

## Path B: Modular Path

This path follows the design document's goal of allowing exclusion to save
binary size, treating the reCAPTCHA provider as a separate component.

### In `app-check` Repository

*   **Approach**: Expose `RecaptchaEnterpriseProvider` as a separate library
    product.
*   **`Package.swift` Changes**:
    ```swift
    products: [
      .library(
        name: "AppCheckCore",
        targets: ["AppCheckCore"]
      ),
      .library(
        name: "RecaptchaEnterpriseProvider",
        targets: ["RecaptchaEnterpriseProvider"]
      ),
    ]
    ```

### In `firebase-ios-sdk` Repository

*   **Integration**: Create a new, separate target (e.g.,
    `FirebaseRecaptchaEnterpriseProvider`) that depends on `FirebaseAppCheck`
    and the core `RecaptchaEnterpriseProvider` product.

### Developer Experience

*   **Opt-in**: The customer must explicitly add both `FirebaseAppCheck` and
    `FirebaseRecaptchaEnterpriseProvider` to their target, plus manually add the
    `RecaptchaEnterprise` SDK.
*   **Pros**: Strict modularity; users can fully exclude the provider and its
    interop dependency.
*   **Cons**: Higher friction for users (multiple dependencies to add).
