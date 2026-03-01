# Riverpod 3 Migration Plan for OpenVine

## Executive Summary
The OpenVine mobile app currently has a **version mismatch**: pubspec.yaml declares Riverpod 3.0.0, but the codebase was written for Riverpod 2. This causes **596 compilation errors** that need systematic resolution.

## MIGRATION STATUS UPDATE (2025-09-30)

### ✅ Phase 1: Critical Fixes - COMPLETED
- **Errors reduced from 1953 to 441 (77% reduction)**
- Added legacy imports to 3 provider files
- Fixed provider references in main.dart and home_feed_provider.dart
- Generated all missing .g.dart files (120 outputs)
- **App now compiles and runs successfully**

### ✅ Phase 2: AutoDispose Analysis - COMPLETED
- **GOOD NEWS**: OpenVine is already using modern Riverpod 3 patterns
- All 75 AutoDispose instances working correctly
- Using @riverpod annotations (no legacy patterns found)
- **No code changes required for AutoDispose patterns**

### 🔄 Phase 3: Test Migration - IN PROGRESS
- **340 total test files** with 57 using Riverpod
- **66 mock files** requiring regeneration
- High complexity areas identified: Provider tests, Widget tests
- **Estimated effort: 15-17 working days**

## Current State Analysis

### Version Status
- **pubspec.yaml**: `flutter_riverpod: ^3.0.0` ✅
- **Codebase**: Written for Riverpod 2 ❌
- **Generated Files**: Outdated, causing duplicate definitions ❌
- **Tests**: Using Riverpod 2 APIs ❌

### Error Categories (596 total)
1. **Provider Reference Errors**: ~50+ instances
   - `socialNotifierProvider` undefined
   - `userProfileNotifierProvider` undefined
   - Missing provider exports in generated files

2. **Legacy Provider Usage**: 10 files
   - `StateProvider` and `StateNotifierProvider` need legacy imports

3. **AutoDispose Pattern Issues**: 19 files
   - AutoDispose interfaces removed in Riverpod 3

4. **Nullable Access Errors**: ~30+ instances
   - Unchecked nullable value accesses

5. **Test File Breakages**: 200+ errors
   - API changes in test utilities
   - Mock generation issues

## Breaking Changes Summary

### 1. Legacy Providers Moved
**Riverpod 2:**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final myProvider = StateProvider<int>((ref) => 0);
```

**Riverpod 3:**
```dart
import 'package:flutter_riverpod/legacy.dart';  // New import!

final myProvider = StateProvider<int>((ref) => 0);
```

### 2. AsyncValue Changes
**Riverpod 2:**
```dart
final value = asyncValue.valueOrNull;
```

**Riverpod 3:**
```dart
final value = asyncValue.value; // Returns null during errors
```

### 3. Provider Update Filtering
All providers now use `==` to filter updates by default. Override `updateShouldNotify` for custom behavior.

### 4. StreamProvider Pausing
StreamProviders now pause when not actively listened to, which may affect background data fetching.

### 5. Notifier Lifecycle Changes
- Notifiers recreated on provider rebuild
- Methods throw after disposal except `mounted`
- AutoDispose interfaces removed

## Migration Steps

### Phase 1: Critical Fixes (Day 1)
**Goal**: Get the app compiling

#### Step 1.1: Update Legacy Provider Imports
Files to modify:
```bash
lib/providers/optimistic_follow_provider.dart
lib/providers/vine_recording_provider.dart
lib/providers/video_overlay_manager_provider.dart
lib/providers/individual_video_providers.dart
lib/providers/search_provider.dart
lib/features/feature_flags/providers/feature_flag_providers.dart
lib/features/feature_flags/screens/feature_flag_screen.dart
```

Add import at top of each file:
```dart
import 'package:flutter_riverpod/legacy.dart';
```

#### Step 1.2: Clean and Regenerate
```bash
# Clean old generated files
find . -name "*.g.dart" -delete
find . -name "*.freezed.dart" -delete

