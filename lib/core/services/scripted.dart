import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/message.dart';
import '../models/scenario.dart';
import 'llm_service.dart';
import 'stt_service.dart';

/// Plays a scenario's partner lines as if they were recognized speech.
///
/// Delivery rule (identical for both variants): a partner turn is only played
/// while the app is listening. If the app is not listening, the turn waits and
/// that wait is added to [waited] so it can be excluded from task time.
class ScriptedStt implements SttService {
  ScriptedStt(this.form, {this.onSignal, this.wordDelay = const Duration(milliseconds: 80)});

  final ScenarioForm form;
  final Duration wordDelay;

  /// Called with 'done' after the user answers the last waiting turn.
  final void Function(String signal)? onSignal;

  final _events = StreamController<SttEvent>.broadcast();
  final _status = ValueNotifier(SttStatus.idle);
  final _level = ValueNotifier(0.0);

  int _index = 0;
  bool _waitingForUser = false;
  bool _playing = false;
  bool _done = false;
  bool _continuous = true;
  DateTime? _blockedSince;
  Duration waited = Duration.zero;
  String _speaker = 's1';

  @override
  ValueListenable<SttStatus> get status => _status;
  @override
  ValueListenable<double> get level => _level;
  @override
  Stream<SttEvent> get events => _events.stream;
  @override
  String get speakerId => _speaker;

  bool get isWaitingForUser => _waitingForUser;
  bool get isDone => _done;

  /// Suggestions attached to the most recent partner turn.
  List<String> get currentSuggestions {
    for (var i = _index - 1; i >= 0; i--) {
      final t = form.turns[i];
      if (t.text != null) return t.suggest;
    }
    return const [];
  }

  @override
  Future<bool> init() async => true;

  @override
  Future<void> start({bool continuous = true}) async {
    _continuous = continuous;
    _status.value = SttStatus.listening;
    _unblock();
    _pump();
  }

  @override
  Future<void> pause() async {
    _status.value = SttStatus.paused;
    _level.value = 0;
  }

  @override
  Future<void> stop() async {
    _status.value = SttStatus.idle;
    _level.value = 0;
  }

  void _unblock() {
    final since = _blockedSince;
    if (since != null) {
      waited += DateTime.now().difference(since);
      _blockedSince = null;
    }
  }

  Future<void> _pump() async {
    if (_playing || _waitingForUser || _done) return;
    _playing = true;
    while (_index < form.turns.length) {
      final turn = form.turns[_index];
      if (turn.waitForUser) {
        _waitingForUser = true;
        break;
      }
      if (_status.value != SttStatus.listening) {
        _blockedSince ??= DateTime.now();
        break;
      }
      await _speak(turn);
      _index++;
      // v3 single-shot listening ends after one utterance.
      if (!_continuous) {
        _status.value = SttStatus.idle;
        break;
      }
    }
    _playing = false;
  }

  Future<void> _speak(ScenarioTurn turn) async {
    _speaker = turn.speaker ?? 's1';
    final words = turn.text!.split(' ');
    for (var i = 1; i <= words.length; i++) {
      _level.value = 0.4 + (i % 3) * 0.2;
      _events.add(SttEvent(words.take(i).join(' '), isFinal: false, speakerId: _speaker));
      await Future<void>.delayed(wordDelay);
    }
    _level.value = 0;
    _events.add(SttEvent(turn.text!, isFinal: true, speakerId: _speaker, confidence: 0.95));
  }

  @override
  void userReplied() {
    if (!_waitingForUser) return; // idempotent: extra sends don't skip turns
    _waitingForUser = false;
    _index++;
    if (_index >= form.turns.length) {
      _done = true;
      onSignal?.call('done');
      return;
    }
    _pump();
  }

  @override
  void nextSpeaker() {}
  @override
  void setSpeaker(String id) => _speaker = id;

  @override
  void dispose() => _events.close();
}

/// Canned AI answers so scripted sessions work offline and give every
/// participant identical suggestions.
class ScriptedLlm implements LlmService {
  ScriptedLlm({this.stt, this.glossary = const {}});

  /// Generic fallback used when no OpenRouter key is configured.
  ScriptedLlm.generic() : stt = null, glossary = const {};

  final ScriptedStt? stt;
  final Map<String, String> glossary;

  static const _fallback = ['Baik, saya mengerti', 'Bisa diulangi?', 'Terima kasih'];

  @override
  Future<List<String>> suggestReplies(List<ChatMessage> history, Map<String, Speaker> speakers,
      {String draft = ''}) async {
    final s = stt?.currentSuggestions ?? const [];
    return s.isEmpty ? _fallback : s;
  }

  @override
  Future<List<String>> suggestionsFromTranscript(String text, {int max = 6}) async =>
      (await suggestReplies(const [], const {})).take(max).toList();

  @override
  Future<String> simplify(String text) async {
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    return sentences.map((s) {
      final w = s.split(' ');
      return w.length <= 12 ? s : '${w.take(12).join(' ')}.';
    }).join('\n');
  }

  @override
  Future<String> explainWord(String word, String context) async =>
      glossary[word.toLowerCase()] ?? 'Arti kata "$word" belum tersedia tanpa internet.';

  @override
  Future<String> titleFor(String text) async {
    final w = text.split(RegExp(r'\s+')).where((e) => e.length > 3).take(3).join(' ');
    return w.isEmpty ? 'Obrolan baru' : w[0].toUpperCase() + w.substring(1);
  }
}
