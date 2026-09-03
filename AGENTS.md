# AGENTS.md

## Project

ArtazzenMobile is a SwiftUI iOS 17+ Swift Package. `Sources/` contains the executable app, and `Tests/ArtazzenMobileTests/` contains XCTest coverage. The app consumes the Artazzen backend API; preserve the existing API shapes unless a change explicitly updates that contract.

## Codebase map

Swift 5.9, SwiftUI-only (UIKit appears only for `PhotosPicker`/`UIImage` in CaptureView), no third-party dependencies.

- `Sources/ArtazzenMobileApp.swift` — app entry; `WindowGroup` → `MainTabView`.
- `Sources/Views/MainTabView.swift` — `TabView` with 5 tabs: Queue, Review (swipe deck), Capture, Gallery, Settings. Global tint `Color.azTeal`.
- `Sources/Models/` — `Artwork` (core model), `AIConfig`, `DesignTokens` (palette + fonts).
- `Sources/Services/ArtazzenAPI.swift` — `actor ArtazzenAPI` with Basic auth and one method per backend endpoint.
- `Sources/Views/` — one `NavigationStack` per tab; Gallery and Queue push `ArtworkDetailView` via `navigationDestination(for: Artwork.self)` + `NavigationLink(value:)`.
- `Sources/Components/` — `TagPill`, `StatusBadge`, `AIFieldEditor` (`AIFieldRow`), and `ArtworkCard` (currently unused).
- `Tests/ArtazzenMobileTests/ArtworkTests.swift` — 5 tests covering `Artwork` JSON decode/encode and `imageURL(relativeTo:)` behavior.

There is no ViewModel or `ObservableObject` layer. Views hold their own `@State`, and no view loads data from the network yet.

## Design system

`Sources/Models/DesignTokens.swift` defines the palette (`azCarbon`, `azParchment`, `azTeal`, `azOrange`, `azViolet`) and three custom fonts (ClashGrotesk-Bold, InstrumentSans-Regular, JetBrainsMono-Regular). The font files are not bundled in this package, so `Font.custom` silently falls back to the system font. There is no design doc in this repo; the original design handoff and the backend contract live in the `ArtazzenDotCom` repository.

## API contract notes

- Auth: HTTP Basic from the `username`/`password` passed to `ArtazzenAPI.init`.
- Endpoints: `GET /admin/api/new-files`, `POST admin/metadata/<filename>` (form-encoded), `POST /admin/ai/regenerate` (JSON), `POST /admin/upload` (multipart), `POST /admin/unapprove/<name>`, `POST /admin/delete/<name>`, `GET /admin/api/collections`, `GET /admin/config`.
- Response shapes mirror the FastAPI backend in `ArtazzenDotCom`; preserve them unless the contract change is deliberate.
- Inconsistency to be aware of: `saveMetadata` accepts status codes `200..<400`; every other call accepts `200..<300`.
- `Artwork` JSON uses snake_case keys (`ai_generated`, `detected_at`, ...). `Artwork` equality and hashing are filename-only by design.

## Current state — known gaps (verified 2026-09-02)

The package builds and CI passes, but the app is a static UI shell. Verified findings:

- `ArtazzenAPI` is never instantiated anywhere. Every "API call via ArtazzenAPI" comment in the views is a placeholder; no view loads, saves, uploads, or regenerates anything.
- No server URL or credential configuration exists: no defaults, no settings fields. The app cannot reach the backend as written.
- Every screen's data array (`pending`, `artworks`, `collections`) starts empty and is never populated.
- The Dark Mode toggle writes `@AppStorage("az-dark-mode")`, but nothing reads it and no `preferredColorScheme` is applied, so it is a no-op.
- `ArtworkCard` is dead code. `unapprove`, `delete`, `fetchConfig`, and `fetchCollections` on the API client have no callers.
- `SwipeDeckView` approve/hide animate the top card and mutate local state only; nothing is sent to the backend.
- Custom fonts are not bundled (see Design system).

Treat any code that appears to perform networking or persistence as unverified until a wiring commit lands.

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
