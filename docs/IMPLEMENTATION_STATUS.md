# Implementation status

Last audited: 2026-11-27.

## Phase 1 — source audit

- [x] Confirm source repository and default branch.
- [x] Confirm new iOS repository and `main` branch.
- [x] Inspect Android project structure and primary UI/API source files.
- [x] Inspect Go route registration, data models and SQL migrations.
- [x] Record verified API paths and known capability gaps.
- [x] Record Android screen inventory and backend support map.
- [ ] Complete fixture coverage for every endpoint and edge case.

## Phase 2 — iOS foundation and first vertical slices

- [x] Add XcodeGen project configuration for an iOS 17+ SwiftUI app.
- [x] Add Swift 6 app entry point and dependency boundary.
- [x] Add Keychain-backed access-token storage.
- [x] Add typed URLSession authentication/current-user/logout requests.
- [x] Add registration/login UI with server-aligned input validation.
- [x] Add session restoration and retry on network failure.
- [x] Add reusable Liquid Glass surface with compiler-gated iOS 26 glass effect and older-system material fallback.
- [x] Add initial feed loading, text post publishing, like and save actions.
- [x] Add story listing, image/MP4 upload, authenticated media loading, view/delete and 5/12/24/48-hour expiry selection.
- [ ] Resolve current Xcode CI compile errors and obtain a green simulator build.

## Phase 3 — remaining product features

- [ ] Full feed sorting, search, recommendations and pagination.
- [ ] Profile, profile editing, followers and following.
- [ ] Vibees/reel feed, video composer and AVPlayer lifecycle.
- [ ] Video post publishing and authenticated streaming.
- [ ] Comments and notifications.
- [ ] Messaging and WebSocket lifecycle.
- [ ] Moderation, blocked users and reports.
- [ ] Device accounts, badges and AI tools exposed by Android UI.
- [ ] Appearance settings and profile color customization.
- [ ] Photo-post support (blocked by missing backend route; requires separate approval).

## Phase 4 — quality and distribution

- [x] Add API contract unit tests.
- [x] Add macOS/Xcode CI workflow.
- [x] Add manual TestFlight release workflow configuration.
- [ ] Green simulator build and unit tests.
- [ ] UI tests for critical user journeys.
- [ ] Physical-device validation and TestFlight verification.

## Current limitations / facts

1. The current backend exposes text posts and MP4 video posts/reels. No image upload route or image media table was found in the audited backend.
2. Stories accept multipart media uploads (JPEG, PNG, WebP or MP4), maximum 15 MiB, and expiration durations of 5, 12, 24 or 48 hours.
3. The WebSocket handler authenticates and sends a `connected` frame, then reads frames; it does not currently broadcast feed/chat events.
4. The repository does not contain Apple signing credentials. TestFlight upload requires the owner's Apple Developer and App Store Connect configuration.
5. GitHub Actions successfully generates the Xcode project. Simulator compilation is being corrected from CI diagnostics; no green build is claimed yet.
