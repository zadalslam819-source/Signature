// ABOUTME: Riverpod provider for tracking app foreground/background state
// ABOUTME: Ensures video visibility callbacks only trigger when app is actually in foreground

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_foreground_provider.g.dart';

/// State notifier for tracking app foreground/background state
@Riverpod(keepAlive: true)
class AppForeground extends _$AppForeground {
  @override
  bool build() => true; // Start as foreground

  void setForeground(bool isForeground) {
    state = isForeground;
  }
}

/// Convenience provider to read foreground state without watching
final isAppInForegroundProvider = Provider<bool>((ref) {
  return ref.watch(appForegroundProvider);
});
