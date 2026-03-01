# Video Lifecycle Fix: Tab Switch Background Playback

## Problem

Videos were continuing to play in the background when users switched tabs, causing:
- Multiple video controllers staying alive simultaneously
- Background audio playback when viewing profiles
- Memory leaks from undisposed controllers
- Generation counter incrementing (`gen=1`, `gen=2`, `gen=3`) indicating duplicate controllers

## Root Cause

1. **IndexedStack keeps widgets alive**: `MainNavigationScreen` uses `IndexedStack` to preserve tab state
2. **AutomaticKeepAliveClientMixin**: `VideoFeedScreen` uses this mixin to maintain scroll position
3. **No tab visibility awareness**: Video widgets remained mounted even when tabs were switched
4. **Active video not cleared**: The `activeVideoProvider` was only cleared on specific navigation, not on all tab switches

Result: Video feed widgets stayed mounted, controllers stayed alive with 3-second grace period, videos played in background.

## Solution

**Minimal 3-Line Fix** in `lib/providers/tab_visibility_provider.dart`:

```dart
void setActiveTab(int index) {
  // CRITICAL: Clear active video when switching tabs to prevent background playback
  // This ensures videos are paused and controllers can be disposed when tabs become inactive
  ref.read(activeVideoProvider.notifier).clearActiveVideo();

  state = index;
}
```

## How It Works

1. **Tab switch triggers cleanup**: When user switches tabs, `setActiveTab()` is called
2. **Active video cleared immediately**: `clearActiveVideo()` removes the current active video
3. **Widget reacts to state change**: `VideoFeedItem` watches `isVideoActiveProvider(videoId)`
4. **Video pauses automatically**: Widget's listener detects `isActive` changed to `false`, calls `controller.pause()`
5. **Controller disposal after grace**: Provider's `keepAlive()` grace period (3s) allows controller to dispose

## Test Coverage

**Test file**: `test/widgets/video_tab_switch_lifecycle_test.dart`

Three comprehensive tests verify:
1. ✅ Active video cleared when switching FROM video tab TO non-video tab
2. ✅ Active video cleared when switching FROM explore tab TO other tabs
3. ✅ Active video cleared when switching BETWEEN video tabs (allowing new tab to set its own)

All tests PASS.

## Benefits

- **Single source of truth**: One place (`TabVisibility`) handles all tab switch cleanup
- **Automatic cleanup**: No manual pause/dispose calls needed
- **Works with IndexedStack**: Leverages existing reactive architecture
- **Minimal changes**: 3 lines of code + import
- **TDD verified**: Comprehensive test coverage ensures correctness

## Related Files

- **Modified**: `lib/providers/tab_visibility_provider.dart` (3-line fix)
- **Tests**: `test/widgets/video_tab_switch_lifecycle_test.dart` (new)
- **Related**: `lib/providers/individual_video_providers.dart` (controller lifecycle)
- **Related**: `lib/widgets/video_feed_item.dart` (reactive video widget)

## Migration Notes

No breaking changes. The fix is backward compatible and improves existing behavior.

Users will notice:
- Videos stop immediately when switching tabs (expected behavior)
- No background audio when viewing profiles
- Lower memory usage
- Single controller per video at any time
