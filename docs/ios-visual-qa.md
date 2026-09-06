# iPhone and iPad visual QA

## Request ownership

The mobile app uploads through `POST /admin/upload`, saves/approves metadata through
`POST /admin/metadata/<filename>`, and previews AI fields through
`POST /admin/ai/regenerate` (`preview: true`). The ArtazzenDotCom backend sends the
OpenAI Responses API request and owns the OpenAI key. The app stores only its
Artazzen admin credentials. The Settings model picker preserves a model returned
by the server even if it is outside the prototype's two preset choices. A shared
model catalog and AI settings redesign remain separate work.

Artwork downloads use the API's resolved `url`, including the production
`/images/` mount, without attaching admin credentials. `ArtworkImageLoader`
validates HTTP status and decodes orientation-correct thumbnails with ImageIO.
Decoded images have a 32 MiB cache budget. The view has distinct loading, success,
and failure states; touch and hold an image to retry (also a VoiceOver action).
Gallery crops to a consistent portrait tile; Review and Detail show the full image
inside a portrait canvas. Decoding smaller images does not reduce download size;
a backend thumbnail endpoint would be a separate contract change.

## Design references

The adjacent ArtazzenDotCom checkout contains:

- `DESIGN.md`: Carbon/Parchment, teal/orange/violet, typography, 8px spacing.
- `artazzen-design-system/project/DESIGN.md` and `project/preview/`: design export.
- `ds-bundle/`: HTML/CSS component references.

The specific interactive iOS HTML mockup was not located in either checkout on
2026-09-06. These web references establish the palette and typography, not proof
of native layout. Custom font files remain unbundled.

## Device feedback loop without a Mac

1. Download the successful PR CI run's `Artazzen-iPad-<commit>` artifact, or use
   `./scripts/package-playground.sh` to create a local document ZIP.
2. Extract the document as described in QUICKSTART, open `Artazzen.swiftpm` in
   iPad Swift Playgrounds, and Run. Confirm which commit's document you opened.
3. Connect in Settings. Verify Queue, Gallery, Review, and Detail images with both
   an existing server artwork and an image uploaded through the app.
4. If an image fails, record the visible error, artwork filename, configured server
   URL, iPadOS version, and whether the same image opens in Safari. Never include
   passwords. Touch and hold the image and choose Retry Image.
5. Check portrait, landscape, Split View, dark mode, and larger accessibility text.
   Gallery tiles should not change size while loading. Review metadata should
   scroll while Hide/Approve stay below the content. Confirm vertical scrolling
   does not approve/hide work, and horizontal swipes still work. Hide is local to
   the session; approve changes backend state, so use a test artwork.
6. Share screenshots or a short screen recording for the next layout iteration.

On 2026-09-06 four sampled public production image URLs returned HTTP 200 with
JPEG bodies through curl; a Swift URLSession request also returned HTTP 200.
These probes do not reproduce or resolve the reported iPad-specific failure.
The updated document needs device validation before that report can be closed.

## gstack device bridge

`ios-sync` regenerates an existing `ios-qa` debug bridge; it does not sync the web
API or import a design. No `DebugBridgeGenerated` installation was found here.
The installed gstack `ios-qa` prerequisites require macOS, Xcode/devicectl, and a
paired USB device. This Linux host cannot build/deploy that bridge or verify its
state snapshot. No bridge or remote-control endpoint is added to the app.
Swift Playgrounds builds and device feedback are the available workflow until a
Mac/device host is connected. CI compilation does not prove on-device rendering.
