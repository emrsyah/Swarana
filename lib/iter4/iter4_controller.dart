import 'dart:async';
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';

import '../core/services/storage.dart';

/// Iteration-4 task test: 3 interface options × 3 short tasks, with a scripted
/// partner (no real speech). Records completion, time, errors and taps.
/// No questionnaires: those happen outside the app.

enum I4Option {
  chat('opsi1', 'Opsi 1 · Normal Chat'),
  dual('opsi2', 'Opsi 2 · Dual View'),
  audio('opsi3', 'Opsi 3 · Audio First');

  const I4Option(this.id, this.label);
  final String id;
  final String label;
}

enum I4Task {
  reply('T1', 'Balas', 'Pesan nasi goreng yang tidak pedas ke kasir.'),
  repeat('T2', 'Minta ulang', 'Ucapan kasir tidak jelas. Minta kasir mengulang ucapannya.'),
  recall('T3', 'Ingat', 'Berapa total harga yang tadi disebut kasir? Cari di aplikasi, lalu sebutkan ke peneliti.');

  const I4Task(this.id, this.title, this.instruction);
  final String id;
  final String title;
  final String instruction;
}

enum I4Phase { brief, running, mark, between, done }

class I4Message {
  I4Message({required this.me, required this.text, this.partial = false, this.garbled = false})
      : time = DateTime.now();
  final bool me;
  String text;
  bool partial;
  final bool garbled;
  final DateTime time;
  bool spoken = false;
}

class I4TaskResult {
  I4TaskResult(this.option, this.task);
  final I4Option option;
  final I4Task task;
  bool completed = false;
  String outcome = 'running'; // success | wrong | gave_up | timed_out
  int timeMs = 0;
  int taps = 0;
  int rage = 0;
  final List<String> errors = [];
  final List<String> sends = [];

  Map<String, Object?> toJson() => {
        'option': option.id,
        'task': task.id,
        'completed': completed,
        'outcome': outcome,
        'time_ms': timeMs,
        'errors': errors.length,
        'error_kinds': errors,
        'taps': taps,
        'rage_clicks': rage,
        'sends': sends,
      };
}

class Iter4Controller extends ChangeNotifier {
  Iter4Controller({required this.participantId, required this.storage}) {
    final n = int.tryParse(participantId.replaceAll(RegExp(r'\D'), '')) ?? participantId.length;
    const squares = [
      [0, 1, 2],
      [1, 2, 0],
      [2, 0, 1],
    ];
    order = [for (final i in squares[n % 3]) I4Option.values[i]];
    startedAt = DateTime.now();
  }

  static const timeLimit = Duration(minutes: 3);

  final String participantId;
  final Storage storage;
  late final List<I4Option> order;
  late final DateTime startedAt;

  int optionIndex = 0;
  int taskIndex = 0;
  I4Phase phase = I4Phase.brief;
  final List<I4TaskResult> results = [];
  List<I4Message> messages = [];

  I4TaskResult? _current;
  DateTime? _t0;
  Timer? _timeout;
  int _script = 0; // cancels running scripts when the option/task changes
  final List<({DateTime t, Offset p})> _recent = [];

  I4Option get option => order[optionIndex];
  I4Task get task => I4Task.values[taskIndex];
  bool get running => phase == I4Phase.running;
  int get elapsedSec => _t0 == null ? 0 : DateTime.now().difference(_t0!).inSeconds;

  I4Message? get lastPartner => messages.where((m) => !m.me).lastOrNull;
  I4Message? get lastMine => messages.where((m) => m.me).lastOrNull;

  // ---------------- Flow ----------------

  void startTask() {
    if (phase != I4Phase.brief) return;
    _current = I4TaskResult(option, task);
    _t0 = DateTime.now();
    _timeout?.cancel();
    _timeout = Timer(timeLimit, () => _finish('timed_out', false));
    phase = I4Phase.running;
    notifyListeners();
    _log('task_started', {});
    _runScript();
  }

  /// Scripted partner lines for the current task (same for every option).
  Future<void> _runScript() async {
    final id = ++_script;
    switch (task) {
      case I4Task.reply:
        await _say(id, 'Selamat siang! Mau pesan apa?');
      case I4Task.repeat:
        await _say(id, 'Baik, nasi goreng tidak pedas.');
        await _say(id, 'Totalnya dua puluh lima ribu ya.');
        await _say(id, 'Minumnya mau … (suara tidak jelas) …', garbled: true);
      case I4Task.recall:
        await _say(id, 'Minumnya mau es teh atau air putih?');
        await _say(id, 'Silakan ditunggu di meja nomor tujuh ya.');
    }
  }

