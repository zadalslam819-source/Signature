# Video Cache Optimization Plan

## Problem Statement

Cached videos are not being used for playback:
- Videos take 14+ seconds to load even when already cached
- 1GB cache is wasted - all videos stream from network every time
- Poor user experience on app restart (slow loading)
- Wasted bandwidth re-downloading previously cached videos
- Battery drain from network streaming instead of file I/O

## Root Cause Analysis

### Current Architecture Issues

1. **IndividualVideoController** (`lib/providers/individual_video_providers.dart:120-122`)
   - Creates `VideoPlayerController.networkUrl()` with remote URL
   - **BUG:** Completely bypasses the cache
   - **BUG:** Controller never checks if video is cached locally
   - **RESULT:** Always streams from network, even when cached

2. **Background Caching** (`lib/providers/individual_video_providers.dart:124-142`)
   - Downloads video to cache in background (fire-and-forget)
   - **BUG:** Controller doesn't use the cached file, even after download completes
   - **RESULT:** Videos get cached but never used for playback

3. **VideoCacheManager** (`lib/services/video_cache_manager.dart`)
   - Has `getCachedVideo()` method that returns cached files
   - **BUG:** Method is async, can't be called from synchronous provider
   - **BUG:** No synchronous cache lookup available
   - **RESULT:** Provider can't check cache before creating controller

4. **No Cache State Tracking**
   - No in-memory index of which videos are cached
   - **BUG:** Every cache check requires async disk I/O
   - **RESULT:** Can't synchronously determine if video is cached

## Solution: Video File Resolver Pattern

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  IndividualVideoController Provider                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ 1. Calls VideoFileResolver.resolveVideoSource()      │  │
│  │ 2. Gets VideoSource (cached file OR network URL)     │  │
│  │ 3. Creates appropriate VideoPlayerController         │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  VideoFileResolver (NEW)                                     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ • Maintains in-memory cache index                     │  │
│  │ • Synchronous cache lookup                            │  │
│  │ • Returns VideoSource (file or network)               │  │
│  │ • Triggers background caching if not cached           │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  VideoCacheManager (ENHANCED)                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ • Added: getCachedFilePathSync()                      │  │
│  │ • Added: In-memory cache index (_cacheIndex)          │  │
│  │ • Enhanced: cacheVideo() updates index                │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Test-Driven Development Plan

### Phase 1: VideoCacheManager Sync Lookup Tests

#### Test 1.1: Cache index tracks cached videos
```dart
test('Cache index updated when video cached', () async {
  final cacheManager = VideoCacheManager();

  // Cache a video
  await cacheManager.cacheVideo(testUrl, testVideoId);

  // Check index
  expect(cacheManager.isCachedSync(testVideoId), true);
});
```

#### Test 1.2: Sync lookup returns null for uncached video
```dart
test('Sync lookup returns null for uncached video', () {
  final cacheManager = VideoCacheManager();

  final file = cacheManager.getCachedFilePathSync('nonexistent_id');

  expect(file, null);
});
```

#### Test 1.3: Sync lookup returns file for cached video
```dart
test('Sync lookup returns file path for cached video', () async {
  final cacheManager = VideoCacheManager();

  await cacheManager.cacheVideo(testUrl, testVideoId);
  final file = cacheManager.getCachedFilePathSync(testVideoId);

  expect(file, isNotNull);
  expect(file!.existsSync(), true);
});
```

#### Test 1.4: Cache index persists across sessions
```dart
test('Cache index loaded from disk on startup', () async {
  // Cache a video
  final cacheManager1 = VideoCacheManager();
  await cacheManager1.cacheVideo(testUrl, testVideoId);

  // Create new instance (simulates app restart)
  final cacheManager2 = VideoCacheManager();
  await cacheManager2.initialize(); // Load index from disk

  expect(cacheManager2.isCachedSync(testVideoId), true);
});
```

### Phase 2: VideoFileResolver Tests

