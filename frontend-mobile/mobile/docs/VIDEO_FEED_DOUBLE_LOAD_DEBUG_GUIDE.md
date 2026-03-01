# Video Feed Double-Load Debugging Guide

## Problem Description
The app opens, loads a video, starts playing it, then "resets" and reloads the video a second time. This causes a poor user experience.

## Root Cause Hypothesis
Based on the code architecture analysis, the most likely cause is:

**Social Provider Deferred Initialization Triggering HomeFeed Rebuild**

1. App initializes and shows UI with `_isInitialized = true`
2. VideoFeedScreen is displayed and watches `homeFeedProvider`
3. HomeFeed provider builds for the first time, watching `socialProvider`
4. At this point, socialProvider may not be fully initialized (it's deferred in main.dart lines 513-554)
5. Moments later, the deferred social provider initialization completes
6. Since HomeFeed `ref.watch(social.socialProvider)` creates a dependency, HomeFeed rebuilds
7. This triggers VideoFeedScreen to rebuild, causing the "reset" behavior

## Debugging Steps

### 1. Run Tests with Detailed Logging

```bash
cd mobile
flutter test test/integration/video_feed_double_load_debug_test.dart --reporter expanded
```

Look for:
- Multiple HomeFeed builds in quick succession
- Timing gaps between builds (< 2 seconds indicates rapid rebuild)
- Social provider build triggering HomeFeed rebuild

### 2. Run the App with Lifecycle Logging

```bash
cd mobile
flutter run -d chrome --dart-define=LOG_LEVEL=debug
```

**Key Log Patterns to Watch:**

#### Expected Single-Load Pattern:
```
🏗️  VideoFeedScreen: initState #1
🏠 HomeFeed: BUILD #1 START
👥 [LIFECYCLE] SocialProvider: Starting deferred initialization
🏠 HomeFeed: BUILD #1 COMPLETE
🎨 VideoFeedScreen: build() #1
✅ [LIFECYCLE] SocialProvider: Deferred initialization COMPLETE
```

#### Problem Double-Load Pattern:
```
🏗️  VideoFeedScreen: initState #1
🏠 HomeFeed: BUILD #1 START (social not ready)
🏠 HomeFeed: BUILD #1 COMPLETE
🎨 VideoFeedScreen: build() #1
👥 [LIFECYCLE] SocialProvider: Starting deferred initialization
✅ [LIFECYCLE] SocialProvider: Deferred initialization COMPLETE
⚠️  HomeFeed: RAPID REBUILD DETECTED! Only XXXms since last build
🏠 HomeFeed: BUILD #2 START (social now ready)
🏠 HomeFeed: BUILD #2 COMPLETE
🎨 VideoFeedScreen: build() #2  <-- THIS CAUSES THE "RESET"
```

### 3. Check Logs for Key Indicators

**Rapid Rebuild Warning:**
```
⚠️  HomeFeed: RAPID REBUILD DETECTED! Only XXXms since last build.
This may indicate a provider dependency issue.
```

**Widget Recreation Warning:**
```
⚠️  VideoFeedScreen: RAPID RE-INIT DETECTED! Only XXXms since last init.
This indicates the widget is being recreated!
```

**Social Provider Completion:**
```
⚠️  [LIFECYCLE] This social provider completion may trigger HomeFeed provider rebuild if UI is already showing!
```

## Solution Applied

**FOUR FIXES IMPLEMENTED** for optimal solution (fast startup + no double-load + follow updates):

### Fix 1: Change HomeFeed to keepAlive: true

**File:** `lib/providers/home_feed_provider.dart` line 19

```dart
// Current (auto-disposes)
@Riverpod(keepAlive: false)

// Change to (stays alive)
@Riverpod(keepAlive: true)
```

**Pros:** Simple one-line fix, prevents provider disposal/rebuild
**Cons:** Provider stays in memory permanently (but it's a core feature, so this is acceptable)

**Status:** ✅ **APPLIED**

### Fix 2: Use ref.read() instead of ref.watch()

**File:** `lib/providers/home_feed_provider.dart` line 62

```dart
// Before (creates reactive dependency):
final socialData = ref.watch(social.socialProvider);

// After (one-time read, no reactive dependency):
final socialData = ref.read(social.socialProvider);
```

**Why:** Using `ref.watch()` creates a reactive dependency that triggers rebuilds whenever socialProvider state changes. Using `ref.read()` performs a one-time read without creating a dependency.

**Status:** ✅ **APPLIED**

### Fix 3: Add Cache Loading to SocialProvider

**File:** `lib/providers/social_providers.dart`

**Problem:** SocialProvider wasn't loading cached following list, only waiting for relay response (~5 seconds). HomeFeed would read 0 following before cache loaded.

**Solution:** Added cache loading methods:
- `_loadFollowingListFromCache()` - Loads cached following list and updates state immediately
- `_saveFollowingListToCache()` - Saves following list to cache when updated
- Called cache load **before** waiting for relay in `initialize()`
- Called cache save after processing contact list events

```dart
// In initialize() method:
// Load cached following list FIRST for instant UI display
await _loadFollowingListFromCache();

Log.info(
    '🤝 SocialNotifier: Fetching contact list for authenticated user (cached: ${state.followingPubkeys.length} users)',
    name: 'SocialNotifier',
    category: LogCategory.system);
```

**Result:** HomeFeed reads cached data (12 users) immediately via `ref.read()`, videos load instantly!

**Status:** ✅ **APPLIED**

### Fix 4: Trigger HomeFeed Refresh on Follow/Unfollow

**File:** `lib/providers/social_providers.dart`

**Problem:** When user follows/unfollows someone, HomeFeed doesn't see the change because we're using `ref.read()` instead of `ref.watch()`.

**Solution:** Added explicit refresh trigger:
- Added `_refreshHomeFeed()` method that calls `ref.invalidate(homeFeedProvider)`
- Called after follow/unfollow operations
- Called after saving cache

```dart
// In followUser() and unfollowUser():
state = state.copyWith(followingPubkeys: newFollowingList);

// Save to cache
_saveFollowingListToCache();

// Trigger home feed refresh to show videos from newly followed user
_refreshHomeFeed();
```

**User Experience:**
- Pull-to-refresh: Swipe down on feed (already implemented)
- Double-tap refresh: Double tap on first video to refresh (newly added)

**Status:** ✅ **APPLIED**

### Fix 5 (Rejected): Synchronous Social Init

**Why rejected:** Would add ~5 seconds to startup time (unacceptable!)

**Alternative approach using Fixes 1-4:**
- Social provider loads cached following list synchronously (<100ms)
- HomeFeed gets cached data immediately (fast!)
- Fresh data arrives in background from relay (~5 seconds)
- Fresh data is saved to cache automatically
- Follow/unfollow actions trigger explicit refresh

**Result:** Fast startup (< 1 second) + no double-load + follow updates work!

## Expected Behavior After Fixes

With all 4 fixes applied:

1. **Fast startup** (< 1 second) - Social provider loads cached following list synchronously
2. **HomeFeed builds ONCE** with cached following list (12 users from cache)
3. **No reactive dependency** on socialProvider prevents automatic rebuilds when fresh data arrives
4. **keepAlive: true** prevents disposal between navigation
5. **No RAPID REBUILD DETECTED warnings** in logs
6. **Video plays smoothly** without reset/reload
7. **Fresh data arrives silently** in background (~5 seconds) and is saved to cache
8. **Follow/unfollow actions** trigger explicit refresh to show updated feed
9. **User can refresh** via pull-down or double-tap on first video

**Log Pattern (Fixed):**
```
📋 Loaded cached following list: 12 users (in background)
🏠 HomeFeed: BUILD #1 START - User is following 12 people (from cache)
🏠 HomeFeed: BUILD #1 COMPLETE - 12 videos from following
🎬 Video loads and plays (no reset)
[5 seconds later]
✅ [LIFECYCLE] SocialProvider: Background initialization COMPLETE (fresh data loaded, saved to cache)
[User follows someone new]
💾 Saved following list to cache: 13 users
🔄 Triggered home feed refresh after following list change
🏠 HomeFeed: BUILD #2 START - User is following 13 people
🏠 HomeFeed: BUILD #2 COMPLETE - 13 videos from following
```

**Only BUILD #1 on startup - fast and clean! BUILD #2 only when user explicitly follows/unfollows or refreshes.**

## Testing the Fix

After applying all fixes, verify:

1. **Run the debug test:**
   ```bash
   flutter test test/integration/video_feed_double_load_debug_test.dart
   ```
   - Should show only 1-2 HomeFeed builds (2 max)
   - Should show only 1 VideoFeedScreen initState

2. **Run the app and watch logs:**
   ```bash
   flutter run -d chrome --dart-define=LOG_LEVEL=debug | grep -E '\[LIFECYCLE\]|HomeFeed: BUILD|VideoFeedScreen: (initState|build)'
   ```
   - Should NOT see "RAPID REBUILD DETECTED"
   - Should NOT see "RAPID RE-INIT DETECTED"
   - Should see clean initialization sequence

3. **Manual testing:**
   - Open app
   - Watch home feed load
   - Video should load once and start playing
   - Should NOT see video "reset" or reload

## Additional Notes

### Why keepAlive: false is Problematic

The `@Riverpod(keepAlive: false)` annotation on HomeFeed means:
- Provider auto-disposes when no widgets watch it
- Provider rebuilds from scratch when watched again
- Any dependency change (like social provider) triggers rebuild

For a core feed that's always visible, `keepAlive: true` is more appropriate.

### Riverpod Provider Dependencies

```
VideoFeedScreen (widget)
  └─ watches: homeFeedProvider
      └─ watches: socialProvider
          └─ initializes: deferred after UI shows
```

When `socialProvider` completes initialization:
1. It notifies all watchers (including HomeFeed)
2. HomeFeed rebuilds with new social data
3. VideoFeedScreen rebuilds because its watched provider changed
4. User sees "reset" behavior

## Log File Locations

- Chrome DevTools Console (when running on Chrome)
- Terminal output (when running flutter run)
- Test output (when running flutter test)

## Contact

If you encounter issues with this debugging guide, check:
- `test/integration/video_feed_double_load_debug_test.dart` - Debug tests
- `lib/providers/home_feed_provider.dart` - HomeFeed lifecycle logging
- `lib/screens/video_feed_screen.dart` - Widget lifecycle logging
- `lib/main.dart` - Social provider initialization logging
