import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SttEvent {
  SttEvent(this.text, {required this.isFinal, this.speakerId = 's1', this.confidence = -1});

  final String text;
  final bool isFinal;
  final String speakerId;

  /// 0..1, or <= 0 when the engine gave no rating.
  final double confidence;

  bool get lowConfidence => isFinal && confidence > 0 && confidence < 0.6;
}

enum SttStatus { idle, listening, paused, unavailable, error }

abstract class SttService {
  ValueListenable<SttStatus> get status;

  /// 0..1 input level for the header meter.
  ValueListenable<double> get level;
  Stream<SttEvent> get events;

  /// Current partner speaker id. Live STT has no diarization, so the user
  /// (or researcher) switches speakers manually: see [nextSpeaker].
  String get speakerId;

  Future<bool> init();

  /// Mode of the last [start] call.
  bool get continuous;

  /// [continuous] keeps restarting after each utterance (v5). v3 uses a
  /// single 30 s session, as in iteration 3.
  Future<void> start({bool continuous = true});
  Future<void> pause();
  Future<void> stop();

  /// Mark that a different person is now speaking.
  void nextSpeaker();
  void setSpeaker(String id);

  /// The user sent a reply. Scripted mode uses this to advance the script.
  void userReplied();

  void dispose();
}

class LiveSttService implements SttService {
  final _stt = SpeechToText();
  final _events = StreamController<SttEvent>.broadcast();
  final _status = ValueNotifier(SttStatus.idle);
  final _level = ValueNotifier(0.0);

  bool _continuous = true;
  bool _wanted = false;
  int _speakerCount = 1;
  String _speaker = 's1';
  Timer? _restart;
  int _busyBackoffMs = 300;

  @override
  ValueListenable<SttStatus> get status => _status;
  @override
  ValueListenable<double> get level => _level;
  @override
  Stream<SttEvent> get events => _events.stream;
  @override
  String get speakerId => _speaker;
  @override
  bool get continuous => _continuous;

  @override
  Future<bool> init() async {
    final ok = await _stt.initialize(onError: _onError, onStatus: _onStatus);
    if (!ok) _status.value = SttStatus.unavailable;
    return ok;
  }

  @override
  Future<void> start({bool continuous = true}) async {
    _continuous = continuous;
    _wanted = true;
    await _listen();
  }

  /// In dictation mode one session (up to 60 s) returns ever-growing text,
  /// so everything landed in one bubble on device. We cut it into utterances:
  /// after [_utteranceGap] without new words the current part is finalized and
  /// later words start a new message.
  static const _utteranceGap = Duration(milliseconds: 1400);
  int _committed = 0;
  String _lastText = '';
  Timer? _gap;

  void _emitSegment(String full, {required bool isFinal, double confidence = -1}) {
    if (full.length < _committed) _committed = 0; // engine rewrote earlier words
    final seg = full.substring(_committed).trim();
    if (seg.isEmpty || _events.isClosed) return;
    _events.add(SttEvent(seg, isFinal: isFinal, speakerId: _speaker, confidence: confidence));
    if (isFinal) _committed = full.length;
  }

  Future<void> _listen() async {
    if (!_wanted || _stt.isListening) return;
    _committed = 0;
    _lastText = '';
    _status.value = SttStatus.listening;
    await _stt.listen(
      onResult: _onResult,
      onSoundLevelChange: (db) =>
          // Android reports roughly -2..10 dB; map to 0..1.
          _level.value = ((db + 2) / 12).clamp(0.0, 1.0),
      listenOptions: SpeechListenOptions(
        localeId: 'id_ID',
        partialResults: true,
        listenMode: _continuous ? ListenMode.dictation : ListenMode.confirmation,
        pauseFor: Duration(seconds: _continuous ? 3 : 4),
        listenFor: Duration(seconds: _continuous ? 60 : 30),
        cancelOnError: false,
      ),
    );
  }

  void _onResult(SpeechRecognitionResult r) {
    final text = r.recognizedWords.trim();
    if (text.isEmpty || _events.isClosed) return;
    _busyBackoffMs = 300;
    _gap?.cancel();
    _lastText = text;
    if (r.finalResult) {
      _emitSegment(text, isFinal: true, confidence: r.confidence);
      return;
    }
    _emitSegment(text, isFinal: false);
    if (_continuous) {
      _gap = Timer(_utteranceGap, () => _emitSegment(_lastText, isFinal: true));
    }
  }

  void _onStatus(String s) {
    if (s == SpeechToText.doneStatus || s == SpeechToText.notListeningStatus) {
      _level.value = 0;
      _scheduleRestart();
    }
  }

  void _onError(SpeechRecognitionError e) {
    // No match / timeout just mean silence: restart quietly.
    if (e.errorMsg == 'error_busy') _busyBackoffMs = (_busyBackoffMs * 2).clamp(300, 3000);
    if (!e.permanent || e.errorMsg == 'error_no_match' || e.errorMsg == 'error_speech_timeout') {
      _scheduleRestart();
      return;
    }
    if (e.errorMsg == 'error_permission' || e.errorMsg == 'error_insufficient_permissions') {
      _wanted = false;
      _status.value = SttStatus.unavailable;
      return;
    }
    _scheduleRestart();
  }

  void _scheduleRestart() {
    if (!_wanted) return;
    if (!_continuous) {
      _wanted = false;
      _status.value = SttStatus.idle;
      return;
    }
    // Android plays a short system beep on every restart; known limitation.
    _restart?.cancel();
    _restart = Timer(Duration(milliseconds: _busyBackoffMs), _listen);
  }

  @override
  Future<void> pause() async {
    _wanted = false;
    _restart?.cancel(); _gap?.cancel();
    await _stt.stop();
    _level.value = 0;
    _status.value = SttStatus.paused;
  }

  @override
  Future<void> stop() async {
    _wanted = false;
    _restart?.cancel(); _gap?.cancel();
    await _stt.cancel();
    _level.value = 0;
    _status.value = SttStatus.idle;
  }

  @override
  void nextSpeaker() => _speaker = 's${++_speakerCount}';

  @override
  void setSpeaker(String id) => _speaker = id;

  @override
  void userReplied() {}

  @override
  void dispose() {
    _wanted = false;
    _restart?.cancel(); _gap?.cancel();
    _stt.cancel();
    _events.close();
  }
}
