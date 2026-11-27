# vibecodeGram for iOS

Native iOS client for [cbferz/vibecodeGram](https://github.com/cbferz/vibecodeGram).

- Product: **vibecodeGram**
- Platform: iOS 17+
- Language/UI: Swift 6 + SwiftUI
- Architecture: MVVM with Domain, Data, Networking and Design System boundaries
- Backend: existing Go + PostgreSQL service; no second backend

## Project status

This repository is the independent iOS implementation. The initial repository baseline records the source audit and verified API constraints. It is **not yet a feature-complete release**. See [the implementation status](docs/IMPLEMENTATION_STATUS.md) and [the API compatibility audit](docs/API_COMPATIBILITY.md).

## Source of truth

The Android client and Go backend in `cbferz/vibecodeGram` are read-only references during iOS development. Do not copy Android implementation code or change production data/schema to accommodate an unverified client assumption.

The Android client's configured API origin is:

`https://api.vibecodegram.tendercheck.pro`

The app should use this origin by default and allow build-time configuration for development/staging. All authenticated requests use `Authorization: Bearer <JWT>`; tokens belong in the iOS Keychain.

## Open in Xcode

The Xcode project configuration will be generated from `project.yml` using XcodeGen. On macOS:

```sh
brew install xcodegen
xcodegen generate
open vibecodeGram.xcodeproj
```

Select an iPhone simulator or a properly provisioned physical device and build the `vibecodeGram` scheme. Signing credentials are intentionally not committed.

## Build and test

The GitHub Actions workflow uses a macOS runner and Xcode. A successful simulator build does not produce a signed, installable IPA. TestFlight distribution requires the account owner's Apple Developer membership, signing assets and App Store Connect configuration.

## Security

- Never commit API tokens, JWTs, passwords, signing certificates, provisioning profiles or private keys.
- Never put backend-only secrets (JWT signing secret, Hugging Face token, subscription webhook secret) in the iOS app.
- Do not reset, migrate destructively, or otherwise modify the production PostgreSQL database as part of iOS work.
- Treat HTTP 401 as an expired/revoked session and return the user to authentication after clearing the local token.
