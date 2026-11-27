# iOS architecture

## Layering

- **App** — app lifecycle, root scene, dependency graph and top-level navigation.
- **Core/Networking** — typed endpoint client, request construction, decoding, API errors and media transfer.
- **Core/Storage** — Keychain session credentials and small local preferences.
- **Core/DesignSystem** — Liquid Glass surfaces, typography, spacing, color, motion and accessibility.
- **Domain** — feature-facing models, repositories/protocols and use cases.
- **Features** — MVVM presentation and SwiftUI views grouped by product capability.
- **Tests / UITests** — deterministic API/model tests and critical user journeys.

## Rules

1. Views render state and forward user intent; they do not construct URLs or decode JSON.
2. View models own loading/error/empty states and call domain protocols.
3. Repositories own endpoint mapping and DTO conversion.
4. Networking owns auth headers, HTTP status handling, cancellation and decoding.
5. JWTs are stored only in Keychain. Never use UserDefaults for credentials.
6. AVPlayer instances are feature-scoped and released when the corresponding playback context ends.
7. Liquid Glass is a design-system primitive, not a one-off home-screen effect. Keep contrast, Dynamic Type and Reduce Motion behavior.
8. Backend contracts are authoritative. Any missing server capability is documented as a gap, not simulated locally.

## Platform

Swift 6, SwiftUI, iOS 17+, URLSession, async/await, AVFoundation/AVKit, PhotosUI and AuthenticationServices where supported by the audited product flow. SwiftData is not required for the initial client.
