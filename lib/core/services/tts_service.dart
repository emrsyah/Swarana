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

  /// Text and time of the last utterance, so listeners can drop echoes.
  String? lastSpokenText;
  DateTime? lastSpokenAt;

  /// True if [heard] looks like the phone's own last utterance.
  bool isEcho(String heard) {
    final at = lastSpokenAt, said = lastSpokenText;
    if (at == null || said == null) return false;
    if (DateTime.now().difference(at) > const Duration(seconds: 4)) return false;
    String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final h = norm(heard), s = norm(said);
    return h.isNotEmpty && (s.contains(h) || h.contains(s));
  }
  bool _disposed = false;

  void _emit(TtsState s) {
    final id = _current;
    if (id != null && !_disposed) _updates.add((id: id, state: s));
  }

  void _finish(TtsState s) {
    _emit(s);
    if (s == TtsState.done && !_disposed) haptics.done();
    _current = null;
    lastSpokenAt = DateTime.now();
    if (_resumeStt && !_disposed) {
      _resumeStt = false;
      // Resume in the mode it was in (v3 single-shot, v5 continuous), after
      // the speaker's tail has died down (on device the app heard itself).
      final continuous = _resumeContinuous;
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (!_disposed) stt?.start(continuous: continuous);
      });
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
    lastSpokenText = text;
    lastSpokenAt = DateTime.now();
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
