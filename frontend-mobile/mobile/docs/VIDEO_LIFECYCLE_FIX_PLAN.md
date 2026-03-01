# Video Lifecycle Management Fix Plan

## Problem Statement

Videos play randomly when they shouldn't:
- Videos continue playing when app is backgrounded/locked
- Videos play when navigating to other screens (Settings, Profile, etc.)
- Videos play when widget is off-screen but still in widget tree
- Battery drain from background video playback

## Root Cause Analysis

### Current Architecture Issues

1. **AppLifecycleHandler** (`lib/widgets/app_lifecycle_handler.dart:83`)
   - Calls `visibilityManager.pauseAllVideos()` when app backgrounds
   - **BUG:** This only clears internal state, doesn't pause controllers
   - **BUG:** Never calls `activeVideoProvider.notifier.clearActiveVideo()`
   - **RESULT:** Active video stays active and playing in background

2. **VideoVisibilityManager.pauseAllVideos()** (`lib/services/video_visibility_manager.dart:155`)
   - Only clears `_playableVideos`, `_visibilityMap`, and flags
   - **BUG:** Doesn't actually call `.pause()` on any video controllers
   - **BUG:** Doesn't clear the `activeVideoProvider` state
   - **RESULT:** Controllers keep playing in background

3. **VideoFeedItem** (`lib/widgets/video_feed_item.dart:85-104`)
   - Listens to `isVideoActiveProvider` changes
   - **BUG:** No awareness of widget visibility (only active state)
   - **BUG:** Doesn't pause when widget scrolls off-screen
   - **RESULT:** Video plays if active, even when widget not visible

4. **Tab Navigation** (`lib/screens/video_feed_screen.dart`, etc.)
   - Each screen sets active video on mount
   - **BUG:** Doesn't clear active video when navigating away
   - **RESULT:** Video from previous tab keeps playing when you switch tabs

## Test-Driven Development Plan

### Phase 1: App Lifecycle Tests (Backgrounding/Locking)

#### Test 1.1: App backgrounded clears active video
```dart
testWidgets('App going to background clears active video', (tester) async {
  // Setup: Mount app with active video
  // Action: Simulate AppLifecycleState.paused
  // Assert: activeVideoProvider.currentVideoId == null
});
```

#### Test 1.2: App backgrounded pauses video controller
```dart
testWidgets('App going to background pauses playing video', (tester) async {
  // Setup: Mount app with playing video
  // Action: Simulate AppLifecycleState.paused
  // Assert: controller.value.isPlaying == false
});
```

#### Test 1.3: App resumed doesn't auto-play videos
```dart
testWidgets('App resuming does not auto-play videos', (tester) async {
  // Setup: App was backgrounded with video
  // Action: Simulate AppLifecycleState.resumed
  // Assert: controller.value.isPlaying == false (relies on visibility)
});
```

### Phase 2: Tab Navigation Tests

#### Test 2.1: Switching tabs clears active video
```dart
testWidgets('Switching to different tab clears active video', (tester) async {
  // Setup: Video playing on Home tab
  // Action: Switch to Settings tab
  // Assert: activeVideoProvider.currentVideoId == null
});
```

#### Test 2.2: Switching tabs pauses video
```dart
testWidgets('Switching tabs pauses playing video', (tester) async {
  // Setup: Video playing on Home tab
  // Action: Switch to Settings tab
  // Assert: controller.value.isPlaying == false
});
```

#### Test 2.3: Returning to original tab doesn't auto-play
```dart
testWidgets('Returning to tab does not auto-play previous video', (tester) async {
  // Setup: Video was playing, switched tabs, now switching back
  // Action: Switch back to original tab
  // Assert: controller.value.isPlaying == false (relies on visibility)
});
```

### Phase 3: Widget Visibility Tests

#### Test 3.1: VideoFeedItem pauses when scrolled off-screen
```dart
testWidgets('VideoFeedItem pauses when scrolled off screen', (tester) async {
  // Setup: Video playing and visible
  // Action: Scroll so widget is off-screen
  // Assert: controller.value.isPlaying == false
});
```

