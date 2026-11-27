# Implementation status

Last audited: 2026-11-27.

## Phase 1 — source audit

- [x] Confirm source repository and default branch.
- [x] Confirm new iOS repository and `main` branch.
- [x] Inspect Android project structure and primary UI/API source files.
- [x] Inspect Go route registration, data models and SQL migrations.
- [x] Record verified API paths and known capability gaps.
- [ ] Complete a screen-by-screen Android behavior audit.
- [ ] Complete request/response fixture coverage for every endpoint.

## Phase 2 — iOS foundation

- [ ] XcodeGen project and app target.
- [ ] Swift 6 / iOS 17+ build.
- [ ] Keychain-backed session storage.
- [ ] Typed URLSession client and centralized API errors.
- [ ] Dependency injection and app navigation.
- [ ] Liquid Glass design tokens and reusable surfaces.

## Phase 3 — product features

- [ ] Authentication and session management.
- [ ] Feed, post creation, likes, saves and comments.
- [ ] Profile, edit profile, followers and following.
- [ ] Stories, story viewer and expiration selection.
- [ ] Vibees / video feed and AVPlayer lifecycle.
- [ ] Search, recommendations and notifications.
- [ ] Messaging and WebSocket connection lifecycle.
- [ ] Moderation, blocked users and reports.
- [ ] Device accounts, badges and AI tools where exposed in Android UI.

## Phase 4 — quality and distribution

- [ ] Unit tests for API decoding, auth and feature state.
- [ ] UI tests for critical user journeys.
- [ ] macOS/Xcode simulator build.
- [ ] GitHub Actions build and test workflow.
- [ ] Signing-free CI artifact and TestFlight release workflow.
- [ ] Physical-device validation and TestFlight verification.

## Current limitations / facts

1. The current backend exposes text posts and MP4 video posts/reels. No image-post upload route was found in the audited Go route registration.
2. Stories accept a multipart `media` upload and support server-validated expiration durations of 5, 12, 24 or 48 hours.
3. The WebSocket handler authenticates and sends a `connected` frame, then reads frames; it does not currently broadcast feed/chat events. Do not represent it as a working push/realtime event bus.
4. The repository does not contain Apple signing credentials. IPA signing and TestFlight delivery cannot be completed without the owner's Apple Developer configuration.
5. This audit did not run Xcode: the current execution environment does not provide macOS/Xcode.
