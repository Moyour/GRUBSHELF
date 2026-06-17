#!/bin/bash

# GrubShelf Authentication Diagnostic Script
# This script helps diagnose authentication and database connection issues

echo "🔍 GrubShelf Authentication Diagnostics"
echo "======================================="
echo ""

# Check if Config.plist exists
if [ ! -f "GrubShelf/Config.plist" ]; then
    echo "❌ Config.plist not found"
    exit 1
fi

# Extract Supabase URL
SUPABASE_URL=$(/usr/libexec/PlistBuddy -c "Print :SUPABASE_URL" GrubShelf/Config.plist 2>/dev/null)
echo "✅ Supabase URL: $SUPABASE_URL"

# Check if API key exists (don't print the actual key)
API_KEY=$(/usr/libexec/PlistBuddy -c "Print :SUPABASE_ANON_KEY" GrubShelf/Config.plist 2>/dev/null)
if [ -n "$API_KEY" ]; then
    echo "✅ API Key: Configured (${#API_KEY} characters)"
else
    echo "❌ API Key: Missing"
    exit 1
fi

# Test basic connectivity to Supabase
echo ""
echo "Testing network connectivity..."
if curl -s --max-time 5 -o /dev/null -w "%{http_code}" "$SUPABASE_URL/rest/v1/" -H "apikey: $API_KEY" | grep -q "200\|400\|401"; then
    echo "✅ Can reach Supabase server"
else
    echo "❌ Cannot reach Supabase server (check internet connection)"
    exit 1
fi

echo ""
echo "======================================="
echo "✅ Basic configuration checks passed"
echo ""
echo "If you're still seeing errors, try:"
echo "1. Sign out and sign back in"
echo "2. Check your household membership in the app"
echo "3. Check the Xcode console for detailed error messages"
