import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rhythm/core/theme/theme_provider.dart';

/// Demo mode (derived from app settings): switches the schedule to a
/// generated throwaway timetable and enables the fun preview features.
/// Defined here so [clockProvider] consumers and the schedule provider
/// share one source of truth.
final demoModeProvider = Provider<bool>((ref) {
  return ref.watch(appSettingsProvider.select((s) => s.demoMode));
});

/// App-wide ticking clock for "ongoing lesson" UI and live countdowns.
///
/// Ticks once per second, aligned to the second boundary, so the
/// displayed countdown never lags behind the wall clock by a fixed
/// fraction of a second. Widgets that only need minute resolution
/// (highlighting the ongoing lesson) subscribe through `select`, so the
/// second tick does not rebuild the whole week.
/// Demo mode keeps real time: the generated demo schedule always contains
/// a lesson that is running right now, so the countdown works live.
final clockProvider = StateNotifierProvider<ClockNotifier, DateTime>((ref) {
  // Riverpod сам вызывает dispose у notifier — повторный ref.onDispose
  // приводил к «Tried to use ClockNotifier after dispose».
  return ClockNotifier();
});

class ClockNotifier extends StateNotifier<DateTime> {
  Timer? _timer;

  ClockNotifier() : super(DateTime.now()) {
    _scheduleTick();
  }

  /// Re-arms a one-shot timer for the next second boundary instead of
  /// `Timer.periodic`: the period would drift and the countdown with it.
  void _scheduleTick() {
    final delay = Duration(milliseconds: 1000 - DateTime.now().millisecond);
    _timer = Timer(delay, () {
      if (!mounted) return;
      state = DateTime.now();
      _scheduleTick();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
