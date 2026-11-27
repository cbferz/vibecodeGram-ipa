# TestFlight setup

The repository contains a manual TestFlight release workflow at `.github/workflows/release-ios.yml`. It is intentionally not run automatically on every commit.

Before using it, configure these GitHub Actions repository secrets:

- `APPLE_TEAM_ID` — the Team ID from the owner's Apple Developer account.
- `APP_STORE_CONNECT_KEY_ID` — App Store Connect API key ID.
- `APP_STORE_CONNECT_ISSUER_ID` — App Store Connect issuer ID.
- `APP_STORE_CONNECT_PRIVATE_KEY` — full contents of the API key `.p8` file.

The App Store Connect API key must have sufficient permissions for signing/provisioning and TestFlight upload. The app's bundle identifier is currently `com.vibecodegram.ios`; register that identifier with Apple and confirm it is available to the team before the first release.

No signing assets or credentials are stored in this repository. The workflow must be run by the repository owner after secrets and Apple account configuration are in place. An upload workflow being present does not mean an IPA has already been built or uploaded.
