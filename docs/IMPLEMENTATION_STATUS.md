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

## Phase 2 — iOS foundation and feature vertical slices

- [x] Swift 6 / SwiftUI / iOS 17+ XcodeGen project.
- [x] MVVM feature boundaries, URLSession API client and centralized errors.
- [x] Keychain token storage, registration/login, restore, logout and retry.
- [x] Liquid Glass surface with iOS 26 native effect and iOS 17–25 material fallback.
- [x] Feed, server-backed sorting/recommendations, text and MP4 posts, playback, likes and saves.
- [x] Comments, post hiding, reporting and blocking.
- [x] Stories list/view, image and MP4 upload, deletion and 5/12/24/48-hour expiry.
- [x] Profile, profile editing, follow/unfollow, follower/following lists and posts/videos/vibees tabs.
- [x] Vibees vertical feed, pagination, authenticated MP4 playback, likes/saves and publishing.
- [x] Search users/posts, notifications and mark-read.
- [x] REST direct/group conversations and message send/history.
- [x] Settings for sessions, blocked users, reports, badges and light/dark appearance.
- [x] AI model catalogue, chat and backend text tools.
- [x] Asset catalog/resource directories created; branded app icon still outstanding.

## Phase 3 — parity gaps and platform integration

- [ ] Device account manager / account switching.
- [ ] Full appearance parity: palettes, accent selection, glass intensity, compact mode and profile color controls.
- [ ] Push notifications and real-time chat delivery.
- [ ] Chat attachment/media features if present in Android UI.
- [ ] More complete profile navigation from follower lists and all social entry points.
- [ ] Feed pagination if backend support is added.
- [ ] Photo posts and profile avatar/cover uploads (backend currently has no corresponding upload endpoints).
- [ ] Full accessibility, localization and dynamic type audit.

## Phase 4 — quality and distribution

- [x] XCTest API contract tests.
- [x] XCUITest target and authentication screen smoke test.
- [x] macOS/Xcode simulator build workflow.
- [x] Manual TestFlight release workflow configuration.
- [ ] Green build and tests for the latest repository HEAD.
- [ ] UI test execution on the latest HEAD.
- [ ] Physical-device validation.
- [ ] Signed archive and TestFlight processing with owner-provided Apple credentials.

## Current verified constraints

1. The audited backend supports text and MP4 video posts/reels. It has no post-image upload route or image media table.
2. Story uploads support JPEG, PNG, WebP and MP4, up to 15 MiB, with 5, 12, 24 or 48-hour expiration.
3. Profile avatar/cover fields accept URLs; no avatar/cover upload endpoint was found.
4. The WebSocket endpoint authenticates and sends a `connected` acknowledgement, but does not broadcast chat/feed events. REST messaging is implemented; real-time delivery requires backend work.
5. No production database, schema, or user data has been changed.
6. No Apple signing credentials are stored in the repository. The TestFlight workflow requires the owner's Apple Developer team and App Store Connect API key.
7. A previous revision passed simulator build and unit tests. The latest HEAD has not yet completed its own green CI run; no final IPA or TestFlight upload is claimed.