#### Test 2.1: Resolver returns cached file when available
```dart
test('VideoFileResolver returns cached file when available', () async {
  final cacheManager = VideoCacheManager();
  await cacheManager.cacheVideo(testUrl, testVideoId);

  final resolver = VideoFileResolver(cacheManager);
  final source = resolver.resolveVideoSource(testVideoId, testUrl);

  expect(source.isFromCache, true);
  expect(source.file, isNotNull);
  expect(source.url, null);
});
```

#### Test 2.2: Resolver returns network URL when not cached
```dart
test('VideoFileResolver returns network URL when not cached', () {
  final cacheManager = VideoCacheManager();
  final resolver = VideoFileResolver(cacheManager);

  final source = resolver.resolveVideoSource(testVideoId, testUrl);

  expect(source.isFromCache, false);
  expect(source.file, null);
  expect(source.url, testUrl);
});
```

#### Test 2.3: Resolver triggers background caching for uncached videos
```dart
test('VideoFileResolver triggers background caching for uncached videos', () async {
  final cacheManager = VideoCacheManager();
  final resolver = VideoFileResolver(cacheManager);

  // Resolve uncached video
  final source = resolver.resolveVideoSource(testVideoId, testUrl);
  expect(source.isFromCache, false);

  // Wait for background caching
  await Future.delayed(Duration(milliseconds: 100));

  // Check cache was started
  expect(cacheManager.isCachedSync(testVideoId), true);
});
```

#### Test 2.4: VideoSource creates correct controller type
```dart
test('VideoSource.file creates file controller', () {
  final file = File('/path/to/video.mp4');
  final source = VideoSource.file(file);

  final controller = source.createController();

  expect(controller.dataSource, file.path);
  expect(controller.dataSourceType, DataSourceType.file);
});
```

```dart
test('VideoSource.network creates network controller', () {
  final source = VideoSource.network(testUrl);

  final controller = source.createController();

  expect(controller.dataSource, testUrl);
  expect(controller.dataSourceType, DataSourceType.network);
});
```

### Phase 3: IndividualVideoController Integration Tests

#### Test 3.1: Controller uses cached file when available
```dart
testWidgets('IndividualVideoController uses cached file', (tester) async {
  // Pre-cache video
  final cacheManager = VideoCacheManager();
  await cacheManager.cacheVideo(testUrl, testVideoId);

  final container = ProviderContainer(
    overrides: [
      videoCacheManagerProvider.overrideWithValue(cacheManager),
    ],
  );

  final params = VideoControllerParams(
    videoId: testVideoId,
    videoUrl: testUrl,
  );

  final controller = container.read(individualVideoControllerProvider(params));

  expect(controller.dataSourceType, DataSourceType.file);
});
```

#### Test 3.2: Controller uses network URL when not cached
```dart
testWidgets('IndividualVideoController uses network when not cached', (tester) async {
  final container = ProviderContainer();

  final params = VideoControllerParams(
    videoId: testVideoId,
    videoUrl: testUrl,
  );

  final controller = container.read(individualVideoControllerProvider(params));

  expect(controller.dataSourceType, DataSourceType.network);
});
```

#### Test 3.3: Cached video initializes faster than network video
```dart
testWidgets('Cached video initializes faster than network video', (tester) async {
  // Cache video
  final cacheManager = VideoCacheManager();
  await cacheManager.cacheVideo(testUrl, testVideoId);

  final container = ProviderContainer(
    overrides: [videoCacheManagerProvider.overrideWithValue(cacheManager)],
  );

  final params = VideoControllerParams(
    videoId: testVideoId,
    videoUrl: testUrl,
  );

  final stopwatch = Stopwatch()..start();
  final controller = container.read(individualVideoControllerProvider(params));
  await controller.initialize();
  stopwatch.stop();

  // Cached file should initialize in <500ms
  expect(stopwatch.elapsedMilliseconds, lessThan(500));
});
```

### Phase 4: End-to-End Tests

