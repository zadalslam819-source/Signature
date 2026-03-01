# Riverpod 3 Test Migration Guide

## Overview
This guide documents the patterns needed to migrate tests from Riverpod 2 to Riverpod 3 based on successful migration of `home_feed_provider_test.dart`.

## Key Changes in Riverpod 3 Testing

### 1. Provider Override Pattern Change

**Riverpod 2 (OLD - BROKEN):**
```dart
container.updateOverrides([
  socialProvider.overrideWith(() {
    return SocialNotifier()..state = SocialState(...);
  }),
]);
```

**Riverpod 3 (NEW - CORRECT):**
```dart
// Create test notifier class
class TestSocialNotifier extends SocialNotifier {
  final SocialState _state;
  TestSocialNotifier(this._state);

  @override
  SocialState build() => _state;
}

// In test - create new container instead of updating
final testContainer = ProviderContainer(
  overrides: [
    socialProvider.overrideWith(() {
      return TestSocialNotifier(SocialState(...));
    }),
  ],
);
addTearDown(testContainer.dispose);
```

**Key Points:**
- Cannot directly set `.state` on a notifier from outside
- Cannot add/remove overrides with `updateOverrides` - must provide same number
- Create new containers per test when you need different provider states
- Always use `addTearDown(container.dispose)` for proper cleanup

### 2. Add `ref.mounted` Checks After Async Operations

In provider implementation code (not tests), add checks after any `await`:

**Before:**
```dart
Future<void> loadMore() async {
  final currentState = await future;
  state = AsyncData(currentState.copyWith(isLoadingMore: true));
  // ... more code
}
```

**After:**
```dart
Future<void> loadMore() async {
  final currentState = await future;

  // Check if provider is still mounted after async gap
  if (!ref.mounted) return;

  state = AsyncData(currentState.copyWith(isLoadingMore: true));

  try {
    await someAsyncOperation();

    // Check again after async operation
    if (!ref.mounted) return;

    state = AsyncData(newState);
  } catch (e) {
    if (!ref.mounted) return;
    // handle error
  }
}
```

**Why?** In Riverpod 3, notifiers can be disposed while async operations are in flight. Attempting to use `ref` or set `state` after disposal throws an error.

### 3. Test Helper Notifier Pattern

Create a test notifier class for each provider you need to override:

```dart
/// Test notifier that returns a fixed social state
class TestSocialNotifier extends SocialNotifier {
  final SocialState _state;

  TestSocialNotifier(this._state);

  @override
  SocialState build() => _state;
}
```

This allows you to:
- Return a fixed state without triggering initialization logic
- Avoid async initialization in tests
- Maintain type safety

## Common Test Patterns

### Pattern 1: Simple Provider Override Test

```dart
test('should do something with specific state', () async {
  final testContainer = ProviderContainer(
    overrides: [
      videoEventServiceProvider.overrideWithValue(mockVideoEventService),
      socialProvider.overrideWith(() {
        return TestSocialNotifier(SocialState(
          followingPubkeys: ['pubkey1', 'pubkey2'],
          isInitialized: true,
        ));
      }),
    ],
  );
  addTearDown(testContainer.dispose);

  final result = await testContainer.read(myProvider.future);

  expect(result.someField, expectedValue);
});
```

### Pattern 2: Testing Multiple States

Instead of using `updateOverrides`, create separate containers:

```dart
test('should handle empty following list', () async {
  final emptyContainer = ProviderContainer(
    overrides: [
      socialProvider.overrideWith(() {
        return TestSocialNotifier(SocialState(followingPubkeys: []));
      }),
    ],
  );
  addTearDown(emptyContainer.dispose);

  final result = await emptyContainer.read(myProvider.future);
  expect(result.isEmpty, isTrue);
});

test('should handle populated following list', () async {
  final populatedContainer = ProviderContainer(
    overrides: [
      socialProvider.overrideWith(() {
        return TestSocialNotifier(SocialState(
          followingPubkeys: ['pub1', 'pub2'],
        ));
      }),
    ],
  );
  addTearDown(populatedContainer.dispose);

  final result = await populatedContainer.read(myProvider.future);
  expect(result.length, equals(2));
});
```

### Pattern 3: Testing Notifier Methods

```dart
test('should call service method on action', () async {
  when(mockService.doSomething()).thenAnswer((_) async => {});

  final testContainer = ProviderContainer(
    overrides: [
      serviceProvider.overrideWithValue(mockService),
      myProvider.overrideWith(() => TestMyNotifier(initialState)),
    ],
  );
  addTearDown(testContainer.dispose);

  // Read the provider to initialize it
  await testContainer.read(myProvider.future);

  // Call method on notifier
  await testContainer.read(myProvider.notifier).performAction();

  // Verify
  verify(mockService.doSomething()).called(1);
});
```

## Migration Checklist

When migrating a provider test file:

- [ ] Create test helper notifier classes for any providers you override
- [ ] Replace all `container.updateOverrides` calls with new container creation
- [ ] Add `addTearDown(container.dispose)` for each container
- [ ] Verify all provider overrides use `overrideWith(() => TestNotifier(state))`
- [ ] Add `ref.mounted` checks in provider implementation after async operations
- [ ] Update imports if using legacy providers (add `flutter_riverpod/legacy.dart`)
- [ ] Run tests and fix any remaining issues
- [ ] Check for cleanup errors and address if critical

## Common Issues and Solutions

### Issue: "Tried to change the number of overrides"
**Solution:** Create a new container instead of using `updateOverrides`.

### Issue: "Cannot use Ref after disposal"
**Solution:** Add `if (!ref.mounted) return;` checks after async operations in provider code.

### Issue: "Cannot set state directly"
**Solution:** Create a test notifier class with a `build()` method that returns the desired state.

### Issue: Cleanup errors during disposal
**Solution:** Usually benign if tests pass. If critical, investigate provider lifecycle and dependencies.

## Examples

See `test/providers/home_feed_provider_test.dart` for a complete working example of all these patterns.

## Additional Resources

- [Riverpod 3 Migration Guide](https://riverpod.dev/docs/3.0_migration)
- [Riverpod Testing Documentation](https://riverpod.dev/docs/essentials/testing)