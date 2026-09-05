#!/usr/bin/env bash
# The archive contains the complete document, never an external package path.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
./scripts/export-playground.sh --check
REVISION="$(git rev-parse --short=12 HEAD)"
OUTPUT="${1:-$ROOT/dist}"
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
ARCHIVE="$OUTPUT/Artazzen-$REVISION.zip"
if [[ -e "$ARCHIVE" ]]; then
    echo "Archive already exists: $ARCHIVE" >&2
    exit 1
fi
zip -qr "$ARCHIVE" Artazzen.swiftpm/Package.swift Artazzen.swiftpm/Sources
unzip -tq "$ARCHIVE"
echo "$ARCHIVE"
