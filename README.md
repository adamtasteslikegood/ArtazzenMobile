# ArtazzenMobile

A SwiftUI iOS 17+ client for the [Artazzen](https://artazzen.com) gallery — an artwork gallery and curation platform. This app talks to the FastAPI backend defined in the `ArtazzenDotCom` web-app repository; the backend API contract (routes, request/response shapes) lives there, is published live at [artazzen.com/docs](https://artazzen.com/docs) (OpenAPI at [artazzen.com/openapi.json](https://artazzen.com/openapi.json)), and is documented in that repo's `CLAUDE.md` route map.

Admin JSON the app uses (HTTP Basic): `GET /admin/api/new-files` (pending + gallery sidecars), `POST /admin/metadata/<file>`, `POST /admin/upload`, `POST /admin/ai/regenerate`, `GET/POST /admin/config`, `GET /admin/api/collections`. Public pages at `/` are HTML, not a gallery JSON API. Artwork metadata is the per-image sidecar described by `ImageSidecar.schema.json` in ArtazzenDotCom.

To try the UI on an iPad, copy `Artazzen.swiftpm` into Swift Playgrounds (see [QUICKSTART.md](QUICKSTART.md)). This package was extracted from `ArtazzenDotCom` on 2026-08-19 and cannot be built on Linux — it requires Xcode or Swift Playgrounds.