#### Test 4.1: Full flow - uncached to cached
```dart
testWidgets('Video streams first time, uses cache second time', (tester) async {
  final container = ProviderContainer();

  // First play - not cached
  final params1 = VideoControllerParams(
    videoId: testVideoId,
    videoUrl: testUrl,
  );
  final controller1 = container.read(individualVideoControllerProvider(params1));
  expect(controller1.dataSourceType, DataSourceType.network);

  // Wait for caching to complete
  await Future.delayed(Duration(seconds: 2));

  // Dispose first controller
  container.invalidate(individualVideoControllerProvider(params1));

  // Second play - should be cached
  final params2 = VideoControllerParams(
    videoId: testVideoId,
    videoUrl: testUrl,
  );
  final controller2 = container.read(individualVideoControllerProvider(params2));
  expect(controller2.dataSourceType, DataSourceType.file);
});
```

#### Test 4.2: Cache persists across app restart
```dart
testWidgets('Cache persists across app restart', (tester) async {
  // Session 1: Cache video
  final container1 = ProviderContainer();
  final params = VideoControllerParams(
    videoId: testVideoId,
    videoUrl: testUrl,
  );

  container1.read(individualVideoControllerProvider(params));
  await Future.delayed(Duration(seconds: 2)); // Wait for caching

  // Simulate app restart
  container1.dispose();

  // Session 2: New container, same video
  final container2 = ProviderContainer();
  final controller2 = container2.read(individualVideoControllerProvider(params));

  expect(controller2.dataSourceType, DataSourceType.file);
});
```

## Implementation Plan

### Step 1: Add In-Memory Cache Index to VideoCacheManager

**File:** `lib/services/video_cache_manager.dart`

**Add state:**
```dart
class VideoCacheManager extends CacheManager {
  // ... existing code ...

  // In-memory cache index for fast sync lookups
  final Map<String, String> _cacheIndex = {}; // videoId -> file path
  bool _indexLoaded = false;

  factory VideoCacheManager() {
    return _instance ??= VideoCacheManager._();
  }

  VideoCacheManager._() : super(/* ... */) {
    // Load cache index on startup
    _loadCacheIndex();
  }
}
```

**Add methods:**
```dart
/// Load cache index from disk on startup
Future<void> _loadCacheIndex() async {
  if (_indexLoaded) return;

  try {
    // Get all cached files from flutter_cache_manager
    // This is async but only runs once on startup
    final cacheDir = await getTemporaryDirectory();
    final cacheFiles = cacheDir.listSync(recursive: true);

    for (final file in cacheFiles) {
      if (file is File) {
        // Extract videoId from filename/metadata
        final videoId = _extractVideoIdFromPath(file.path);
        if (videoId != null) {
          _cacheIndex[videoId] = file.path;
        }
      }
    }

    _indexLoaded = true;
    Log.info('📊 Loaded cache index: ${_cacheIndex.length} videos cached');
  } catch (error) {
    Log.error('❌ Failed to load cache index: $error');
  }
}

/// Check if video is cached (synchronous)
bool isCachedSync(String videoId) {
  return _cacheIndex.containsKey(videoId);
}

/// Get cached file path synchronously
File? getCachedFilePathSync(String videoId) {
  final path = _cacheIndex[videoId];
  if (path == null) return null;

  final file = File(path);
  if (!file.existsSync()) {
    // File was deleted externally - remove from index
    _cacheIndex.remove(videoId);
    return null;
  }

  return file;
}

/// Update cacheVideo to maintain index
@override
Future<File?> cacheVideo(String videoUrl, String videoId, {BrokenVideoTracker? brokenVideoTracker}) async {
  final file = await super.cacheVideo(videoUrl, videoId, brokenVideoTracker: brokenVideoTracker);

  if (file != null) {
    // Update index
    _cacheIndex[videoId] = file.path;
    Log.debug('📊 Updated cache index: $videoId -> ${file.path}');
  }

  return file;
}
```

### Step 2: Create VideoSource Class

**File:** `lib/models/video_source.dart` (NEW)

