# Quickstart

ArtazzenMobile is a SwiftUI iOS 17+ Swift Package and requires macOS with Xcode. The package is not expected to build on Linux.

## Requirements

- Xcode with an iOS 17+ SDK and an available iOS Simulator
- Homebrew (for SwiftLint and swift-format)

## Run locally

```sh
git clone https://github.com/adamtasteslikegood/ArtazzenMobile.git
cd ArtazzenMobile
# Match the versions CI uses (see .github/workflows/ci.yml). Plain `brew
# install swiftlint swift-format` can drift into new default-on SwiftLint
# rules that fail the strict gate; verify with `swiftlint version`.
brew install swiftlint swift-format
open Package.swift
```

The root package provides the `ArtazzenCore` library for XCTest and the `ArtazzenMobile` executable for compile checks. For a runnable app, open `Artazzen.swiftpm` in Xcode or Swift Playgrounds. In Settings, enter `https://artazzen.com` and your admin username/password (HTTP Basic), then tap **Connect and Load**. Passwords are stored in Keychain per server/account; old prototype passwords migrate out of UserDefaults only after a successful Keychain save. Never commit credentials.

## iPad Swift Playgrounds

`Artazzen.swiftpm` is an App Playground you can AirDrop or copy into Files, then open in Swift Playgrounds.

1. Open the successful **CI** run for the PR or `main` in GitHub Actions and download the **Artazzen-iPad-…** artifact (GitHub sign-in required; retention is 30 days).
2. Extract the artifact wrapper ZIP, then extract its `Artazzen-<commit>.zip`. The result is a complete `Artazzen.swiftpm` folder. AirDrop / iCloud Drive it onto the iPad.
3. Open that document in Swift Playgrounds and tap Run. No files outside the document are needed.
4. Settings → Artazzen Server → URL `https://artazzen.com`, admin username and password → Connect and Load.

After changing `Sources/`, refresh the playground copy:

```sh
./scripts/export-playground.sh
./scripts/export-playground.sh --check
./scripts/package-playground.sh
```

CI checks source synchronization, runs core XCTest on an iOS Simulator, builds the root executable, and separately builds the playground before uploading its ZIP. CodeQL runs independently. A green build does not prove iPad Playgrounds launch or on-device Keychain persistence.

Prototype acceptance on iPad: connect and reload the deck; relaunch and confirm credentials persist; approve one test artwork; choose a photo and tap Upload; preview a metadata field without losing other edits; Save & Approve. Verify a failed upload/approval remains retryable. Connection edits apply only through Connect and Load. Hide is local to the current session; it is not a backend operation. The picker preserves supported image formats and converts unsupported formats such as HEIC to JPEG.

## Verify a change

```sh
swiftlint lint --strict --config .swiftlint.yml
swift-format lint --recursive --strict --configuration .swift-format Sources Tests
xcodebuild -scheme ArtazzenCore -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' test
xcodebuild -scheme ArtazzenMobile -destination 'generic/platform=iOS' build
(cd Artazzen.swiftpm && xcodebuild -scheme Artazzen -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build)
```

If the simulator name differs on your machine, replace it with one shown by `xcrun simctl list devices`.
