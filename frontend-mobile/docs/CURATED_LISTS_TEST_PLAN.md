# Curated Lists Test Coverage Analysis & Implementation Plan

## Executive Summary

**Current State**: Limited test coverage focused primarily on relay synchronization
**Gap Analysis**: Missing ~80% of service method tests and 100% of widget/integration workflow tests
**Priority**: HIGH - Core social feature with complex state management and Nostr integration

## User Requirements

Based on user request, tests must cover:
1. ✅ Creating lists
2. ✅ Viewing user's lists
3. ✅ Adding items to lists
4. ✅ Viewing what posts/users are on lists
5. ✅ Finding other lists containing a post/user

## Current Test Coverage Analysis

### ✅ Well-Tested: Relay Sync (Unit + Integration)

#### `test/unit/curated_list_relay_sync_test.dart` (305 lines)
**Coverage**:
- ✅ `fetchUserListsFromRelays()` - Comprehensive unit tests with mocks
- ✅ Unauthenticated state handling
- ✅ Kind 30005 subscription creation
- ✅ Event processing and parsing
- ✅ Replaceable event handling (keeps latest by d-tag)
- ✅ Prevents multiple syncs per session
- ✅ Local vs relay version conflict resolution

**Quality**: High - Well-structured with proper mocking

#### `test/integration/curated_list_relay_integration_test.dart` (259 lines)
**Coverage**:
- ✅ Relay sync without authentication
- ✅ Kind 30005 event structure validation
- ✅ Real relay connection and subscription

**Quality**: Medium - Limited scope, mostly structural validation

### ⚠️ Minimal Coverage: Widget Tests

#### `test/widgets/share_video_menu_comprehensive_test.dart`
**Coverage**: Only mocks `CuratedListService`, doesn't test list functionality
**Gap**: Widget interactions with list service are not tested

### ❌ No Coverage: Core Service Methods (38 methods, only 1 tested)

The following `CuratedListService` methods have **ZERO test coverage**:

#### Lifecycle & Initialization
- ❌ `Future<void> initialize()` - **CRITICAL**: Creates default list, syncs from relays
- ❌ `void dispose()` - Cleanup and subscription management

#### CRUD Operations
- ❌ `Future<CuratedList?> createList(String name, {String? description, List<String>? tags})` - **HIGH PRIORITY**
- ❌ `Future<bool> updateList(String listId, {String? name, String? description, List<String>? tags})` - **HIGH PRIORITY**
- ❌ `Future<bool> deleteList(String listId)` - **HIGH PRIORITY**

#### Video Management (User Requirement #3)
- ❌ `Future<bool> addVideoToList(String listId, String videoEventId)` - **CRITICAL**
- ❌ `Future<bool> removeVideoFromList(String listId, String videoEventId)` - **CRITICAL**
- ❌ `bool isVideoInList(String listId, String videoEventId)` - **HIGH PRIORITY**

#### User Management
- ❌ `Future<bool> addUserToList(String listId, String userPubkey)`
- ❌ `Future<bool> removeUserFromList(String listId, String userPubkey)`
- ❌ `bool isUserInList(String listId, String userPubkey)`

