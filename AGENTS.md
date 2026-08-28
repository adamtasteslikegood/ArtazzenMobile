# AGENTS.md

## Project

ArtazzenMobile is a SwiftUI iOS 17+ Swift Package. `Sources/` contains the executable app, and `Tests/ArtazzenMobileTests/` contains XCTest coverage. The app consumes the Artazzen backend API; preserve the existing API shapes unless a change explicitly updates that contract.

## Branching strategy

- `main` is the protected integration branch.
- Create focused feature, fix, docs, or chore branches from the current `origin/main`.
- Push branches and merge through pull requests targeting `main`; do not force-push shared branches or commit directly to `main`.
- Keep PRs focused and use the pull request template. Resolve review threads and wait for refreshed checks after changes.

## Required checks

Pull requests and pushes to `main` run `.github/workflows/ci.yml`: SwiftLint, `swift-format`, XCTest on an iOS Simulator, and a generic iOS build. `.github/workflows/codeql.yml` runs advanced Swift CodeQL analysis on pull requests, pushes, and weekly. Dependabot checks GitHub Actions dependencies weekly.

Run the same commands locally from [QUICKSTART.md](QUICKSTART.md) before opening a PR. Linux is not a supported build environment for this package.

## Repository templates and docs

- `.github/PULL_REQUEST_TEMPLATE.md` defines the required PR description and testing evidence.
- `.github/ISSUE_TEMPLATE/bug_report.md` and `feature_request.md` structure new issues.
- `CONTRIBUTING.md` describes the contribution workflow and quality gates.
- `QUICKSTART.md` documents setup and local verification.

Keep documentation factual, avoid secrets, and update it when branch policy or CI checks change.
