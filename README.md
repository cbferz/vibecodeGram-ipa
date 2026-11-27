# vibecodeGram — native iOS client

Native SwiftUI client for the existing vibecodeGram Go/PostgreSQL backend. This repository is independent of the Android project.

## Requirements

- macOS with Xcode 16.4 or newer
- Swift 6 toolchain
- iOS 17 deployment target
- XcodeGen

## Generate and open the Xcode project

```bash
brew install xcodegen
git clone https://github.com/cbferz/vibecodeGram-ipa.git
cd vibecodeGram-ipa
xcodegen generate
open vibecodeGram.xcodeproj
```

Select the `vibecodeGram` scheme and an iPhone simulator, then build and run.

## Command-line build and tests

```bash
xcodegen generate
xcodebuild \
  -project vibecodeGram.xcodeproj \
  -scheme vibecodeGram \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild \
  -project vibecodeGram.xcodeproj \
  -scheme vibecodeGram \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO test
```

GitHub Actions runs simulator build, XCTest and XCUITest on macOS.

## Backend configuration

The default API base URL is configured in `project.yml` as `INFOPLIST_KEY_API_BASE_URL`. Change it for a local/staging environment before generating the Xcode project. Do not put credentials or private tokens in this setting.

The client uses the existing backend; it does not create or migrate the production database. Access tokens are stored in Keychain.

## Current implementation

Implemented vertical slices include:

- Authentication, Keychain session restoration and logout
- Feed, text and MP4 video posts, sorting and recommendations
- Likes, saves, comments, hiding posts, reports and blocking
- Stories with image/MP4 upload and the server's 5/12/24/48-hour expiration choices
- Profile editing, follower/following lists and posts/videos/vibees tabs
- Vibees vertical video feed and MP4 publishing
- Search, notifications and REST-based direct/group conversations
- Session management, blocked-user list, reports, badges and AI tools
- Light/dark appearance preference

See [FEATURE_MAP.md](docs/FEATURE_MAP.md) and [IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md) for the Android parity map and verified gaps.

## Known backend constraints

- Photo posts are not supported by the audited backend: there is no post-image upload route or image media table. Story image upload is supported.
- Profile avatar and cover fields accept URLs; the backend does not provide image upload for those fields.
- The WebSocket endpoint currently authenticates and sends a connection acknowledgement, but does not broadcast chat/feed events. Chat screens therefore use REST refresh; real-time delivery requires a backend feature.
- TestFlight upload requires the repository owner's Apple Developer account and App Store Connect API key. No signing credentials are committed.

## TestFlight

Configure the GitHub Actions secrets listed in [TESTFLIGHT.md](docs/TESTFLIGHT.md), register the bundle identifier `com.vibecodegram.ios` with the Apple Developer team, then manually run **iOS TestFlight Release** from Actions.

A configured workflow is not proof of a completed archive or TestFlight upload. Check the workflow run and App Store Connect processing status.
