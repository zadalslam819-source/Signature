# Fresh Content Filter - Simple Implementation Plan (TDD)

## Core Insight

**Don't sort. Just filter.** O(n) check is fast, maintains order, preserves indices.

```dart
// Simple membership check
if (!seenVideosService.hasSeenVideo(video.id)) {
  // Show this video
}
```

## The Real Question

**Where do we apply the filter?**

### Option A: Filter in Provider (Stream Transformation)
**Pros**: Clean separation, works everywhere
**Cons**: Breaks PageView indices, need different UI for filtered view

### Option B: Filter in PageView (Skip Logic)
**Pros**: Preserves indices, works with existing PageView
**Cons**: User sees "seen" videos briefly, jumpy UX

### Option C: Separate "Fresh Feed" Mode
**Pros**: Explicit user choice, can use different UI
**Cons**: Code duplication, more complexity

---

## Recommended: Option A with New UI Component

**Strategy**: Create filtered provider + simple scrollable list (not PageView)

---

## TDD Implementation Plan

### Test 1: Filter Provider Returns Only Unseen Videos

**File**: `test/providers/unseen_videos_provider_test.dart`

```dart
test('unseenVideosProvider filters out seen videos', () async {
  // Arrange
  final seenService = SeenVideosService();
  await seenService.initialize();
  await seenService.markVideoAsSeen('video1');
  await seenService.markVideoAsSeen('video3');

  final container = ProviderContainer(
    overrides: [
      seenVideosServiceProvider.overrideWithValue(seenService),
      videoEventsProvider.overrideWith((_) => Stream.value([
        VideoEvent(id: 'video1', ...),
        VideoEvent(id: 'video2', ...),
        VideoEvent(id: 'video3', ...),
        VideoEvent(id: 'video4', ...),
      ])),
    ],
  );

  // Act
  final unseenVideos = await container.read(unseenVideoEventsProvider.future);

  // Assert
  expect(unseenVideos.length, 2);
  expect(unseenVideos[0].id, 'video2');
  expect(unseenVideos[1].id, 'video4');
});
```

**Prompt 1A: Write failing test**
```
Create test/providers/unseen_videos_provider_test.dart with the test above.
Run it and verify it fails because unseenVideoEventsProvider doesn't exist yet.
```

**Prompt 1B: Make test pass**
```
Create lib/providers/unseen_videos_provider.dart:

@riverpod
Stream<List<VideoEvent>> unseenVideoEvents(Ref ref) async* {
  final seenService = ref.watch(seenVideosServiceProvider);

  await for (final videos in ref.watch(videoEventsProvider)) {
    final unseen = videos.where((v) => !seenService.hasSeenVideo(v.id)).toList();
    yield unseen;
  }
}

Run the test again and verify it passes.
```

---

### Test 2: Filter Updates When Video Marked As Seen

```dart
test('unseenVideosProvider updates when video marked seen', () async {
  // Arrange
  final seenService = SeenVideosService();
  await seenService.initialize();

  final container = ProviderContainer(
    overrides: [
      seenVideosServiceProvider.overrideWithValue(seenService),
      videoEventsProvider.overrideWith((_) => Stream.value([
        VideoEvent(id: 'video1', ...),
        VideoEvent(id: 'video2', ...),
      ])),
    ],
  );

  // Act - Initial state
  final initialUnseen = await container.read(unseenVideoEventsProvider.future);
  expect(initialUnseen.length, 2);

  // Act - Mark one as seen
  await seenService.markVideoAsSeen('video1');

  // Wait for provider to update
  await Future.delayed(Duration(milliseconds: 600)); // Account for debounce

  final updatedUnseen = await container.read(unseenVideoEventsProvider.future);

  // Assert
  expect(updatedUnseen.length, 1);
  expect(updatedUnseen[0].id, 'video2');
});
```

**Prompt 2A: Write test**
```
Add the test above to test/providers/unseen_videos_provider_test.dart.
Run it and verify it fails (provider doesn't react to seenService changes).
```

