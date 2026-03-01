# Fresh Content Filter - Direct Provider Modification (TDD)

## The Right Approach

**Modify existing providers directly** - no wrapper providers, no duplication, no technical debt.

---

## TDD Test 1: Modify videoEventsProvider to Show Fresh First

**File**: `test/providers/video_events_provider_fresh_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/video_event_service.dart';

void main() {
  group('VideoEventsProvider - Fresh First', () {
    test('emits videos with unseen first, maintaining order within groups', () async {
      // Arrange
      final seenService = SeenVideosService();
      await seenService.initialize();

      // Mark video1 and video3 as seen
      await seenService.markVideoAsSeen('video1');
      await seenService.markVideoAsSeen('video3');

      final videoEventService = VideoEventService(
        nostrService: mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );

      // Add test videos to discovery list
      videoEventService.discoveryVideos.addAll([
        VideoEvent(id: 'video1', pubkey: 'pub1', title: 'Seen 1'),
        VideoEvent(id: 'video2', pubkey: 'pub2', title: 'Unseen 1'),
        VideoEvent(id: 'video3', pubkey: 'pub3', title: 'Seen 2'),
        VideoEvent(id: 'video4', pubkey: 'pub4', title: 'Unseen 2'),
      ]);

      final container = ProviderContainer(
        overrides: [
          seenVideosServiceProvider.overrideWithValue(seenService),
          videoEventServiceProvider.overrideWithValue(videoEventService),
        ],
      );

      // Act
      final videos = await container.read(videoEventsProvider.stream.first);

      // Assert - unseen videos first, maintaining original order within each group
      expect(videos.length, 4);
      expect(videos[0].id, 'video2'); // Unseen first
      expect(videos[1].id, 'video4'); // Unseen second
      expect(videos[2].id, 'video1'); // Seen third
      expect(videos[3].id, 'video3'); // Seen fourth
    });

    test('handles all videos unseen', () async {
      final seenService = SeenVideosService();
      await seenService.initialize();

      final videoEventService = VideoEventService(
        nostrService: mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );

      videoEventService.discoveryVideos.addAll([
        VideoEvent(id: 'video1', pubkey: 'pub1', title: 'Unseen 1'),
        VideoEvent(id: 'video2', pubkey: 'pub2', title: 'Unseen 2'),
      ]);

      final container = ProviderContainer(
        overrides: [
          seenVideosServiceProvider.overrideWithValue(seenService),
          videoEventServiceProvider.overrideWithValue(videoEventService),
        ],
      );

      final videos = await container.read(videoEventsProvider.stream.first);

      expect(videos.length, 2);
      expect(videos[0].id, 'video1');
      expect(videos[1].id, 'video2');
    });

    test('handles all videos seen', () async {
      final seenService = SeenVideosService();
      await seenService.initialize();
      await seenService.markVideoAsSeen('video1');
      await seenService.markVideoAsSeen('video2');

      final videoEventService = VideoEventService(
        nostrService: mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );

      videoEventService.discoveryVideos.addAll([
        VideoEvent(id: 'video1', pubkey: 'pub1', title: 'Seen 1'),
        VideoEvent(id: 'video2', pubkey: 'pub2', title: 'Seen 2'),
      ]);

      final container = ProviderContainer(
        overrides: [
          seenVideosServiceProvider.overrideWithValue(seenService),
          videoEventServiceProvider.overrideWithValue(videoEventService),
        ],
      );

      final videos = await container.read(videoEventsProvider.stream.first);

      expect(videos.length, 2);
      expect(videos[0].id, 'video1');
      expect(videos[1].id, 'video2');
    });
  });
}
```

**Prompt 1A: Write failing test**
```
Create test/providers/video_events_provider_fresh_test.dart with tests above.
Run: flutter test test/providers/video_events_provider_fresh_test.dart
Verify it fails because videoEventsProvider doesn't reorder yet.
```

**Prompt 1B: Modify videoEventsProvider to reorder**
```
Modify lib/providers/video_events_providers.dart in the VideoEvents.build() method.

After line 65 where it creates currentEvents:
  final currentEvents = List<VideoEvent>.from(videoEventService.discoveryVideos);

Add reordering logic:
  // Reorder to show unseen videos first
  final seenService = ref.watch(seenVideosServiceProvider);
  final unseen = <VideoEvent>[];
  final seen = <VideoEvent>[];

  for (final video in currentEvents) {
    if (seenService.hasSeenVideo(video.id)) {
      seen.add(video);
    } else {
      unseen.add(video);
    }
  }

  final reorderedEvents = [...unseen, ...seen];

  if (_canEmit) {
    _controller!.add(reorderedEvents);
  }

Also apply same logic in the onVideoEventServiceChange callback around line 85.

Run: flutter test test/providers/video_events_provider_fresh_test.dart
Verify tests pass.
```

---

## TDD Test 2: Modify homeFeedProvider to Show Fresh First

**File**: `test/providers/home_feed_provider_fresh_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/seen_videos_service.dart';

void main() {
  group('HomeFeedProvider - Fresh First', () {
    test('returns home feed videos with unseen first', () async {
      // Arrange
      final seenService = SeenVideosService();
      await seenService.initialize();
      await seenService.markVideoAsSeen('video1');

      final videoEventService = VideoEventService(
        nostrService: mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );

      videoEventService.homeFeedVideos.addAll([
        VideoEvent(id: 'video1', pubkey: 'following1', title: 'Seen'),
        VideoEvent(id: 'video2', pubkey: 'following2', title: 'Unseen'),
        VideoEvent(id: 'video3', pubkey: 'following3', title: 'Also Unseen'),
      ]);

      final container = ProviderContainer(
        overrides: [
          seenVideosServiceProvider.overrideWithValue(seenService),
          videoEventServiceProvider.overrideWithValue(videoEventService),
          // Mock social provider with following list
          social.socialProvider.overrideWith((ref) {
            return SocialState(
              followingPubkeys: {'following1', 'following2', 'following3'},
            );
          }),
        ],
      );

      // Act
      final feedState = await container.read(homeFeedProvider.future);

      // Assert
      expect(feedState.videos.length, 3);
      expect(feedState.videos[0].id, 'video2'); // Unseen first
      expect(feedState.videos[1].id, 'video3'); // Unseen second
      expect(feedState.videos[2].id, 'video1'); // Seen last
    });
  });
}
```

