#!/usr/bin/env bash
# Downloads Inter (variable), Outfit (variable), and IBM Plex Mono static TTFs into GrubShelf/Fonts/.
# Sources: https://github.com/google/fonts (OFL). Run from repo root: ./scripts/download-brand-fonts.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/GrubShelf/Fonts"
mkdir -p "$DEST"

curl -fsSL -o "$DEST/Inter-Variable.ttf" \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/inter/Inter%5Bopsz%2Cwght%5D.ttf"
curl -fsSL -o "$DEST/Outfit-Variable.ttf" \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/outfit/Outfit%5Bwght%5D.ttf"
curl -fsSL -o "$DEST/IBMPlexMono-Regular.ttf" \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/ibmplexmono/IBMPlexMono-Regular.ttf"
curl -fsSL -o "$DEST/IBMPlexMono-SemiBold.ttf" \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/ibmplexmono/IBMPlexMono-SemiBold.ttf"
curl -fsSL -o "$DEST/IBMPlexMono-Bold.ttf" \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/ibmplexmono/IBMPlexMono-Bold.ttf"

echo "Wrote brand fonts to $DEST"
