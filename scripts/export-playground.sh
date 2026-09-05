#!/usr/bin/env bash
# Copy app sources into the iPad Swift Playgrounds document.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Artazzen.swiftpm/Sources"
mkdir -p "$DEST"
rsync -a --delete --exclude '.DS_Store' "$ROOT/Sources/" "$DEST/"
echo "Updated $DEST"
