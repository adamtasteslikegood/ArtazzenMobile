# Quickstart

ArtazzenMobile is a SwiftUI iOS 17+ Swift Package and requires macOS with Xcode. The package is not expected to build on Linux.

## Requirements

- Xcode with an iOS 17+ SDK and an available iOS Simulator
- Homebrew (for SwiftLint and swift-format)

## Run locally

```sh
git clone https://github.com/adamtasteslikegood/ArtazzenMobile.git
cd ArtazzenMobile
brew install swiftlint swift-format
open Package.swift
```

Select the `ArtazzenMobile` scheme and an iOS 17+ Simulator in Xcode, then run the app. Configure any backend credentials through the app's settings; never commit credentials.

## Verify a change

```sh
swiftlint lint --strict --config .swiftlint.yml
swift-format lint --recursive --strict --configuration .swift-format Sources Tests
xcodebuild -scheme ArtazzenMobile-Package -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' test
xcodebuild -scheme ArtazzenMobile-Package -destination 'generic/platform=iOS' build
```

If the simulator name differs on your machine, replace it with one shown by `xcrun simctl list devices`.