```dart
// ABOUTME: Represents a video source - either cached file or network URL
// ABOUTME: Encapsulates logic for creating appropriate VideoPlayerController

import 'dart:io';
import 'package:video_player/video_player.dart';

/// Video source that can be either a cached file or network URL
class VideoSource {
  final File? file;
  final String? url;
  final bool isFromCache;

  const VideoSource._({
    required this.file,
    required this.url,
    required this.isFromCache,
  });

  /// Create source from cached file
  factory VideoSource.file(File file) {
    return VideoSource._(
      file: file,
      url: null,
      isFromCache: true,
    );
  }

  /// Create source from network URL
  factory VideoSource.network(String url) {
    return VideoSource._(
      file: null,
      url: url,
      isFromCache: false,
    );
  }

  /// Create appropriate VideoPlayerController for this source
  VideoPlayerController createController() {
    if (isFromCache && file != null) {
      return VideoPlayerController.file(file!);
    } else if (!isFromCache && url != null) {
      return VideoPlayerController.networkUrl(Uri.parse(url!));
    } else {
      throw StateError('Invalid VideoSource state');
    }
  }

  @override
  String toString() => 'VideoSource(isFromCache: $isFromCache, ${isFromCache ? 'file: ${file?.path}' : 'url: $url'})';
}
```

### Step 3: Create VideoFileResolver

**File:** `lib/services/video_file_resolver.dart` (NEW)

```dart
// ABOUTME: Resolves video sources by checking cache first, then falling back to network
// ABOUTME: Provides synchronous video source resolution with automatic background caching

import 'dart:io';
import 'package:openvine/services/video_cache_manager.dart';
import 'package:openvine/models/video_source.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Resolves video sources from cache or network
class VideoFileResolver {
  final VideoCacheManager _cacheManager;

  const VideoFileResolver(this._cacheManager);

  /// Resolve video source - cached file if available, otherwise network URL
  /// This is SYNCHRONOUS and returns immediately
  VideoSource resolveVideoSource(String videoId, String videoUrl) {
    // Check cache synchronously via in-memory index
    final cachedFile = _cacheManager.getCachedFilePathSync(videoId);

    if (cachedFile != null) {
      Log.info('🎯 Using cached file for ${videoId.substring(0, 8)}...',
          name: 'VideoFileResolver', category: LogCategory.video);
      return VideoSource.file(cachedFile);
    } else {
      Log.info('🌐 Using network URL for ${videoId.substring(0, 8)}..., will cache in background',
          name: 'VideoFileResolver', category: LogCategory.video);

      // Start background caching (fire-and-forget)
      _cacheManager.cacheVideo(videoUrl, videoId).catchError((error) {
        Log.warning('⚠️ Background caching failed for ${videoId.substring(0, 8)}: $error',
            name: 'VideoFileResolver', category: LogCategory.video);
        return null;
      });

      return VideoSource.network(videoUrl);
    }
  }
}
```

**Add provider:**

**File:** `lib/providers/app_providers.dart`

```dart
/// Provider for video file resolver
final videoFileResolverProvider = Provider<VideoFileResolver>((ref) {
  final cacheManager = openVineVideoCache; // Use singleton
  return VideoFileResolver(cacheManager);
});
```

### Step 4: Update IndividualVideoController to Use Resolver

**File:** `lib/providers/individual_video_providers.dart`

**Replace controller creation:**
```dart
@riverpod
VideoPlayerController individualVideoController(
  Ref ref,
  VideoControllerParams params,
) {
  // ... keepAlive and lifecycle code ...

  Log.info('🎬 Creating VideoPlayerController for video ${params.videoId.substring(0, 8)}...');

  // Use resolver to get cached file or network URL
  final resolver = ref.read(videoFileResolverProvider);
  final source = resolver.resolveVideoSource(params.videoId, params.videoUrl);

  // Create appropriate controller (file or network)
  final controller = source.createController();

  if (source.isFromCache) {
    Log.info('✨ Controller created from cached file (instant load)');
  } else {
    Log.info('🌐 Controller created from network (will stream)');
  }

  // ... rest of initialization and lifecycle code ...

  return controller;
}
```

**Remove old background caching:**
```dart
// DELETE this entire block - resolver handles caching now
// Cache video in background for future use (non-blocking)
// Use unawaited to explicitly mark as fire-and-forget
// final videoCache = openVineVideoCache;
// unawaited(...);
```

### Step 5: Update VideoCacheManager.cacheVideo() to Update Index

**File:** `lib/services/video_cache_manager.dart`

