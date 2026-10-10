import 'package:vibration/vibration.dart';

/// Non-audio feedback. Deaf users cannot hear chimes, so every important
/// event gets a vibration pattern.
class Haptics {
  bool enabled = true;
  bool? _has;

  Future<bool> _ok() async => enabled && (_has ??= await Vibration.hasVibrator());

  /// New partner message arrived.
  Future<void> tick() async {
    if (await _ok()) await Vibration.vibrate(duration: 45);
  }

  /// TTS finished speaking the user's message.
  Future<void> done() async {
    if (await _ok()) await Vibration.vibrate(pattern: [0, 50, 80, 50]);
  }

  /// Something needs attention (noise, volume, offline).
  Future<void> alert() async {
    if (await _ok()) await Vibration.vibrate(pattern: [0, 200, 100, 200]);
  }
}
