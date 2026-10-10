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

  void raise(AlertKind kind) {
    // Avoid buzzing repeatedly for the same condition.
    final prev = _last[kind];
    if (prev != null && DateTime.now().difference(prev) < const Duration(seconds: 8)) return;
    _last[kind] = DateTime.now();
    _haptics.alert();
    _ctrl.add(kind);
  }
}