**Prompt 2B: Make provider reactive**
```
Modify lib/providers/unseen_videos_provider.dart to listen to seenService changes:

@riverpod
class UnseenVideoEvents extends _$UnseenVideoEvents {
  @override
  Stream<List<VideoEvent>> build() {
    final seenService = ref.watch(seenVideosServiceProvider);

    // Listen to both video events AND seen videos changes
    ref.listen(seenVideosServiceProvider, (prev, next) {
      // Force re-filter when seen videos change
      ref.invalidateSelf();
    });

    return ref.watch(videoEventsProvider).asyncMap((videos) {
      return videos.where((v) => !seenService.hasSeenVideo(v.id)).toList();
    });
  }
}

Run test and verify it passes.
```

---

### Test 3: Performance - Filter 1000 Videos in <50ms

```dart
test('unseenVideosProvider filters 1000 videos quickly', () async {
  // Arrange
  final seenService = SeenVideosService();
  await seenService.initialize();

  // Mark half as seen
  for (int i = 0; i < 500; i++) {
    await seenService.markVideoAsSeen('video$i');
  }

  final largeVideoList = List.generate(1000, (i) => VideoEvent(id: 'video$i', ...));

  final container = ProviderContainer(
    overrides: [
      seenVideosServiceProvider.overrideWithValue(seenService),
      videoEventsProvider.overrideWith((_) => Stream.value(largeVideoList)),
    ],
  );

  // Act
  final stopwatch = Stopwatch()..start();
  final unseen = await container.read(unseenVideoEventsProvider.future);
  stopwatch.stop();

  // Assert
  expect(unseen.length, 500);
  expect(stopwatch.elapsedMilliseconds, lessThan(50));
});
```

**Prompt 3: Performance test**
```
Add performance test to test/providers/unseen_videos_provider_test.dart.
Run and verify it passes. If it fails, profile and optimize the filter logic.
```

---

### Test 4: UI - Fresh Feed Screen Shows Only Unseen Videos

**File**: `test/screens/fresh_feed_screen_test.dart`

```dart
testWidgets('FreshFeedScreen displays only unseen videos', (tester) async {
  // Arrange
  final seenService = SeenVideosService();
  await seenService.initialize();
  await seenService.markVideoAsSeen('video1');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        seenVideosServiceProvider.overrideWithValue(seenService),
        videoEventsProvider.overrideWith((_) => Stream.value([
          VideoEvent(id: 'video1', title: 'Seen Video'),
          VideoEvent(id: 'video2', title: 'Unseen Video'),
        ])),
      ],
      child: MaterialApp(home: FreshFeedScreen()),
    ),
  );

  await tester.pumpAndSettle();

  // Assert - Should only show video2
  expect(find.text('Unseen Video'), findsOneWidget);
  expect(find.text('Seen Video'), findsNothing);
});
```

**Prompt 4A: Write UI test**
```
Create test/screens/fresh_feed_screen_test.dart with the test above.
Run and verify it fails (FreshFeedScreen doesn't exist).
```

**Prompt 4B: Create FreshFeedScreen**
```
Create lib/screens/fresh_feed_screen.dart:

class FreshFeedScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unseenVideosAsync = ref.watch(unseenVideoEventsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Fresh Videos')),
      body: unseenVideosAsync.when(
        data: (videos) => ListView.builder(
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            return VideoThumbnailWidget(
              video: video,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExploreVideoScreenPure(
                    videos: videos,
                    startIndex: index,
                  ),
                ),
              ),
            );
          },
        ),
        loading: () => CircularProgressIndicator(),
        error: (e, st) => Text('Error: $e'),
      ),
    );
  }
}

Run test and verify it passes.
```

---

### Test 5: Integration - Marking Video as Seen Removes From Fresh Feed

