# TODOs

- [ ] Add `serviceName` to `AppCheckCoreRecaptchaEnterpriseProvider.init` for
  consistency with other providers.
- [ ] Implement exponential backoff in `RecaptchaEnterpriseProvider` for
  transient errors (need to reach out to people first).
- [ ] Bring up API proposal for coordinating assertion behavior when optional
  SDKs (like reCAPTCHA) are missing across platforms.

## Error Handling for Missing reCAPTCHA SDK in Production

When the reCAPTCHA SDK is not linked in a release build, we currently return a
generic "unsupported" error. We discussed three options for improving this:

### Option 1: Follow Precedent (Keep as is)
- **Code**: `GACAppCheckErrorCodeUnsupported` (4)
- **Message**: "The attestation provider RecaptchaEnterprise is not supported on
  current platform and OS version."
- **Pros**: Consistent with other providers (DeviceCheck, AppAttest) when they
  are not supported.
- **Cons**: The message implies a platform/OS limitation, not a missing
  dependency.

### Option 2: Prioritize Message Accuracy
- **Code**: `GACAppCheckErrorCodeUnknown` (0)
- **Message**: "The reCAPTCHA Enterprise SDK is not linked. See
  https://cloud.google.com/recaptcha/docs/instrument-ios-apps#prepare-environment"
- **Pros**: Provides the exact, clear message in logs.
- **Cons**: Uses a generic error code (`Unknown`) instead of `Unsupported`.

### Option 3: Enhance the Utility (Recommended for long term)
- **Code**: `GACAppCheckErrorCodeUnsupported` (4)
- **Message**: Specific message as in Option 2.
- **Pros**: Best error code + best message.
- **Cons**: Requires adding a new method to `GACAppCheckErrorUtil` (internal
  change).
