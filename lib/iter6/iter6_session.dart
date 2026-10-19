import 'dart:ui' show Offset, Size;

import '../core/services/storage.dart';
import '../ux_kit/ux_controller.dart';

/// One Uji 4 role-play: records taps, sends and app events while the
/// participant uses the Iterasi 5 interface, then holds the evaluator's
/// scoring. Saved as study file `I6-<pid>`.
class I6Confusion {
  I6Confusion({required this.atSec, required this.type, required this.text, required this.source, this.note = ''});
  int atSec;
  String type; // Ragu / Salah tekan / Bertanya
  String text; // teks penyebab
  final String source; // auto | manual
  String note;
  bool include = true;

  Map<String, Object?> toJson() => {'at_s': atSec, 'type': type, 'text': text, 'source': source, 'note': note};
}

class Iter6Session implements UxEventSink {
  Iter6Session({required this.participantId, required this.card, required this.simulated, required this.storage,
      this.cardOverridden = false}) {
    storage.writeEvents('I6-$participantId', const []);
  }

  /// Safe for file names: letters, digits, dash, underscore.
  static String cleanId(String raw) => raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_-]'), '');

  final bool cardOverridden;

  /// Chat transcript for the evaluator (partner finals and sent messages).
  final List<({int atSec, bool me, String text})> transcript = [];
  bool scored = false;

  final String participantId;
  final String card;
  final bool simulated;
  final Storage storage;

  DateTime? startedAt;
  DateTime? endedAt;
  String screen = '/v5/obrolan';
  int taps = 0;
  int rage = 0;
  final Map<String, int> sendsBySource = {};
  final List<({int atSec, String text})> sends = [];
  final List<int> tapTimes = []; // seconds since start
  final List<({int atSec, double x, double y, String screen})> rageAt = [];
  final List<({DateTime t, Offset p})> _recent = [];

  // Interaction 1 (news in Transkrip): the answer typed in the question modal.
  String newsAnswer = '';
  int newsRepeats = 0;
  int? newsAnsweredSec;

  /// Address check for interaction 1; pre-ticks the box, the evaluator confirms.
  static bool newsAnswerOk(String a) {
    final low = a.toLowerCase();
    return RegExp(r'asia\s*-?\s*afrika|asia\s*africa').hasMatch(low) && RegExp(r'\b45\b|empat puluh lima').hasMatch(low);
  }

  void answerNews(String text) {
    if (!running) return;
    newsAnswer = text.trim();
    newsAnsweredSec = _sec();
    interactions[0] = newsAnswerOk(newsAnswer);
    transcript.add((atSec: _sec(), me: true, text: 'Jawaban berita: $newsAnswer'));
    _log('news_answered', {'text': newsAnswer, 'auto_ok': interactions[0], 'repeats': newsRepeats});
  }

  void repeatNews() {
    if (!running) return;
    newsRepeats++;
    _log('news_repeat', {});
  }

  // Evaluator input
  final List<bool> interactions = List.filled(5, false);
  final List<I6Confusion> confusions = [];
  String notes = '';

  bool get running => startedAt != null && endedAt == null;

  // Time spent reading a between-phase instruction is not task time.
  Duration _paused = Duration.zero;
  DateTime? _pausedSince;
  bool get paused => _pausedSince != null;

  Duration _pausedUntil(DateTime t) => _paused + (_pausedSince == null ? Duration.zero : t.difference(_pausedSince!));
  int get elapsedSec {
    if (startedAt == null) return 0;
    final end = endedAt ?? DateTime.now();
    return (end.difference(startedAt!) - _pausedUntil(end)).inSeconds;
  }

  int _sec() => (DateTime.now().difference(startedAt!) - _pausedUntil(DateTime.now())).inSeconds;

  void pause() {
    if (!running || paused) return;
    _pausedSince = DateTime.now();
    _log('instruction_shown', {});
  }

  void resume() {
    final since = _pausedSince;
    if (since == null) return;
    _paused += DateTime.now().difference(since);
    _pausedSince = null;
    _log('instruction_closed', {'read_ms': DateTime.now().difference(since).inMilliseconds});
  }

  void start() {
    startedAt = DateTime.now();
    _log('roleplay_started', {});
  }

  void partnerLine(String text) {
    if (running) transcript.add((atSec: _sec(), me: false, text: text));
  }

  /// [at] lets the evaluator's confirmation dialog not count as task time.
  void end({DateTime? at}) {
    if (!running) return;
    resume();
    endedAt = at ?? DateTime.now();
    _log('roleplay_ended', {'time_ms': endedAt!.difference(startedAt!).inMilliseconds});
    _proposeConfusions();
    save();
  }

  // ---------------- Tracking ----------------

  void onTap(Offset pos, Size size) {
    if (!running || paused) return;
    taps++;
    final s = _sec();
    tapTimes.add(s);
    final x = pos.dx / size.width, y = pos.dy / size.height;
    _log('ux_tap', {'x': x, 'y': y});
    final now = DateTime.now();
    _recent
      ..removeWhere((t) => now.difference(t.t) > const Duration(seconds: 1))
      ..add((t: now, p: pos));
    if (_recent.where((t) => (t.p - pos).distance < 40).length >= 3) {
      rage++;
      rageAt.add((atSec: s, x: x, y: y, screen: screen));
      _log('ux_rage_click', {'x': x, 'y': y});
      _recent.clear();
    }
  }

  void onRoute(String name) {
    screen = name;
    if (running) _log('ux_screen', {});
  }

  /// Receives the v5 app's own events (message_sent, simplify_used, ...).
  @override
  void send(String event, Map<String, Object?> props) {
    if (!running) return;
    if (event == 'message_sent') {
      final b = props['bucket'] as String? ?? 'keyboard';
      sendsBySource[b] = (sendsBySource[b] ?? 0) + 1;
      sends.add((atSec: _sec(), text: '${props['length']} karakter · $b'));
      transcript.add((atSec: _sec(), me: true, text: '${props['text'] ?? ''}'));
    }
    _log(event, {
      for (final e in props.entries)
        if (!const {'event', 'at', 'participant', 'variant', 'order_position', 'scenario', 'in_task', 'elapsed_ms', 'screen'}
            .contains(e.key))
          e.key: e.value,
    });
  }

  /// Candidate confusion moments for the evaluator to confirm: long pauses
  /// between actions (Ragu?) and rage clicks (Salah tekan?).
  void _proposeConfusions() {
    // Actions = taps and sent messages; partner lines also reset the gap
    // (time spent reading/listening is not hesitation).
    final marks = <int>{0, ...tapTimes, ...transcript.map((t) => t.atSec), elapsedSec}.toList()..sort();
    for (var i = 1; i < marks.length; i++) {
      if (marks[i] - marks[i - 1] >= 15) {
        confusions.add(I6Confusion(
            atSec: marks[i - 1], type: 'Ragu', text: '', source: 'auto',
            note: 'Tidak ada aksi ${marks[i] - marks[i - 1]} detik (bisa juga sedang membaca/menunggu)'));
      }
    }
    for (final r in rageAt) {
      confusions.add(I6Confusion(
          atSec: r.atSec, type: 'Salah tekan', text: '', source: 'auto', note: 'Rage click di ${r.screen}'));
    }
    confusions.sort((a, b) => a.atSec.compareTo(b.atSec));
    for (final c in confusions) {
      c.include = false; // evaluator opts in
    }
  }

  void _log(String event, Map<String, Object?> props) {
    storage.appendEvent('I6-$participantId', {
      'event': event,
      'at': DateTime.now().toIso8601String(),
      'participant': participantId,
      'study': 'iter6',
      'variant': 'iter6',
      'screen': screen,
      'card': card,
      'in_task': running,
      ...props,
    });
  }

  Map<String, Object?> toJson() => {
        'type': 'iter6',
        'participant': participantId,
        'card': card,
        'mode': simulated ? 'simulasi' : 'teller_manusia',
        'card_overridden': cardOverridden,
        'scored': scored,
        'transcript': [for (final t in transcript) {'at_s': t.atSec, 'who': t.me ? 'nasabah' : 'lawan bicara', 'text': t.text}],
        'started_at': startedAt?.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'time_s': elapsedSec,
        'instruction_ms': _paused.inMilliseconds,
        'news_answer': newsAnswer,
        'news_answered_s': newsAnsweredSec,
        'news_repeats': newsRepeats,
        'interactions': interactions,
        'success_count': interactions.where((e) => e).length,
        'confusions': confusions.where((c) => c.include).map((c) => c.toJson()).toList(),
        'taps': taps,
        'rage_clicks': rage,
        'sends_by_source': sendsBySource,
        'notes': notes,
      };

  Future<void> save() => storage.saveStudy('I6-$participantId', toJson());
}
