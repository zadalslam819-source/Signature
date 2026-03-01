// ABOUTME: State class for tracking seen videos with immutable state pattern
// ABOUTME: Used by SeenVideosNotifier for reactive state management

import 'package:freezed_annotation/freezed_annotation.dart';

part 'seen_videos_state.freezed.dart';

@freezed
sealed class SeenVideosState with _$SeenVideosState {
  const factory SeenVideosState({
    @Default({}) Set<String> seenVideoIds,
    @Default(false) bool isInitialized,
  }) = _SeenVideosState;

  /// Initial empty state
  static const initial = SeenVideosState();
}