  Future<void> _say(int id, String text, {bool garbled = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (id != _script) return;
    final m = I4Message(me: false, text: '', partial: true, garbled: garbled);
    messages.add(m);
    final words = text.split(' ');
    for (var i = 1; i <= words.length; i++) {
      if (id != _script) return;
      m.text = words.take(i).join(' ');
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 90));
    }
    m.partial = false;
    notifyListeners();
  }

  /// The participant sends (and "speaks") a message.
  void send(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final m = I4Message(me: true, text: t);
    messages.add(m);
    notifyListeners();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      m.spoken = true;
      notifyListeners();
    });
    final c = _current;
    if (!running || c == null) return;
    c.sends.add(t);
    _log('message_sent', {'text': t});
    final low = t.toLowerCase();
    switch (task) {
      case I4Task.reply:
        if (low.contains('nasi goreng') && (low.contains('pedas'))) {
          _finish('success', true);
        } else {
          error('pesan_salah');
        }
      case I4Task.repeat:
        if (RegExp(r'ulang|lagi|tidak (dengar|jelas)|kurang jelas|pelan|maaf\?').hasMatch(low)) {
          _finish('success', true);
        } else {
          error('pesan_salah');
        }
      case I4Task.recall:
        error('bertanya_ke_kasir'); // asking again instead of finding it
    }
  }

  /// Replay of a spoken message (allowed, not an error).
  void replay(I4Message m) {
    m.spoken = false;
    notifyListeners();
    _log('replay', {});
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      m.spoken = true;
      notifyListeners();
    });
  }

  /// Taps on controls that cannot help with the task.
  void error(String kind) {
    final c = _current;
    if (!running || c == null) return;
    c.errors.add(kind);
    _log('task_error', {'kind': kind});
    notifyListeners();
  }

  void track(String event) => _log(event, {});

  /// T3: participant says they found the answer → researcher marks it.
  void foundAnswer() {
    if (!running || task != I4Task.recall) return;
    _stopClock();
    phase = I4Phase.mark;
    notifyListeners();
  }

  void markAnswer(bool correct) {
    if (phase != I4Phase.mark) return;
    if (!correct) _current!.errors.add('jawaban_salah');
    _record(correct ? 'success' : 'wrong', correct);
  }

  void giveUp() => _finish('gave_up', false);

  void _finish(String outcome, bool ok) {
    if (!running) return;
    _stopClock();
    _record(outcome, ok);
  }

  void _stopClock() {
    _timeout?.cancel();
    _current!.timeMs = DateTime.now().difference(_t0!).inMilliseconds;
  }

  void _record(String outcome, bool ok) {
    final c = _current!
      ..outcome = outcome
      ..completed = ok;
    results.add(c);
    _log('task_completed', c.toJson());
    _current = null;
    _t0 = null;
    if (taskIndex < I4Task.values.length - 1) {
      taskIndex++;
      phase = I4Phase.brief;
    } else if (optionIndex < order.length - 1) {
      phase = I4Phase.between;
    } else {
      phase = I4Phase.done;
    }
    _save();
    notifyListeners();
  }

  void nextOption() {
    if (phase != I4Phase.between) return;
    _script++;
    optionIndex++;
    taskIndex = 0;
    messages = [];
    phase = I4Phase.brief;
    notifyListeners();
  }

  // ---------------- Tracking ----------------

  void onTap(Offset pos, Size screen) {
    final c = _current;
    if (!running || c == null) return;
    c.taps++;
    final now = DateTime.now();
    final e = {'x': pos.dx / screen.width, 'y': pos.dy / screen.height};
    _log('ux_tap', e);
    _recent
      ..removeWhere((t) => now.difference(t.t) > const Duration(seconds: 1))
      ..add((t: now, p: pos));
    if (_recent.where((t) => (t.p - pos).distance < 40).length >= 3) {
      c.rage++;
      c.errors.add('rage_click');
      _log('ux_rage_click', e);
      _recent.clear();
    }
  }

  void _log(String event, Map<String, Object?> props) {
    storage.appendEvent('I4-$participantId', {
      'event': event,
      'at': DateTime.now().toIso8601String(),
      'participant': participantId,
      'study': 'iter4',
      'variant': option.id,
      'screen': '/iter4/${option.id}',
      'task': task.id,
      'in_task': running,
      ...props,
    });
  }

  Map<String, Object?> toJson() => {
        'type': 'iter4',
        'participant': participantId,
        'order': order.map((o) => o.id).toList(),
        'started_at': startedAt.toIso8601String(),
        'finished': phase == I4Phase.done,
        'tasks': results.map((r) => r.toJson()).toList(),
      };

  void _save() => storage.saveStudy('I4-$participantId', toJson());

  @override
  void dispose() {
    _script++;
    _timeout?.cancel();
    super.dispose();
  }
}
