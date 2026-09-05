# AGENTS.md

## Project

ArtazzenMobile is a SwiftUI iOS 17+ Swift Package. `Sources/` contains the executable app, and `Tests/ArtazzenMobileTests/` contains XCTest coverage. The app consumes the Artazzen backend API; preserve the existing API shapes unless a change explicitly updates that contract.

## Codebase map

Swift 5.9, SwiftUI-only (UIKit appears only for `PhotosPicker`/`UIImage` in CaptureView), no third-party dependencies.

- `Sources/ArtazzenMobileApp.swift` — app entry; `WindowGroup` → `MainTabView` with `AppSession` and dark-mode scheme.
- `Sources/Views/MainTabView.swift` — `TabView` with 5 tabs: Queue, Review (swipe deck), Capture, Gallery, Settings. Global tint `Color.azTeal`.
- `Sources/Models/` — `Artwork` (core model), `AIConfig`, `DesignTokens` (palette + fonts).
- `Sources/Services/ArtazzenAPI.swift` — `actor ArtazzenAPI` with Basic auth and one method per backend endpoint.
- `Sources/Views/` — one `NavigationStack` per tab; Gallery and Queue push `ArtworkDetailView` via `navigationDestination(for: Artwork.self)` + `NavigationLink(value:)`.
- `Sources/Components/` — `TagPill`, `StatusBadge`, `AIFieldEditor` (`AIFieldRow`), and `ArtworkCard` (currently unused).
- `Tests/ArtazzenMobileTests/ArtworkTests.swift` — decode/encode, relative image URLs, pending/gallery mapping, collections registry.

`AppSession` (`@Observable`) is the shared session: server URL, Basic auth, pending/gallery arrays, and ArtazzenAPI calls. Views still own local `@State` (search, filters, gestures). Credentials persist in `UserDefaults` for the prototype only; do not commit them.

## Design system

`Sources/Models/DesignTokens.swift` defines the palette (`azCarbon`, `azParchment`, `azTeal`, `azOrange`, `azViolet`) and three custom fonts (ClashGrotesk-Bold, InstrumentSans-Regular, JetBrainsMono-Regular). The font files are not bundled in this package, so `Font.custom` silently falls back to the system font. There is no design doc in this repo; the original design handoff and the backend contract live in the `ArtazzenDotCom` repository.

## API contract notes

- Auth: HTTP Basic from the `username`/`password` passed to `ArtazzenAPI.init`.
- Endpoints: `GET /admin/api/new-files`, `POST /admin/metadata/<filename>` (form-encoded), `POST /admin/ai/regenerate` (JSON), `POST /admin/upload` (multipart), `POST /admin/unapprove/<name>`, `POST /admin/delete/<name>`, `GET /admin/api/collections` (registry objects, not string arrays), `GET/POST /admin/config`.
- Response shapes mirror the FastAPI backend in `ArtazzenDotCom`; preserve them unless the contract change is deliberate.
- Inconsistency to be aware of: `saveMetadata` accepts status codes `200..<400`; every other call accepts `200..<300`.
- `Artwork` JSON uses snake_case keys (`ai_generated`, `detected_at`, ...). `Artwork` equality and hashing are filename-only by design.

## Current state (2026-09-05)

Prototype wiring landed: Settings stores server URL + Basic auth, `AppSession` loads the admin API, and dark mode applies `preferredColorScheme`. Remaining gaps:

- Hide on the review deck is local-only (FastAPI has no hide endpoint).
- `ArtworkCard` is unused. `unapprove` and `delete` still have no UI callers.
- Custom fonts are not bundled (see Design system).
- Admin password is stored in `UserDefaults` for the iPad prototype; do not ship that as-is.
- Linux still cannot build this package. Visual QA needs Xcode, Simulator, or `Artazzen.swiftpm` in Swift Playgrounds.

`Artazzen.swiftpm` is the iPad Swift Playgrounds App Playground. Refresh it with `./scripts/export-playground.sh` after `Sources/` changes.

## Conventions

- Swift 5.9, `@State`-based views; prefer `navigationDestination` + `NavigationLink(value:)` over `NavigationLink(destination:)`.
- JSON coding keys are snake_case; keep them in sync with the backend contract.
- Format Swift with `swift-format` (4-space indent, 100-column limit) and run strict SwiftLint before opening a PR.
- Add or update XCTest coverage for behavior changes; test files live in `Tests/ArtazzenMobileTests/`.

## Branching strategy

- `main` is the protected integration branch.
- Create focused feature, fix, docs, or chore branches from the current `origin/main`.
- Push branches and merge through pull requests targeting `main`; do not force-push shared branches or commit directly to `main`.
- Keep PRs focused and use the pull request template. Resolve review threads and wait for refreshed checks after changes.

## Required checks

Pull requests and pushes to `main` run `.github/workflows/ci.yml`: strict SwiftLint, a `swift-format` diagnostic, XCTest on an iOS Simulator, and a generic iOS build. `.github/workflows/codeql.yml` runs advanced Swift CodeQL analysis on pull requests, pushes, and weekly. Dependabot checks GitHub Actions dependencies weekly.

Run the same commands locally from [QUICKSTART.md](QUICKSTART.md) before opening a PR. Linux is not a supported build environment for this package.

## Repository templates and docs

- `.github/PULL_REQUEST_TEMPLATE.md` defines the required PR description and testing evidence.
- `.github/ISSUE_TEMPLATE/bug_report.md` and `feature_request.md` structure new issues.
- `CONTRIBUTING.md` describes the contribution workflow and quality gates.
- `QUICKSTART.md` documents setup and local verification.

Keep documentation factual, avoid secrets, and update it when branch policy or CI checks change.
