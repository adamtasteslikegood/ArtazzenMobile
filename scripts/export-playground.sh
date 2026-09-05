#!/usr/bin/env bash
# Copy app sources into the iPad Swift Playgrounds document.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Artazzen.swiftpm/Sources"
if [[ "${1:-}" == "--check" ]]; then
    diff -qr "$ROOT/Sources" "$DEST"
    exit
fi
mkdir -p "$DEST"
rsync -a --delete --exclude '.DS_Store' "$ROOT/Sources/" "$DEST/"
echo "Updated $DEST"