```dart
testWidgets('watching video removes it from fresh feed', (tester) async {
  // Arrange
  final seenService = SeenVideosService();
  await seenService.initialize();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        seenVideosServiceProvider.overrideWithValue(seenService),
        videoEventsProvider.overrideWith((_) => Stream.value([
          VideoEvent(id: 'video1', title: 'Video 1'),
          VideoEvent(id: 'video2', title: 'Video 2'),
        ])),
      ],
      child: MaterialApp(home: FreshFeedScreen()),
    ),
  );

  await tester.pumpAndSettle();
  expect(find.text('Video 1'), findsOneWidget);

  // Act - Tap video to watch it
  await tester.tap(find.text('Video 1'));
  await tester.pumpAndSettle();

  // Simulate VideoMetricsTracker marking as seen
  await seenService.recordVideoView('video1');

  // Go back to fresh feed
  await tester.pageBack();
  await tester.pumpAndSettle();

  // Assert - Video 1 should be gone
  expect(find.text('Video 1'), findsNothing);
  expect(find.text('Video 2'), findsOneWidget);
});
```

**Prompt 5: Integration test**
```
Add integration test to test/screens/fresh_feed_screen_test.dart.
Run and verify the full flow works end-to-end.
```

---

## Summary of TDD Flow

1. ✅ Write test for filter provider
2. ✅ Implement provider to pass test
3. ✅ Write test for reactivity
4. ✅ Make provider reactive to pass test
5. ✅ Write performance test
6. ✅ Optimize if needed
7. ✅ Write UI test
8. ✅ Implement UI to pass test
9. ✅ Write integration test
10. ✅ Verify full flow

---

## What About Existing VideoFeedScreen?

**Don't modify it.** Instead:

### Add "Fresh Mode" Toggle in Main Screen

**File**: `test/screens/main_screen_fresh_toggle_test.dart`

```dart
testWidgets('main screen shows fresh feed toggle', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: MainScreen()),
    ),
  );

  // Assert - Toggle exists
  expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

  // Act - Tap toggle
  await tester.tap(find.byIcon(Icons.auto_awesome));
  await tester.pumpAndSettle();

  // Assert - Now showing FreshFeedScreen instead of VideoFeedScreen
  expect(find.byType(FreshFeedScreen), findsOneWidget);
});
```

**Prompt 6: Add toggle to MainScreen**
```
Modify lib/main.dart to:

1. Add IconButton in AppBar with Icons.auto_awesome
2. Store toggle state in provider: isFreshModeProvider
3. Show FreshFeedScreen when enabled, VideoFeedScreen when disabled
4. Save preference to SharedPreferences

Write test first, then implement.
```

---

## Performance Notes

**O(n) filter is fast:**
- 1000 videos × 1 HashMap lookup = ~1000 ops
- HashMap lookup is O(1)
- Total: O(n) ≈ 10-20ms

**No sorting needed:**
- Sorting is O(n log n) ≈ 100-200ms for 1000 videos
- We maintain chronological order from Nostr

**Debouncing:**
- Already implemented in videoEventsProvider (500ms)
- Filter happens after debounce, so max once per 500ms

---

## Why This is Better

1. **Simple** - Just filter, no complex sorting logic
2. **Fast** - O(n) membership check vs O(n log n) sort
3. **Testable** - Each piece has clear unit tests
4. **Non-breaking** - Existing VideoFeedScreen unchanged
5. **User control** - Explicit toggle, not automatic sorting
6. **TDD** - Every feature test-driven

---

## What About "Recently Seen" vs "Never Seen"?

**Keep it simple for v1:**
- If seen, skip it
- If not seen, show it

**For v2 (if needed):**
- Add duration parameter to filter
- `unseenSince(Duration(days: 7))`
- Still O(n) with timestamp comparison

---

## Questions This Answers

**Q: Does indexing prevent sorting?**
A: Yes, PageView relies on stable indices. That's why we use a separate screen with ListView instead.

**Q: Is this just a Set check?**
A: Exactly. `hasSeenVideo()` is O(1) HashMap lookup.

**Q: Is there TDD?**
A: Yes, every feature has test-first implementation order.

**Q: What about performance?**
A: Filtering 1000 videos is ~20ms. Test enforces <50ms.
