#!/bin/bash

# Clear GrubShelf app data and cached auth tokens
# This will force the app to sign in fresh

echo "🧹 Clearing GrubShelf app data..."

# Clear UserDefaults (app preferences and cached auth)
defaults delete com.grubshelf.GrubShelf 2>/dev/null || echo "No app defaults found"

# Clear iOS Simulator data (if using simulator)
if command -v xcrun &> /dev/null; then
    echo "Clearing iOS Simulator data..."
    xcrun simctl uninstall booted com.grubshelf.GrubShelf 2>/dev/null || echo "Not running in simulator or app not installed"
fi

echo ""
echo "✅ Done! Now:"
echo "1. Build and run the app from Xcode"
echo "2. Sign in with your credentials"
echo "3. The app will have a fresh auth session"
