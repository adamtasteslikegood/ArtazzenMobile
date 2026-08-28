# Contributing to ArtazzenMobile

## Development workflow

1. Start from an up-to-date `main` branch: `git fetch origin --prune` and `git switch main && git pull --ff-only`.
2. Create a focused branch, such as `feat/gallery-filter`, `fix/network-error`, or `chore/ci`.
3. Make the smallest coherent change and add or update XCTest coverage.
4. Run the checks in [QUICKSTART.md](QUICKSTART.md), commit the change, push the branch, and open a pull request to `main` using the repository template.
5. Address review feedback and wait for all required checks before merging.

Do not commit secrets, signing certificates, provisioning profiles, derived data, or local Xcode user state.

## Pull requests

Describe the user-facing or maintenance change, include testing evidence, and call out any iOS/Xcode or backend contract assumptions. Keep unrelated formatting or dependency changes out of the PR.

## Quality gates

Pull requests to `main` run SwiftLint, `swift-format`, XCTest on an iOS Simulator, an iOS build, and CodeQL analysis. A PR is ready to merge only when those checks pass and review comments are resolved.
