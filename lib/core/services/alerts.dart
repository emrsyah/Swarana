import 'dart:async';

import 'haptics.dart';

enum AlertKind { noisy, volumeLow, volumeMuted, speechWhilePaused, offline, micDenied }

/// App-wide alert bus. Real triggers: volume checks before TTS, LLM/network
/// failures, mic permission. The researcher panel can also fire any alert for
/// demos and testing.
class Alerts {
  Alerts(this._haptics);

  final Haptics _haptics;
  final _ctrl = StreamController<AlertKind>.broadcast();
  final Map<AlertKind, DateTime> _last = {};

  Stream<AlertKind> get stream => _ctrl.stream;

  /// Shown as a banner only, no vibration: they come from background work
  /// (AI suggestions failing, talking while paused) and can repeat often.
  static const _silent = {AlertKind.offline, AlertKind.speechWhilePaused};

  void raise(AlertKind kind) {
    // Avoid repeating the same condition.
    final prev = _last[kind];
    if (prev != null && DateTime.now().difference(prev) < const Duration(seconds: 60)) return;
    _last[kind] = DateTime.now();
    if (!_silent.contains(kind)) _haptics.alert();
    _ctrl.add(kind);
  }
}
