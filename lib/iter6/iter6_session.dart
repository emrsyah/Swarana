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
  Iter6Session({required this.participantId, required this.card, required this.simulated, required this.storage}) {
    storage.writeEvents('I6-$participantId', const []);
  }

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

  // Evaluator input
  final List<bool> interactions = List.filled(5, false);
  final List<I6Confusion> confusions = [];
  String notes = '';

  bool get running => startedAt != null && endedAt == null;
  int get elapsedSec => startedAt == null ? 0 : (endedAt ?? DateTime.now()).difference(startedAt!).inSeconds;
  int _sec() => DateTime.now().difference(startedAt!).inSeconds;

  void start() {
    startedAt = DateTime.now();
    _log('roleplay_started', {});
  }

  void end() {
    if (!running) return;
    endedAt = DateTime.now();
    _log('roleplay_ended', {'time_ms': endedAt!.difference(startedAt!).inMilliseconds});
    _proposeConfusions();
    save();
  }

  // ---------------- Tracking ----------------

  void onTap(Offset pos, Size size) {
    if (!running) return;
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
    }
    _log(event, {
      for (final e in props.entries)
        if (!const {'event', 'at', 'participant', 'variant', 'order_position', 'scenario', 'in_task', 'elapsed_ms'}
            .contains(e.key))
          e.key: e.value,
    });
  }

  /// Candidate confusion moments for the evaluator to confirm: long pauses
  /// between actions (Ragu?) and rage clicks (Salah tekan?).
  void _proposeConfusions() {
    final marks = [0, ...tapTimes, elapsedSec];
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
        'started_at': startedAt?.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'time_s': elapsedSec,
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