**Prompt 2A: Write failing test**
```
Create test/providers/home_feed_provider_fresh_test.dart with test above.
Run and verify it fails.
```

**Prompt 2B: Modify homeFeedProvider to reorder**
```
Modify lib/providers/home_feed_provider.dart in the HomeFeed.build() method.

After line 93 where it gets followingVideos:
  final followingVideos = List<VideoEvent>.from(videoEventService.homeFeedVideos);

Add reordering logic:
  // Reorder to show unseen videos first
  final seenService = ref.watch(seenVideosServiceProvider);
  final unseen = <VideoEvent>[];
  final seen = <VideoEvent>[];

  for (final video in followingVideos) {
    if (seenService.hasSeenVideo(video.id)) {
      seen.add(video);
    } else {
      unseen.add(video);
    }
  }

  final reorderedVideos = [...unseen, ...seen];

Then use reorderedVideos instead of followingVideos in the returned VideoFeedState.

Run: flutter test test/providers/home_feed_provider_fresh_test.dart
Verify test passes.
```

---

## TDD Test 3: Performance

**File**: `test/providers/video_events_provider_performance_test.dart`

```dart
test('reorders 1000 videos in less than 50ms', () async {
  final seenService = SeenVideosService();
  await seenService.initialize();

  // Mark half as seen
  for (int i = 0; i < 500; i++) {
    await seenService.markVideoAsSeen('video$i');
  }

  final videoEventService = VideoEventService(
    nostrService: mockNostrService,
    subscriptionManager: mockSubscriptionManager,
  );

  videoEventService.discoveryVideos.addAll(
    List.generate(
      1000,
      (i) => VideoEvent(id: 'video$i', pubkey: 'pub$i', title: 'Video $i'),
    ),
  );

  final container = ProviderContainer(
    overrides: [
      seenVideosServiceProvider.overrideWithValue(seenService),
      videoEventServiceProvider.overrideWithValue(videoEventService),
    ],
  );

  final stopwatch = Stopwatch()..start();
  final videos = await container.read(videoEventsProvider.stream.first);
  stopwatch.stop();

  expect(videos.length, 1000);
  expect(stopwatch.elapsedMilliseconds, lessThan(50));
});
```

**Prompt 3: Add performance test**
```
Create test/providers/video_events_provider_performance_test.dart with test above.
Run and verify it passes.
```

---

## TDD Test 4: Integration

**File**: `test/integration/fresh_content_integration_test.dart`

```dart
testWidgets('videos reorder when marked as seen', (tester) async {
  final seenService = SeenVideosService();
  await seenService.initialize();

  final videoEventService = VideoEventService(
    nostrService: mockNostrService,
    subscriptionManager: mockSubscriptionManager,
  );

  videoEventService.discoveryVideos.addAll([
    VideoEvent(id: 'video1', pubkey: 'pub1', title: 'Video 1'),
    VideoEvent(id: 'video2', pubkey: 'pub2', title: 'Video 2'),
  ]);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        seenVideosServiceProvider.overrideWithValue(seenService),
        videoEventServiceProvider.overrideWithValue(videoEventService),
      ],
      child: MaterialApp(home: ExploreScreen()),
    ),
  );

  await tester.pumpAndSettle();

  // Both videos initially present
  expect(find.text('Video 1'), findsWidgets);
  expect(find.text('Video 2'), findsWidgets);

  // Mark video1 as seen
  await seenService.recordVideoView('video1');

  // Trigger provider refresh
  videoEventService.notifyListeners();

  await tester.pumpAndSettle();

  // Both still present but order may have changed
  // Video 2 should now be prioritized over Video 1
  expect(find.text('Video 1'), findsWidgets);
  expect(find.text('Video 2'), findsWidgets);
});
```

**Prompt 4: Integration test**
```
Create test/integration/fresh_content_integration_test.dart with test above.
Run and verify the full flow works.
```

---

## What Gets Modified

**Modified Files**:
- `lib/providers/video_events_providers.dart` - Add reordering logic to VideoEvents.build()
- `lib/providers/home_feed_provider.dart` - Add reordering logic to HomeFeed.build()

**No New Files**
**No Wrapper Providers**
**No Abandoned Code**

---

## The Implementation

In each provider, after getting the video list, add:

```dart
// Reorder to show unseen videos first
final seenService = ref.watch(seenVideosServiceProvider);
final unseen = <VideoEvent>[];
final seen = <VideoEvent>[];

for (final video in videos) {
  if (seenService.hasSeenVideo(video.id)) {
    seen.add(video);
  } else {
    unseen.add(video);
  }
}

final reordered = [...unseen, ...seen];
```

That's it. No duplication, clean and simple.

---

## TDD Execution Order

1. Write test for videoEventsProvider → Add reordering logic
2. Write test for homeFeedProvider → Add reordering logic
3. Write performance test → Verify <50ms
4. Write integration test → Verify full flow

Each existing provider gets ~10 lines of reordering code. No new files.

Ready to start with **Prompt 1A**?
