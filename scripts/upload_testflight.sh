#!/usr/bin/env bash
# Archive GrubShelf and upload to TestFlight (App Store Connect).
# Prerequisites: Xcode, Apple Developer account, signing configured in Xcode.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="GrubShelf"
PROJECT="GrubShelf.xcodeproj"
ARCHIVE_PATH="$ROOT/build/GrubShelf.xcarchive"
EXPORT_PATH="$ROOT/build/export"
EXPORT_OPTIONS="$ROOT/ExportOptions.plist"

echo "==> Regenerating Xcode project (xcodegen)"
command -v xcodegen >/dev/null && xcodegen generate || true

if [[ ! -f "$ROOT/GrubShelf/Config.plist" ]]; then
  echo "ERROR: GrubShelf/Config.plist missing. Copy from Config.plist.example and add Supabase + Google keys."
  exit 1
fi

if grep -q 'YOUR_' "$ROOT/GrubShelf/Config.plist" 2>/dev/null; then
  echo "ERROR: Config.plist still has placeholder values."
  exit 1
fi

TEAM_ID="${DEVELOPMENT_TEAM:-}"
if [[ -z "$TEAM_ID" ]]; then
  TEAM_ID="$(xcodebuild -showBuildSettings -project "$PROJECT" -scheme "$SCHEME" -configuration Release 2>/dev/null | awk -F' = ' '/DEVELOPMENT_TEAM/ {print $2; exit}')"
fi

if [[ -z "$TEAM_ID" || "$TEAM_ID" == "" ]]; then
  echo ""
  echo "No DEVELOPMENT_TEAM found."
  echo "1. Open $PROJECT in Xcode"
  echo "2. Target GrubShelf → Signing & Capabilities → select your Team"
  echo "3. Repeat for GrubShelfWidget"
  echo "4. Re-run: DEVELOPMENT_TEAM=XXXXXXXXXX ./scripts/upload_testflight.sh"
  echo ""
  echo "Or upload manually: Product → Archive → Distribute App → App Store Connect → Upload"
  exit 1
fi

echo "==> Using DEVELOPMENT_TEAM=$TEAM_ID"
rm -rf "$ROOT/build"
mkdir -p "$ROOT/build"

echo "==> Archive (Release)"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=iOS" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  -allowProvisioningUpdates

echo "==> Export & upload to App Store Connect"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates

echo ""
echo "Upload started. Check App Store Connect → TestFlight for processing (often 10–30 minutes)."
echo "See docs/TESTFLIGHT_UPLOAD.md for tester setup."
