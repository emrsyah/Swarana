import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/services/stt_service.dart';
import 'v3_backend.dart';

/// Ported from iteration 3. Keeps the original singleton + ValueNotifier API
/// and single-shot behaviour (one 30 s session that ends on a pause), but
/// runs on the shared STT service so live and scripted modes work the same in
/// both variants.
class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final ValueNotifier<bool> isListeningNotifier = ValueNotifier(false);

  /// Also written by the v3 UI for manual text, as in the original.
  final ValueNotifier<String> recognizedTextNotifier = ValueNotifier('');
  final ValueNotifier<String> statusNotifier = ValueNotifier('notListening');

  SttService? _stt;
  StreamSubscription<SttEvent>? _sub;

  bool get isInitialized => _stt != null;

  /// Rebinds to the current shared STT (a new one per variant/task).
  void _bind() {
    final s = V3Backend.services.stt;
    if (identical(s, _stt)) return;
    _stt?.status.removeListener(_onStatus);
    _sub?.cancel();
    _stt = s;
    s.status.addListener(_onStatus);
    _sub = s.events.listen((e) => recognizedTextNotifier.value = e.text);
    _onStatus();
  }

  void _onStatus() {
    final listening = _stt?.status.value == SttStatus.listening;
    isListeningNotifier.value = listening;
    statusNotifier.value = listening ? 'listening' : 'notListening';
  }

  Future<bool> initialize() async {
    _bind();
    return _stt!.init();
  }

  Future<void> startListening({
    String? localeId,
    Duration? timeout,
    Duration? pauseFor,
    bool partialResults = true,
  }) async {
    _bind();
    if (isListeningNotifier.value) return;
    recognizedTextNotifier.value = '';
    V3Backend.ux.track('listen_started');
    await _stt!.start(continuous: false);
  }

  Future<void> stopListening() async => _stt?.pause();

  Future<void> cancelListening() async => _stt?.stop();

  void dispose() {}
}
