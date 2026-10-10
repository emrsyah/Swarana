import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:volume_controller/volume_controller.dart';

import '../models/message.dart';
import 'alerts.dart';
import 'haptics.dart';
import 'stt_service.dart';

typedef TtsUpdate = ({String id, TtsState state});

/// Text-to-speech with visible state. Pauses STT while speaking so the app
/// does not transcribe its own voice as partner speech.
class TtsService {
  TtsService({required this.alerts, required this.haptics});

  final Alerts alerts;
  final Haptics haptics;
  SttService? stt;

  final _tts = FlutterTts();
  final _updates = StreamController<TtsUpdate>.broadcast();
  String? _current;
  bool _resumeStt = false;

  /// Same rate in both variants so the A/B compares interface only.
  static const speechRate = 0.5;

  Stream<TtsUpdate> get updates => _updates.stream;

  Future<void> init() async {
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(speechRate);
    _tts.setStartHandler(() => _emit(TtsState.speaking));
    _tts.setCompletionHandler(() => _finish(TtsState.done));
    _tts.setCancelHandler(() => _finish(TtsState.done));
    _tts.setErrorHandler((_) => _finish(TtsState.failed));
  }

  bool _resumeContinuous = true;
  bool _disposed = false;

  void _emit(TtsState s) {
    final id = _current;
    if (id != null && !_disposed) _updates.add((id: id, state: s));
  }

  void _finish(TtsState s) {
    _emit(s);
    if (s == TtsState.done && !_disposed) haptics.done();
    _current = null;
    if (_resumeStt && !_disposed) {
      _resumeStt = false;
      // Resume in the mode it was in (v3 single-shot, v5 continuous).
      stt?.start(continuous: _resumeContinuous);
    }
  }

  /// Speaks [text] for message [id]. Returns the state it ended in.
  Future<void> speak(String id, String text) async {
    try {
      final vol = await VolumeController.instance.getVolume();
      if (vol <= 0.01) {
        alerts.raise(AlertKind.volumeMuted);
        _updates.add((id: id, state: TtsState.muted));
        return;
      }
      if (vol < 0.3) alerts.raise(AlertKind.volumeLow);
    } on Exception {
      // Volume unknown (e.g. desktop): speak anyway.
    }
    if (_current != null) await _tts.stop();
    final s = stt;
    if (s != null && s.status.value == SttStatus.listening) {
      _resumeStt = true;
      _resumeContinuous = s.continuous;
      await s.pause();
    }
    _current = id;
    _updates.add((id: id, state: TtsState.speaking));
    final r = await _tts.speak(text);
    if (r != 1) _finish(TtsState.failed);
  }

  /// Stops speech without resuming listening (leaving a screen).
  Future<void> stop() {
    _resumeStt = false;
    return _tts.stop();
  }

  void dispose() {
    _disposed = true;
    _resumeStt = false;
    _tts.stop();
  }
}
