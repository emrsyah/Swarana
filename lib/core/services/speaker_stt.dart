import 'dart:async';

import 'package:flutter/foundation.dart';

import 'stt_service.dart';
import 'voice_lab.dart';

/// Live speech-to-text with automatic speaker detection, backed by
/// [VoiceLab]: each sentence is tagged with who said it (on the phone) and
/// written by on-device Gemma for one person or OpenRouter for a group.
///
/// If the voice models can't be prepared (first run offline, no mic
/// permission, native failure) it falls back to Android's recognizer
/// ([LiveSttService]) for the rest of the session, with manual speakers.
class SpeakerSttService implements SttService {
  SpeakerSttService({VoiceLab? engine}) : _lab = engine ?? VoiceLab.instance;

  final VoiceLab _lab;
  final _events = StreamController<SttEvent>.broadcast();
  final _status = ValueNotifier(SttStatus.idle);
  final _level = ValueNotifier(0.0);
  StreamSubscription<LabUtterance>? _heardSub;

  LiveSttService? _fallback;
  bool _continuous = true;
  bool _ready = false;
  String _lastSpeaker = 's1';

  @override
  ValueListenable<SttStatus> get status => _status;
  @override
  ValueListenable<double> get level => _level;
  @override
  Stream<SttEvent> get events => _events.stream;
  @override
  String get speakerId => _fallback?.speakerId ?? _lastSpeaker;
  @override
  bool get continuous => _continuous;

  @override
  Future<bool> init() async {
    if (_ready) return true;
    if (_fallback != null) return _fallback!.init();
    try {
      await _lab.prepare();
    } catch (e) {
      debugPrint('SpeakerStt: falling back to Android recognizer: $e');
      return _useFallback();
    }
    _lab.reset(); // new conversation, new voices
    _heardSub = _lab.heard.listen(_onHeard);
    _lab.level.addListener(_syncLevel);
    _lab.status.addListener(_syncStatus);
    _ready = true;
    return true;
  }

  Future<bool> _useFallback() async {
    final fb = _fallback = LiveSttService();
    fb.status.addListener(() => _status.value = fb.status.value);
    fb.level.addListener(() => _level.value = fb.level.value);
    fb.events.listen(_events.add);
    return fb.init();
  }

  void _syncLevel() => _level.value = _lab.level.value;

  void _syncStatus() {
    _status.value = switch (_lab.status.value) {
      VoiceLabStatus.listening => SttStatus.listening,
      VoiceLabStatus.error => SttStatus.error,
      // idle/preparing: keep paused vs idle as set by pause()/stop().
      _ => _status.value == SttStatus.listening ? SttStatus.idle : _status.value,
    };
  }

  void _onHeard(LabUtterance u) {
    if (_events.isClosed) return;
    final id = _lastSpeaker = 's${u.speaker + 1}';
    if (!u.done) {
      _events.add(SttEvent('…', isFinal: false, speakerId: id));
      return;
    }
    final err = u.error;
    _events.add(err != null
        // Shown flagged as unclear rather than dropped, so the gap is visible.
        ? SttEvent('(ucapan tidak bisa ditulis: periksa internet atau unduh AI di ponsel)',
            isFinal: true, speakerId: id, confidence: 0.01)
        : SttEvent(u.text!, isFinal: true, speakerId: id));
    // v3 listens for a single utterance per tap.
    if (!_continuous) stop();
  }

  @override
  Future<void> start({bool continuous = true}) async {
    _continuous = continuous;
    final fb = _fallback;
    if (fb != null) return fb.start(continuous: continuous);
    if (!_ready && !await init()) return;
    if (_fallback != null) return _fallback!.start(continuous: continuous);
    await _lab.start();
  }

  @override
  Future<void> pause() async {
    if (_fallback != null) return _fallback!.pause();
    await _lab.stop();
    _status.value = SttStatus.paused;
  }

  @override
  Future<void> stop() async {
    if (_fallback != null) return _fallback!.stop();
    await _lab.stop();
    _status.value = SttStatus.idle;
  }

  @override
  void nextSpeaker() => _fallback != null ? _fallback!.nextSpeaker() : _lab.forceNewSpeaker();

  /// Speakers are detected from voices; a manual id only applies to the
  /// fallback recognizer.
  @override
  void setSpeaker(String id) => _fallback?.setSpeaker(id);

  @override
  void userReplied() {}

  @override
  void dispose() {
    _heardSub?.cancel();
    _lab.level.removeListener(_syncLevel);
    _lab.status.removeListener(_syncStatus);
    if (_ready) _lab.stop();
    _fallback?.dispose();
    _events.close();
  }
}