**Enhance cacheVideo:**
```dart
Future<File?> cacheVideo(String videoUrl, String videoId, {BrokenVideoTracker? brokenVideoTracker}) async {
  try {
    // Check if already cached first - avoid redundant downloads
    final cachedFile = getCachedFilePathSync(videoId);
    if (cachedFile != null) {
      Log.debug('⏭️ Video ${videoId.substring(0, 8)}... already cached, skipping download');
      return cachedFile;
    }

    Log.info('🎬 Caching video ${videoId.substring(0, 8)}... from $videoUrl');

    final fileInfo = await downloadFile(
      videoUrl,
      key: videoId,
      authHeaders: {},
    );

    // Update cache index
    _cacheIndex[videoId] = fileInfo.file.path;

    Log.info('✅ Video ${videoId.substring(0, 8)}... cached successfully at ${fileInfo.file.path}');

    return fileInfo.file;
  } catch (error) {
    // ... error handling ...
  }
}
```

## Testing Strategy

### Unit Tests
- `test/services/video_cache_manager_sync_test.dart` - Test cache index and sync lookups
- `test/services/video_file_resolver_test.dart` - Test resolver logic
- `test/models/video_source_test.dart` - Test VideoSource controller creation

### Integration Tests
- `test/providers/individual_video_controller_cache_test.dart` - Test provider uses cache
- `test/integration/video_cache_persistence_test.dart` - Test cache across sessions

### Manual Testing
1. Clear app data
2. Open app, play video - should stream from network (14+ seconds)
3. Close app completely
4. Reopen app, play same video - should load from cache (<500ms)
5. Verify logs show "🎯 Using cached file" message

## Success Criteria

1. ✅ Cached videos load in <500ms (vs 14+ seconds)
2. ✅ First video on app startup uses cache if available
3. ✅ Cache persists across app restarts
4. ✅ Uncached videos still stream correctly
5. ✅ Background caching still works for new videos
6. ✅ Cache index loaded efficiently on startup (<100ms)
7. ✅ Logs clearly show "cached file" vs "network URL" source

## Performance Impact

### Before
- First video load: 14+ seconds (network stream)
- Subsequent plays: 14+ seconds (always re-streams)
- Bandwidth: Full video download every time
- Cache: Populated but never used

### After
- First video load (cached): <500ms (local file)
- First video load (uncached): 14+ seconds (network stream, then cached)
- Subsequent plays: <500ms (local file)
- Bandwidth: Download once, reuse forever (up to 30 days)
- Cache: Actively used for all playback

## Files to Create

1. `lib/models/video_source.dart` - NEW
2. `lib/services/video_file_resolver.dart` - NEW
3. `test/services/video_cache_manager_sync_test.dart` - NEW
4. `test/services/video_file_resolver_test.dart` - NEW
5. `test/models/video_source_test.dart` - NEW
6. `test/providers/individual_video_controller_cache_test.dart` - NEW
7. `test/integration/video_cache_persistence_test.dart` - NEW

## Files to Modify

1. `lib/services/video_cache_manager.dart` - Add cache index
2. `lib/providers/individual_video_providers.dart` - Use resolver
3. `lib/providers/app_providers.dart` - Add resolver provider

## Estimated Effort

- **Test Writing:** 4-5 hours (7 test files)
- **Implementation:** 3-4 hours (3 new files, 3 modified files)
- **Manual Testing:** 1 hour (verify cache behavior)
- **Total:** ~8-10 hours

## Dependencies

- No new dependencies required
- Uses existing `video_player` and `flutter_cache_manager`
- All changes are additive (no breaking changes)

## Rollback Plan

If issues arise:
1. Revert `individual_video_providers.dart` to use `VideoPlayerController.networkUrl()` directly
2. Remove `VideoFileResolver` and `VideoSource` classes
3. App returns to current behavior (always streams, but no crashes)

## Migration Path

This change is **backwards compatible**:
- Existing cache continues to work
- Cache index built on first startup (one-time cost)
- Provider signature unchanged (still returns `VideoPlayerController`)
- Widget code unchanged (no API changes)

## Future Enhancements

After this is stable:
1. Add cache warming strategies (preload popular videos)
2. Add cache eviction policies (LRU, size-based)
3. Add analytics for cache hit rate
4. Add user settings for cache size limits