#### Query Operations (User Requirements #2, #4, #5)
- ❌ `List<CuratedList> getAllLists()` - **CRITICAL** (Req #2: "see their lists")
- ❌ `CuratedList? getListById(String listId)` - **HIGH PRIORITY**
- ❌ `List<CuratedList> getListsContainingVideo(String videoEventId)` - **CRITICAL** (Req #5: "find other lists that have this post")
- ❌ `List<CuratedList> getListsContainingUser(String userPubkey)` - **HIGH PRIORITY** (Req #5: "find other lists that have this user")
- ❌ `List<String> getVideoIdsInList(String listId)` - **CRITICAL** (Req #4: "see what posts are on their lists")
- ❌ `List<String> getUserPubkeysInList(String listId)` - **HIGH PRIORITY** (Req #4: "see what users are on their lists")
- ❌ `List<CuratedList> searchLists(String query)` - **MEDIUM PRIORITY**
- ❌ `List<CuratedList> getListsByTag(String tag)` - **MEDIUM PRIORITY**

#### Specialized List Operations
- ❌ `Future<CuratedList?> getOrCreateContactsList()` - **CRITICAL**: Nostr Kind 3 integration
- ❌ `Future<void> syncContactsListToKind3()` - **HIGH PRIORITY**: Bidirectional sync
- ❌ `Future<void> loadContactsListFromKind3()` - **HIGH PRIORITY**: Import contacts
- ❌ `Future<bool> addToMuteList(String pubkey)` - **MEDIUM PRIORITY**
- ❌ `Future<bool> removeFromMuteList(String pubkey)` - **MEDIUM PRIORITY**
- ❌ `bool isMuted(String pubkey)` - **MEDIUM PRIORITY**
- ❌ `Future<bool> addToBlockList(String pubkey)` - **MEDIUM PRIORITY**
- ❌ `Future<bool> removeFromBlockList(String pubkey)` - **MEDIUM PRIORITY**
- ❌ `bool isBlocked(String pubkey)` - **MEDIUM PRIORITY**

#### State Management
- ❌ `Stream<List<CuratedList>> get listsStream` - **HIGH PRIORITY**: Reactive state
- ❌ `int getListCount()` - **LOW PRIORITY**: Metrics
- ❌ `int getItemCountInList(String listId)` - **MEDIUM PRIORITY**: UI display

#### Persistence
- ❌ `Future<void> _saveListsToPrefs()` - **HIGH PRIORITY**: Data durability
- ❌ `Future<void> _loadListsFromPrefs()` - **HIGH PRIORITY**: Startup state
- ❌ `Future<void> clearAllLists()` - **MEDIUM PRIORITY**: Reset functionality

#### Nostr Integration
- ❌ `NostrEvent _createListEvent(CuratedList list)` - **CRITICAL**: Event structure
- ❌ `CuratedList? _parseListEvent(NostrEvent event)` - **CRITICAL**: Event parsing
- ❌ `Future<void> _publishListEvent(NostrEvent event)` - **HIGH PRIORITY**: Relay publishing

## Test Gaps by Category

### 1. Service Unit Tests (38 methods → 1 tested = 2.6% coverage)

**Critical Gaps**:
- CRUD operations (create/update/delete lists)
- Video management (add/remove/query videos in lists)
- Query operations (get lists, search, filter)
- Nostr event creation/parsing/publishing
- State persistence (SharedPreferences)
- Stream notifications (reactive state)

### 2. Widget Tests (0% coverage)

**Missing UI Components**:
- List creation dialog/screen
- List selection UI (adding video to list)
- List detail view (showing items in list)
- List search/filter UI
- List management screen (view all lists)
- Multi-list selection (find all lists with video)

### 3. Integration Tests (Limited coverage)

**Existing**: Basic relay sync with real connections
**Missing**:
- End-to-end user workflows (create → add → view → search)
- Multi-device sync scenarios
- Conflict resolution (concurrent modifications)
- Contact list (Kind 3) ↔ Curated list (Kind 30005) integration
- Cross-list operations (video appears in multiple lists)
- Performance tests (large lists, many lists)

## Required Test Scenarios (User Requirements)

### Requirement #1: Creating Lists
**Service Tests**:
- ✅ Create list with name only
- ✅ Create list with name + description
- ✅ Create list with name + tags
- ✅ Create list with all optional fields
- ✅ Publish Kind 30005 event to relay
- ✅ Generate valid d-tag identifier
- ✅ Save list to SharedPreferences
- ✅ Emit listsStream update
- ❌ Handle duplicate list names
- ❌ Handle invalid input (empty name, etc.)
- ❌ Handle relay publish failures

**Widget Tests**:
- ❌ Display create list dialog
- ❌ Validate form inputs
- ❌ Show loading state during creation
- ❌ Show success/error messages
- ❌ Close dialog on success
- ❌ Clear form on cancel

**Integration Tests**:
- ❌ Create list → Verify on relay
- ❌ Create list → Other device receives it
- ❌ Create list offline → Sync when online

### Requirement #2: Viewing User's Lists
**Service Tests**:
- ✅ `getAllLists()` returns all user lists
- ✅ `getAllLists()` returns empty list when no lists
- ✅ `getAllLists()` excludes deleted lists
- ✅ `getListCount()` returns correct count
- ✅ Lists sorted by creation date
- ✅ listsStream emits updates on changes

**Widget Tests**:
- ❌ Display empty state (no lists)
- ❌ Display list grid/list view
- ❌ Show list metadata (name, description, item count)
- ❌ Handle tap to open list detail
- ❌ Show loading state during fetch
- ❌ Show error state on fetch failure
- ❌ Pull-to-refresh functionality

**Integration Tests**:
- ❌ Fetch lists from relay on app start
- ❌ Display local lists immediately (offline-first)
- ❌ Sync updates from relay in background

### Requirement #3: Adding Items to List
**Service Tests**:
- ✅ `addVideoToList()` adds video to list
- ✅ `addVideoToList()` prevents duplicates
- ✅ `addVideoToList()` publishes updated event
- ✅ `addVideoToList()` saves to prefs
- ✅ `addVideoToList()` emits stream update
- ✅ `addUserToList()` adds user to list
- ❌ Handle adding to non-existent list
- ❌ Handle relay publish failures
- ❌ Handle offline mode (queue for later sync)

**Widget Tests**:
- ❌ Display list selection UI (ShareVideoMenu)
- ❌ Show checkmarks for lists containing video
- ❌ Toggle video in/out of list
- ❌ Show loading state during add
- ❌ Show success/error feedback
- ❌ Update UI optimistically
- ❌ Create new list from share menu

**Integration Tests**:
- ❌ Add video → Verify on relay
- ❌ Add video → Other device sees update
- ❌ Add video offline → Sync when online
- ❌ Add video to multiple lists

### Requirement #4: Viewing Posts/Users on Lists
**Service Tests**:
- ✅ `getVideoIdsInList()` returns all video IDs
- ✅ `getUserPubkeysInList()` returns all user pubkeys
- ✅ `getItemCountInList()` returns correct count
- ✅ Empty list returns empty arrays
- ✅ Non-existent list returns empty arrays

**Widget Tests**:
- ❌ Display list detail screen
- ❌ Show list metadata (name, description)
- ❌ Display video grid/list
- ❌ Display user list
- ❌ Show empty state (no items)
- ❌ Handle tap to view video
- ❌ Handle tap to view user profile
- ❌ Remove item from list (swipe to delete)
- ❌ Show item count badge

**Integration Tests**:
- ❌ Fetch list items from relay
- ❌ Display cached items immediately
- ❌ Sync item updates from relay
- ❌ Handle removed items (disappear from list)

### Requirement #5: Finding Lists Containing Post/User
**Service Tests**:
- ✅ `getListsContainingVideo()` finds all lists with video
- ✅ `getListsContainingVideo()` returns empty when not found
- ✅ `getListsContainingUser()` finds all lists with user
- ✅ Results include list metadata
- ✅ Results exclude deleted lists

**Widget Tests**:
- ❌ Display "In Lists" section on video detail
- ❌ Show list pills/chips
- ❌ Handle tap to open list
- ❌ Show count when video in many lists
- ❌ Show empty state when video in no lists

**Integration Tests**:
- ❌ Add video to list A → Video detail shows list A
- ❌ Add video to list B → Video detail shows both A and B
- ❌ Remove from list A → Video detail only shows B
- ❌ Other user adds to their list → Don't show in my video detail (privacy)

## Prioritized Implementation Plan

### Phase 1: Critical Service Tests (Week 1)
**Goal**: Cover 80% of core service methods

**Priority: CRITICAL**
1. `initialize()` - Default list creation, relay sync trigger
2. `createList()` - Basic CRUD foundation
3. `addVideoToList()` / `removeVideoFromList()` - Core functionality
4. `getAllLists()` - Essential query operation
5. `getListsContainingVideo()` - User requirement #5
6. `getVideoIdsInList()` - User requirement #4
7. `_createListEvent()` / `_parseListEvent()` - Nostr integration integrity

**Priority: HIGH**
8. `updateList()` / `deleteList()` - Complete CRUD
9. `isVideoInList()` - Query optimization
10. `getListById()` - Common lookup
11. `_publishListEvent()` - Relay publishing
12. `_saveListsToPrefs()` / `_loadListsFromPrefs()` - Persistence
13. `listsStream` - Reactive state

**Files to Create**:
- `test/services/curated_list_service_crud_test.dart` (~400 lines)
- `test/services/curated_list_service_video_management_test.dart` (~300 lines)
- `test/services/curated_list_service_query_test.dart` (~250 lines)
- `test/services/curated_list_service_nostr_events_test.dart` (~350 lines)
- `test/services/curated_list_service_persistence_test.dart` (~200 lines)

**Estimated LOC**: ~1,500 lines of test code

### Phase 2: Widget Tests (Week 2)
**Goal**: Cover all UI components for list management

**Priority: CRITICAL**
1. List selection UI (ShareVideoMenu integration)
2. List detail screen (view items in list)
3. Create list dialog

**Priority: HIGH**
4. List management screen (view all lists)
5. "In Lists" indicator on video detail

**Files to Create**:
- `test/widgets/list_selection_dialog_test.dart` (~300 lines)
- `test/widgets/list_detail_screen_test.dart` (~400 lines)
- `test/widgets/create_list_dialog_test.dart` (~250 lines)
- `test/widgets/list_management_screen_test.dart` (~350 lines)
- `test/widgets/video_in_lists_indicator_test.dart` (~150 lines)

**Estimated LOC**: ~1,450 lines of test code

### Phase 3: Integration Tests (Week 3)
**Goal**: Cover end-to-end workflows and edge cases

**Priority: CRITICAL**
1. Create list → Add video → View list → Verify on relay
2. Multi-device sync (create on device A, see on device B)
3. Offline mode → Queue operations → Sync when online

**Priority: HIGH**
4. Conflict resolution (concurrent modifications)
5. Contact list (Kind 3) ↔ Curated list sync
6. Cross-list operations (video in multiple lists)

**Priority: MEDIUM**
7. Performance tests (large lists, many lists)
8. Search and filter operations

**Files to Create**:
- `test/integration/curated_list_crud_workflow_test.dart` (~400 lines)
- `test/integration/curated_list_multi_device_sync_test.dart` (~350 lines)
- `test/integration/curated_list_offline_mode_test.dart` (~300 lines)
- `test/integration/curated_list_conflicts_test.dart` (~250 lines)
- `test/integration/curated_list_kind3_integration_test.dart` (~300 lines)

**Estimated LOC**: ~1,600 lines of test code

### Phase 4: Edge Cases & Polish (Week 4)
**Goal**: Cover edge cases, error handling, and user management

**Coverage**:
- User management (addUserToList, removeUserFromList, etc.)
- Mute/block lists
- Search and filtering
- Error handling (network failures, invalid data)
- Race conditions
- Memory leaks and cleanup

**Files to Create**:
- `test/services/curated_list_service_user_management_test.dart` (~300 lines)
- `test/services/curated_list_service_moderation_test.dart` (~200 lines)
- `test/services/curated_list_service_error_handling_test.dart` (~250 lines)

**Estimated LOC**: ~750 lines of test code

## Test Structure Recommendations

### Service Unit Tests Pattern
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([NostrService, AuthService])
void main() {
  group('CuratedListService - CRUD Operations', () {
    late CuratedListService service;
    late MockNostrService mockNostr;
    late MockAuthService mockAuth;
    late SharedPreferences prefs;

    setUp(() async {
      mockNostr = MockNostrService();
      mockAuth = MockAuthService();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      service = CuratedListService(
        nostrService: mockNostr,
        authService: mockAuth,
        prefs: prefs,
      );

      // Setup common mocks
      when(mockAuth.isAuthenticated).thenReturn(true);
      when(mockAuth.currentUser).thenReturn(/* ... */);
    });

    test('createList() creates list with valid name', () async {
      final list = await service.createList('My Videos');

      expect(list, isNotNull);
      expect(list!.name, 'My Videos');
      expect(service.getAllLists(), contains(list));
      verify(mockNostr.publishEvent(any)).called(1); // Published to relay
    });

    test('addVideoToList() adds video and publishes update', () async {
      final list = await service.createList('Test List');
      final result = await service.addVideoToList(list!.id, 'video123');

      expect(result, isTrue);
      expect(service.isVideoInList(list.id, 'video123'), isTrue);
      verify(mockNostr.publishEvent(any)).called(2); // Create + Update
    });

    // ... more tests
  });
}
```

### Widget Test Pattern
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/list_selection_dialog.dart';

@GenerateMocks([CuratedListService])
void main() {
  group('ListSelectionDialog Widget Tests', () {
    late MockCuratedListService mockService;

    setUp(() {
      mockService = MockCuratedListService();
      when(mockService.getAllLists()).thenReturn([/* test lists */]);
      when(mockService.isVideoInList(any, any)).thenReturn(false);
    });

    testWidgets('displays all user lists', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            curatedListServiceProvider.overrideWithValue(
              AsyncValue.data(mockService),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ListSelectionDialog(videoId: 'test123'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('My Videos'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
    });

    testWidgets('adds video to list on tap', (tester) async {
      when(mockService.addVideoToList(any, any))
          .thenAnswer((_) async => true);

      // ... test implementation
    });

    // ... more tests
  });
}
```

### Integration Test Pattern
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Curated Lists - End-to-End Workflow', () {
    late CuratedListService service;
    late NostrService nostrService; // Real service

    setUp(() async {
      // Setup with real services and test relays
      nostrService = NostrService(testRelayUrl: 'wss://test-relay.example.com');
      await nostrService.connect();

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      service = CuratedListService(
        nostrService: nostrService,
        authService: AuthService(), // Real auth with test keys
        prefs: prefs,
      );

      await service.initialize();
    });

    test('Create list → Add video → Verify on relay', () async {
      // Create list
      final list = await service.createList('Integration Test List');
      expect(list, isNotNull);

      // Add video
      final added = await service.addVideoToList(list!.id, 'video123');
      expect(added, isTrue);

      // Wait for relay propagation
      await Future.delayed(const Duration(seconds: 2));

      // Fetch from relay to verify
      await service.fetchUserListsFromRelays();

      // Verify video is in list
      expect(service.isVideoInList(list.id, 'video123'), isTrue);

      // Verify list exists on relay
      final lists = service.getAllLists();
      expect(lists.any((l) => l.id == list.id), isTrue);
    });

    // ... more integration tests
  });
}
```

## Coverage Metrics Goals

### Current Coverage
- Service: **2.6%** (1/38 methods)
- Widget: **0%** (0/∞ UI components)
- Integration: **10%** (basic relay sync only)

### Target Coverage (After Implementation)
- Service: **≥90%** (34/38 methods) - Exclude private helpers
- Widget: **≥80%** (all critical UI flows)
- Integration: **≥70%** (core workflows + edge cases)

### Total Test LOC Estimate
- **Phase 1** (Service): ~1,500 lines
- **Phase 2** (Widget): ~1,450 lines
- **Phase 3** (Integration): ~1,600 lines
- **Phase 4** (Edge Cases): ~750 lines
- **Total**: ~5,300 lines of test code

## Dependencies & Setup Requirements

### Test Dependencies (Already in pubspec.yaml)
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.4
  build_runner: ^2.4.8
  integration_test:
    sdk: flutter
```

### Mock Generation
All service tests require mock generation:
```bash
cd mobile
flutter pub run build_runner build --delete-conflicting-outputs
```

### Test Execution
```bash
# Run all tests
flutter test

# Run specific test suite
flutter test test/services/curated_list_service_crud_test.dart

# Run with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Risk Assessment

### High-Risk Areas (Need Immediate Testing)
1. **initialize()** - Creates default list, easy to break during refactoring
2. **Nostr event creation/parsing** - Protocol compliance required
3. **addVideoToList() / removeVideoFromList()** - Core user-facing feature
4. **Concurrent modifications** - Race conditions with relay sync
5. **Persistence layer** - Data loss risk if SharedPreferences handling broken

### Medium-Risk Areas
6. **Contact list (Kind 3) sync** - Complex bidirectional sync logic
7. **listsStream** - State management and memory leaks
8. **Conflict resolution** - Multi-device sync edge cases

### Low-Risk Areas (Can defer)
9. **Mute/block lists** - Less commonly used
10. **Search/filter** - Read-only query operations
11. **getListCount() / getItemCountInList()** - Simple getters

## Success Criteria

### Phase 1 Complete When:
- ✅ All CRITICAL service methods have ≥3 tests each
- ✅ All HIGH priority service methods have ≥2 tests each
- ✅ Service test coverage ≥70%
- ✅ All tests pass with clean output
- ✅ `flutter analyze` shows no issues

### Phase 2 Complete When:
- ✅ All critical UI components have widget tests
- ✅ All user workflows from requirements covered
- ✅ Widget test coverage ≥80%
- ✅ Tests use proper ProviderScope overrides
- ✅ All tests pass with clean output

### Phase 3 Complete When:
- ✅ End-to-end workflows verified with real services
- ✅ Multi-device sync scenarios tested
- ✅ Offline mode behavior validated
- ✅ Conflict resolution verified
- ✅ All integration tests pass consistently

### Phase 4 Complete When:
- ✅ All edge cases covered
- ✅ Error handling tested
- ✅ No memory leaks detected
- ✅ Performance tests pass
- ✅ Overall coverage ≥85%

## Next Steps

1. **Review & Approve Plan**: Get Rabble's sign-off on priorities and scope
2. **Phase 1 Implementation**: Start with `curated_list_service_crud_test.dart`
3. **Continuous Integration**: Run tests on every commit
4. **Coverage Monitoring**: Track coverage metrics as tests are added
5. **Documentation**: Update README with test instructions

---

**Document Status**: Draft for Review
**Created**: 2025-10-01
**Author**: Claude (Test Coverage Analysis)
**Estimated Effort**: 4 weeks full-time (160 hours)
