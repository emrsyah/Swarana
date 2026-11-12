import 'package:vibration/vibration.dart';

/// Non-audio feedback. Deaf users cannot hear chimes, so key events get a
/// vibration, but sparingly: a buzz per sentence quickly becomes noise.
class Haptics {
  bool enabled = true;
  bool? _has;
  DateTime? _lastTick;

  /// Partner messages only buzz when someone starts talking after a pause,
  /// not for every sentence of the same turn.
  static const _tickQuiet = Duration(seconds: 20);

  Future<bool> _ok() async => enabled && (_has ??= await Vibration.hasVibrator());

  /// New partner message arrived.
  Future<void> tick() async {
    final now = DateTime.now();
    final last = _lastTick;
    _lastTick = now;
    if (last != null && now.difference(last) < _tickQuiet) return;
    if (await _ok()) await Vibration.vibrate(duration: 40);
  }

  /// TTS finished speaking the user's message.
  Future<void> done() async {
    if (await _ok()) await Vibration.vibrate(duration: 40);
  }

  /// Something needs attention (muted volume, mic denied...).
  Future<void> alert() async {
    if (await _ok()) await Vibration.vibrate(pattern: [0, 200, 100, 200]);
  }
}