#### Test 3.2: VideoFeedItem doesn't play when off-screen but active
```dart
testWidgets('VideoFeedItem does not play when off-screen even if active', (tester) async {
  // Setup: Video is active but widget is off-screen
  // Action: Check playback state
  // Assert: controller.value.isPlaying == false
});
```

#### Test 3.3: VideoFeedItem plays when scrolled back into view
```dart
testWidgets('VideoFeedItem plays when scrolled back into view if active', (tester) async {
  // Setup: Video active but was paused when scrolled off-screen
  // Action: Scroll back into view
  // Assert: controller.value.isPlaying == true (if still active)
});
```

### Phase 4: Modal/Overlay Tests

#### Test 4.1: Opening modal pauses video
```dart
testWidgets('Opening modal (camera, settings) pauses active video', (tester) async {
  // Setup: Video playing
  // Action: Open camera screen
  // Assert: controller.value.isPlaying == false
});
```

#### Test 4.2: Closing modal doesn't auto-resume video
```dart
testWidgets('Closing modal does not auto-resume video', (tester) async {
  // Setup: Video was paused when modal opened
  // Action: Close modal
  // Assert: controller.value.isPlaying == false (relies on visibility)
});
```

## Implementation Plan

### Step 1: Fix AppLifecycleHandler (app backgrounding)

**File:** `lib/widgets/app_lifecycle_handler.dart`

**Changes:**
```dart
case AppLifecycleState.inactive:
case AppLifecycleState.paused:
case AppLifecycleState.hidden:
  Log.info('📱 App backgrounded - clearing active video and pausing');

  // CRITICAL: Clear active video FIRST
  ref.read(activeVideoProvider.notifier).clearActiveVideo();

  // Then pause all videos
  Future.microtask(() => visibilityManager.pauseAllVideos());
```

**Expected behavior:**
- Setting `activeVideoProvider` to null triggers `VideoFeedItem.listenManual()` callback
- Callback receives `next=false`, calls `_handlePlaybackChange(false)`
- `_handlePlaybackChange(false)` calls `controller.pause()`
- Video stops playing

### Step 2: Enhance pauseAllVideos() with controller access

**File:** `lib/services/video_visibility_manager.dart`

**Problem:** `VideoVisibilityManager` doesn't have access to video controllers (they're managed by Riverpod providers)

**Solution:** Make `pauseAllVideos()` accept `Ref` to access active controller

```dart
void pauseAllVideos(Ref ref) {
  // Clear active video - this triggers VideoFeedItem to pause via listener
  ref.read(activeVideoProvider.notifier).clearActiveVideo();

  // Clear internal state
  _playableVideos.clear();
  _visibilityMap.clear();
  _autoPlayEnabled = false;
  _lastPlayingVideo = null;

  Log.info('⏸️ Cleared active video and visibility state');
}
```

**Update caller:**
```dart
// app_lifecycle_handler.dart
Future.microtask(() => visibilityManager.pauseAllVideos(ref));
```

### Step 3: Add Tab Visibility Tracking

**File:** `lib/providers/tab_visibility_provider.dart` (already exists)

**Enhancement:** Add listener in each tab's screen to clear active video on tab switch

**Example for video_feed_screen.dart:**
```dart
@override
void initState() {
  super.initState();

  // Listen for tab changes
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.listenManual(
      tabVisibilityProvider,
      (prev, next) {
        if (next != widget.tabIndex) {
          // This tab is no longer visible
          Log.info('🔄 Tab ${widget.tabIndex} hidden, clearing active video');
          ref.read(activeVideoProvider.notifier).clearActiveVideo();
        }
      },
    );
  });
}
```

**Files to update:**
- `lib/screens/video_feed_screen.dart` (home tab)
- `lib/screens/explore_screen.dart` (explore tab)
- `lib/screens/profile_screen_scrollable.dart` (profile tab)

### Step 4: Add Widget Visibility Awareness to VideoFeedItem

**File:** `lib/widgets/video_feed_item.dart`

**Add dependency:**
```yaml
# pubspec.yaml
dependencies:
  visibility_detector: ^0.4.0+2
```

