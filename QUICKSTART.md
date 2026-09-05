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

Select the `ArtazzenMobile` scheme and an iOS 17+ Simulator in Xcode, then run the app. In Settings, set the server to `https://artazzen.com` plus your admin username/password (HTTP Basic). Never commit credentials.

## iPad Swift Playgrounds

`Artazzen.swiftpm` is an App Playground you can AirDrop or copy into Files, then open in Swift Playgrounds.

1. On a Mac, zip the `Artazzen.swiftpm` folder (or copy the whole repo).
2. AirDrop / iCloud Drive it onto the iPad.
3. Open it in Swift Playgrounds and tap Run.
4. Settings → Artazzen Server → URL `https://artazzen.com`, admin username and password → Connect and Load.

After changing `Sources/`, refresh the playground copy:

```sh
./scripts/export-playground.sh
```

## Verify a change

```sh
swiftlint lint --strict --config .swiftlint.yml
swift-format lint --recursive --strict --configuration .swift-format Sources Tests
xcodebuild -scheme ArtazzenMobile -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' test
xcodebuild -scheme ArtazzenMobile -destination 'generic/platform=iOS' build
```

If the simulator name differs on your machine, replace it with one shown by `xcrun simctl list devices`.
