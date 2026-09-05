# ArtazzenMobile

A SwiftUI iOS 17+ client for the [Artazzen](https://artazzen.com) gallery — an artwork gallery and curation platform. This app talks to the FastAPI backend defined in the `ArtazzenDotCom` web-app repository; the backend API contract (routes, request/response shapes) lives there, is published live at [artazzen.com/docs](https://artazzen.com/docs) (OpenAPI at [artazzen.com/openapi.json](https://artazzen.com/openapi.json)), and is documented in that repo's `CLAUDE.md` route map.

Admin JSON the app uses (HTTP Basic): `GET /admin/api/new-files` (pending + gallery sidecars), `POST /admin/metadata/<file>`, `POST /admin/upload`, `POST /admin/ai/regenerate`, `GET/POST /admin/config`, `GET /admin/api/collections`. Public pages at `/` are HTML, not a gallery JSON API. Artwork metadata is the per-image sidecar described by `ImageSidecar.schema.json` in ArtazzenDotCom.

To try the UI on an iPad, download the playground ZIP from a successful GitHub Actions CI run and open the contained `Artazzen.swiftpm` document in Swift Playgrounds (see [QUICKSTART.md](QUICKSTART.md)). The shared `ArtazzenCore` library contains the API, session, models, and Keychain credential storage. The runnable app requires Xcode or Swift Playgrounds; Linux core checks cannot verify the iOS app.