**Wrap widget in VisibilityDetector:**
```dart
@override
Widget build(BuildContext context) {
  return VisibilityDetector(
    key: Key('video_${widget.video.id}'),
    onVisibilityChanged: (info) {
      final isVisible = info.visibleFraction > 0.5; // 50% visible threshold

      if (!isVisible && _wasVisible) {
        // Widget scrolled off-screen - pause if playing
        Log.info('👁️ Video scrolled off-screen, pausing');
        _handlePlaybackChange(false);
      } else if (isVisible && !_wasVisible) {
        // Widget scrolled back into view - check if should play
        final isActive = ref.read(isVideoActiveProvider(widget.video.id));
        if (isActive) {
          Log.info('👁️ Video scrolled into view and is active, playing');
          _handlePlaybackChange(true);
        }
      }

      _wasVisible = isVisible;
    },
    child: /* existing widget tree */,
  );
}
```

**Add state variable:**
```dart
bool _wasVisible = false;
```

### Step 5: Fix Modal/Overlay Behavior

**Files:**
- `lib/screens/camera_screen.dart`
- `lib/screens/pure/vine_preview_screen_pure.dart`
- Any other fullscreen overlays

**Add in initState:**
```dart
@override
void initState() {
  super.initState();

  // Clear active video when camera opens
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(activeVideoProvider.notifier).clearActiveVideo();
  });
}
```

## Testing Strategy

### Unit Tests
- Test `VideoVisibilityManager.pauseAllVideos()` clears active video
- Test `ActiveVideoNotifier.clearActiveVideo()` updates state correctly

### Widget Tests
- All tests from Phase 1-4 above
- Mock video controllers to verify `.pause()` and `.play()` calls
- Test race conditions (rapid tab switching, etc.)

### Integration Tests
- Real app flow: background → resume → verify no playback
- Real app flow: tab switch → verify pause → switch back → verify no auto-play
- Real app flow: scroll feed → verify only visible video plays

## Success Criteria

1. ✅ Videos NEVER play when app is backgrounded or locked
2. ✅ Videos NEVER play when on a different tab
3. ✅ Videos NEVER play when widget is off-screen
4. ✅ Videos NEVER auto-resume on app resume (rely on visibility)
5. ✅ Videos NEVER auto-resume when returning to tab (rely on visibility)
6. ✅ Videos ONLY play when:
   - Widget is visible (>50% on screen)
   - Video is active (PageView current page)
   - App is in foreground
   - Tab is active

## Files to Modify

### Implementation Files
1. `lib/widgets/app_lifecycle_handler.dart` - Clear active video on background
2. `lib/services/video_visibility_manager.dart` - Accept Ref, clear active video
3. `lib/widgets/video_feed_item.dart` - Add VisibilityDetector
4. `lib/screens/video_feed_screen.dart` - Listen to tab changes
5. `lib/screens/explore_screen.dart` - Listen to tab changes
6. `lib/screens/profile_screen_scrollable.dart` - Listen to tab changes
7. `lib/screens/camera_screen.dart` - Clear active video on mount
8. `pubspec.yaml` - Add visibility_detector dependency

### Test Files
1. `test/widgets/app_lifecycle_video_pause_test.dart` - NEW (Phase 1 tests)
2. `test/widgets/tab_navigation_video_pause_test.dart` - NEW (Phase 2 tests)
3. `test/widgets/video_feed_item_visibility_test.dart` - NEW (Phase 3 tests)
4. `test/widgets/modal_video_pause_test.dart` - NEW (Phase 4 tests)
5. Update existing `test/widgets/video_feed_item_*.dart` tests to account for visibility

## Estimated Effort

- **Test Writing:** 4-6 hours (4 test files, ~2-3 tests each)
- **Implementation:** 3-4 hours (8 files to modify)
- **Manual Testing:** 1-2 hours (verify on real device)
- **Total:** ~8-12 hours

## Dependencies

- Add `visibility_detector: ^0.4.0+2` to pubspec.yaml
- No breaking changes to existing API
- All changes are additive or internal

## Rollback Plan

If issues arise:
1. Revert `app_lifecycle_handler.dart` changes (removes clearActiveVideo call)
2. Revert `video_feed_item.dart` VisibilityDetector wrapper
3. App returns to current behavior (videos play when shouldn't, but no crashes)

## Next Steps After This Fix

Once lifecycle is solid:
1. Implement Video File Resolver (cache optimization)
2. Add preloading improvements
3. Add analytics for playback behavior
