#!/bin/bash

# ABOUTME: Script to clear corrupted app cache and database files
# ABOUTME: Run this when the app crashes on startup due to corrupted data

echo "🧹 Clearing OpenVine cache and database files..."

# Clear iOS Simulator data
if [ -d "$HOME/Library/Developer/CoreSimulator" ]; then
    echo "📱 Clearing iOS Simulator data..."
    rm -rf "$HOME/Library/Developer/CoreSimulator/Devices/*/data/Containers/Data/Application/*/Library/Caches/openvine"
    rm -rf "$HOME/Library/Developer/CoreSimulator/Devices/*/data/Containers/Data/Application/*/Documents/openvine"
fi

# Clear Android Emulator data
if [ -d "$HOME/.android/avd" ]; then
    echo "🤖 Clearing Android Emulator data..."
    find "$HOME/.android/avd" -name "*openvine*" -type d -exec rm -rf {} + 2>/dev/null || true
fi

# Clear macOS app data
if [ -d "$HOME/Library/Containers/co.openvine.mobile" ]; then
    echo "💻 Clearing macOS app data..."
    rm -rf "$HOME/Library/Containers/co.openvine.mobile/Data/Library/Caches"
    rm -rf "$HOME/Library/Containers/co.openvine.mobile/Data/Documents"
fi

# Clear test Hive files
echo "🗃️ Clearing test Hive files..."
rm -f test_hive/*.hive
rm -f test_hive/*.lock

# Clear Flutter build cache
echo "🔨 Clearing Flutter build cache..."
flutter clean

echo "✅ Cache cleared! The app should now start cleanly."
echo "⚠️  Note: You'll need to log in again and settings will be reset."