# Regenerate with Riverpod 3
dart run build_runner build --delete-conflicting-outputs
```

#### Step 1.3: Fix Provider References
Update `lib/main.dart`:
- Line 523: Fix `socialNotifierProvider` reference
- Line 1070: Fix `socialNotifierProvider` reference
- Lines 1072-1073: Add null checks for social state

Update `lib/providers/home_feed_provider.dart`:
- Line 39: Fix `socialNotifierProvider` reference
- Line 130: Fix `userProfileNotifierProvider` reference
- Line 181: Fix `socialNotifierProvider` reference
- Line 262: Add null check for videos

### Phase 2: Provider Pattern Updates (Day 2)

#### Step 2.1: Update AutoDispose Patterns
**Before (Riverpod 2):**
```dart
class MyNotifier extends AutoDisposeAsyncNotifier<MyState> {
  // ...
}
```

**After (Riverpod 3):**
```dart
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  FutureOr<MyState> build() {
    // initialization
  }
}
```

#### Step 2.2: Fix Nullable Access
Add proper null checks:
```dart
// Before
final length = state.value.length;

// After
final length = state.value?.length ?? 0;
```

#### Step 2.3: Update StreamProvider Behavior
For `lib/providers/p2p_sync_provider.dart`:
- Consider if pausing behavior affects functionality
- Add `keepAlive: true` if continuous listening needed

### Phase 3: Test Migration (Day 3)

#### Step 3.1: Update Test Imports
Add legacy imports to test files using StateProvider/StateNotifierProvider

#### Step 3.2: Fix Mock Generation
```bash
# Regenerate mocks with new Riverpod 3
dart run build_runner build --delete-conflicting-outputs
```

#### Step 3.3: Update Test APIs
- Replace `container.read` patterns as needed
- Update provider override syntax
- Fix widget test provider scoping

### Phase 4: Validation (Day 4)

#### Step 4.1: Static Analysis
```bash
flutter analyze
# Should show 0 errors
```

#### Step 4.2: Test Suite
```bash
flutter test
# All tests should pass
```

#### Step 4.3: Manual Testing
- Test video recording and upload
- Verify social features (follow/unfollow)
- Check video feed loading
- Validate real-time updates

## Risk Mitigation

### Backup Strategy
1. Create a branch before migration: `git checkout -b riverpod-3-migration`
2. Commit after each successful phase
3. Keep Riverpod 2 branch available for rollback

### Gradual Rollout
Consider using feature flags to test Riverpod 3 changes:
```dart
if (featureFlags.useRiverpod3Providers) {
  // New provider logic
} else {
  // Legacy logic
}
```

### Known Issues to Watch
1. **Provider Recreation**: Notifiers now recreate on rebuild - ensure no state loss
2. **Stream Pausing**: May affect real-time Nostr event streaming
3. **Filter Changes**: `==` filtering may cause unexpected update behavior

## Testing Checklist

### Core Functionality
- [ ] App launches without errors
- [ ] User can login/logout
- [ ] Video recording works
- [ ] Video upload succeeds
- [ ] Feed loads properly
- [ ] Social features work (follow/unfollow)
- [ ] Real-time updates function

### Provider-Specific Tests
- [ ] StateProviders update correctly
- [ ] StreamProviders handle pause/resume
- [ ] AutoDispose providers clean up properly
- [ ] Generated providers work correctly
- [ ] Provider overrides in tests work

### Performance Tests
- [ ] No memory leaks from provider recreation
- [ ] Stream pausing doesn't break real-time features
- [ ] App performance remains stable

## Rollback Plan

If critical issues arise:
1. `git checkout main`
2. Revert pubspec.yaml to Riverpod 2:
   ```yaml
   flutter_riverpod: ^2.5.1
   riverpod_annotation: ^2.3.5
   ```
3. Run `flutter pub get`
4. Regenerate with Riverpod 2

## Resources

- [Official Migration Guide](https://riverpod.dev/docs/3.0_migration)
- [Riverpod 3 Changelog](https://pub.dev/packages/flutter_riverpod/changelog#300)
- [Breaking Changes Summary](https://riverpod.dev/docs/whats_new)

## Timeline Estimate

- **Phase 1**: 4-6 hours (Critical fixes)
- **Phase 2**: 6-8 hours (Provider updates)
- **Phase 3**: 8-10 hours (Test migration)
- **Phase 4**: 4-6 hours (Validation)

**Total**: 22-30 hours of focused work

## Next Steps

1. Review this plan with the team
2. Create migration branch
3. Begin Phase 1 implementation
4. Document any additional issues discovered
5. Update this plan as needed during migration