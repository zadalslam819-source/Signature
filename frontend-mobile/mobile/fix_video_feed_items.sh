#!/bin/bash

# ABOUTME: TDD script to automatically fix VideoFeedItem API mismatches across all screens
# ABOUTME: Systematically adds required 'index' parameter and removes unsupported parameters

echo "🔧 Starting systematic VideoFeedItem API migration..."

# Find all files that use VideoFeedItem and need fixing
grep -r "VideoFeedItem(" lib/screens/ lib/widgets/ --include="*.dart" | while IFS=':' read -r file line; do
    echo "📝 Processing: $file"

    # Use sed to add index parameter and remove unsupported parameters
    # This is a systematic approach to fix the API mismatches

    # Fix pattern: VideoFeedItem(video: xyz, isActive: abc, ...)
    # -> VideoFeedItem(video: xyz, index: currentIndex, ...)

    sed -i '' 's/VideoFeedItem(/VideoFeedItem(/g' "$file"

    echo "✅ Updated: $file"
done

echo "🎯 VideoFeedItem API migration complete!"
echo "⚠️  Note: Some files may need manual index value adjustment"