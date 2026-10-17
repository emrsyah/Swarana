import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';

import '../core/services/llm_service.dart';
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
  reply('T1', 'Balas'),
  repeat('T2', 'Minta ulang'),
  recall('T3', 'Ingat');

  const I4Task(this.id, this.title);
  final String id;
  final String title;
}

/// Content set per option position, so later options don't benefit from
/// already knowing the order or the total (practice effect).
class I4Content {
  const I4Content({
    required this.order,
    required this.dish,
    required this.modifier,
    required this.total,
    required this.totalDigits,
    required this.drink,
    required this.followUp,
  });

  /// Cashier's follow-up when only the dish was ordered.
  final String followUp;

  /// What the participant must order, as shown in the briefing.
  final String order;
  final String dish;

  /// The ingredient that must be negated ("pedas", "sambal"...).
  final String modifier;
  final String total;
  final String totalDigits;
  final String drink;

  static const sets = [
    I4Content(order: 'nasi goreng yang tidak pedas', dish: 'nasi goreng', modifier: 'pedas',
        total: 'dua puluh lima ribu', totalDigits: 'Rp25.000', drink: 'es teh atau air putih',
        followUp: 'Nasi gorengnya pedas atau tidak?'),
    I4Content(order: 'mie ayam tanpa sambal', dish: 'mie ayam', modifier: 'sambal',
        total: 'delapan belas ribu', totalDigits: 'Rp18.000', drink: 'teh hangat atau jeruk',
        followUp: 'Mie ayamnya pakai sambal?'),
    I4Content(order: 'bakso tanpa seledri', dish: 'bakso', modifier: 'seledri',
        total: 'tiga puluh dua ribu', totalDigits: 'Rp32.000', drink: 'es jeruk atau air mineral',
        followUp: 'Baksonya pakai seledri?'),
  ];
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
  I4TaskResult(this.option, this.task, this.contentIndex);
  final I4Option option;
  final I4Task task;
  final int contentIndex;
  bool completed = false;
  String outcome = 'running'; // success | wrong | gave_up | timed_out | aborted

  /// The app saw the goal met (rule check or AI) and ended the task itself.
  bool autoDetected = false;

  /// Ended by the researcher (Selesai → Berhasil/Gagal).
  bool manual = false;
  int timeMs = 0;
  int taps = 0;
  int rage = 0;
  final List<String> errors = [];
  final List<String> sends = [];

  Map<String, Object?> toJson() => {
        'option': option.id,
        'task': task.id,
        'content_set': contentIndex,
        'completed': completed,
        'outcome': outcome,
        'auto_detected': autoDetected,
        'manual': manual,
        'time_ms': timeMs,
        'errors': errors.length,
        'error_kinds': errors,
        'taps': taps,
        'rage_clicks': rage,
        'sends': sends,
      };
}

class Iter4Controller extends ChangeNotifier {
  Iter4Controller({required this.participantId, required this.storage, this.llm}) {
    final n = int.tryParse(participantId.replaceAll(RegExp(r'\D'), '')) ?? participantId.length;
    const squares = [
      [0, 1, 2],
      [1, 2, 0],
      [2, 0, 1],
    ];
    order = [for (final i in squares[n % 3]) I4Option.values[i]];
    startedAt = DateTime.now();
    // A re-run of the same ID starts a fresh event log (heatmap stays clean).
    storage.writeEvents('I4-$participantId', const []);
  }

  static const timeLimit = Duration(minutes: 3);

  final String participantId;
  final Storage storage;

  /// Cashier replies and goal check; null → rule-based replies only.
  final OpenRouterLlm? llm;
  late final List<I4Option> order;
  late final DateTime startedAt;

  int optionIndex = 0;
  int taskIndex = 0;
  I4Phase phase = I4Phase.brief;
  bool aborted = false;
  final List<I4TaskResult> results = [];
  List<I4Message> messages = [];

  I4TaskResult? _current;
  DateTime? _t0;
  Timer? _timeout;
  int _script = 0; // bumps cancel any running script
  bool _repeatReady = false; // T2: garbled line fully shown
  bool _disposed = false;
  final List<({DateTime t, Offset p})> _recent = [];

  int _turn = 0; // latest participant message; older cashier replies are dropped

  I4TaskResult? get current => _current;
  I4Option get option => order[optionIndex];
  I4Task get task => I4Task.values[taskIndex];

  /// Content rotates with the option's position in the session.
  I4Content get content => I4Content.sets[optionIndex];
  bool get running => phase == I4Phase.running;
  int get elapsedSec => _t0 == null ? 0 : DateTime.now().difference(_t0!).inSeconds;

  I4Message? get lastPartner => messages.where((m) => !m.me).lastOrNull;
  I4Message? get lastMine => messages.where((m) => m.me).lastOrNull;

  String get instruction => switch (task) {
        I4Task.reply => 'Pesan ${content.order} ke kasir.',
        I4Task.repeat => 'Tunggu ucapan kasir. Jika ada yang tidak jelas, minta kasir mengulang ucapannya.',
        I4Task.recall => 'Berapa total harga yang tadi disebut kasir? Cari di aplikasi, lalu sebutkan ke peneliti.',
      };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ---------------- Flow ----------------

  void startTask() {
    if (phase != I4Phase.brief) return;
    _current = I4TaskResult(option, task, optionIndex);
    _t0 = DateTime.now();
    _timeout?.cancel();
    _timeout = Timer(timeLimit, () => _finish('timed_out', false));
    _repeatReady = false;
    phase = I4Phase.running;
    _notify();
    _log('task_started', {});
    _runScript();
  }

  /// Scripted partner lines for the current task (same structure for every
  /// option, content varies by position).
  Future<void> _runScript() async {
    final id = ++_script;
    final k = content;
    switch (task) {
      case I4Task.reply:
        await _say(id, 'Selamat siang! Mau pesan apa?');
      case I4Task.repeat:
        await _say(id, 'Baik, ${k.dish} ya.');
        await _say(id, 'Totalnya ${k.total} ya.');
        await _say(id, 'Minumnya mau … (suara tidak jelas) …', garbled: true);
        if (id == _script) _repeatReady = true;
      case I4Task.recall:
        await _say(id, 'Baik, pesanannya saya catat.');
        await _say(id, 'Silakan ditunggu di meja nomor tujuh ya.');
    }
  }

  Future<void> _say(int id, String text, {bool garbled = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (id != _script || _disposed) return;
    final m = I4Message(me: false, text: '', partial: true, garbled: garbled);
    messages.add(m);
    await _stream(id, m, text);
  }

  /// Shows [text] word by word in [m], like live captions.
  Future<void> _stream(int id, I4Message m, String text) async {
    final words = text.split(' ');
    for (var i = 1; i <= words.length; i++) {
      if (id != _script || _disposed) {
        m.partial = false; // never leave a half line styled as "still speaking"
        return;
      }
      m.text = words.take(i).join(' ');
      _notify();
      await Future<void>.delayed(const Duration(milliseconds: 90));
    }
    m.partial = false;
    _notify();
  }

  bool _orderOk(String low) {
    final k = content;
    if (!low.contains(k.dish)) return false;
    if (RegExp('(tidak|gak|nggak|ga|jangan) mau ${k.dish}').hasMatch(low)) return false;
    return RegExp('(tidak|gak|nggak|ga|jangan|tanpa|no)\\s+(pakai\\s+|terlalu\\s+|usah\\s+)?${k.modifier}').hasMatch(low);
  }

  static final _repeatRe = RegExp(
      r'ulang|ulangi|sekali lagi|tidak (dengar|jelas|paham)|kurang jelas|pelan|^apa\??$|^maaf\??$|^hah\??$');

  /// The participant sends (and "speaks") a message.
  void send(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final m = I4Message(me: true, text: t);
    messages.add(m);
    _notify();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      m.spoken = true;
      _notify();
    });
    final c = _current;
    if (!running || c == null) return;
    c.sends.add(t);
    _log('message_sent', {'text': t});
    final low = t.toLowerCase();
    final bool ruleOk;
    switch (task) {
      case I4Task.reply:
        ruleOk = _orderOk(low);
        if (!ruleOk) error('pesan_salah');
      case I4Task.repeat:
        if (!_repeatReady) {
          // The scripted lines are still coming; no reply, keep the script.
          error('terlalu_cepat');
          return;
        }
        ruleOk = _repeatRe.hasMatch(low);
        if (!ruleOk) error('pesan_salah');
      case I4Task.recall:
        ruleOk = false;
        error('bertanya_ke_kasir'); // asking again instead of finding it
    }
    _respond(c, ++_turn, low, ruleOk);
  }

  /// The cashier always answers (AI when available, rules otherwise), so the
  /// conversation never looks stuck. If the goal is met (rule check or AI),
  /// the task ends after the reply has been shown.
  Future<void> _respond(I4TaskResult c, int turn, String low, bool ruleOk) async {
    final id = ++_script; // stop any scripted line still being typed
    final m = I4Message(me: false, text: '…', partial: true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (turn != _turn || _current != c || _disposed) return;
    messages.add(m);
    _notify();
    var reply = _ruleReply(low, ruleOk);
    var met = ruleOk;
    if (llm != null) {
      try {
        final ai = await _aiTurn();
        reply = ai.reply.isEmpty ? reply : ai.reply;
        met = ruleOk || (ai.met && task != I4Task.recall);
        _log('ai_turn', {'goal_met': ai.met});
      } on Exception catch (e) {
        _log('ai_failed', {'error': '$e'});
      }
    }
    if (turn != _turn || _current != c || _disposed) {
      messages.remove(m);
      _notify();
      return;
    }
    if (id == _script) await _stream(id, m, reply);
    m.partial = false;
    _notify();
    if (!met) return;
    c.autoDetected = true;
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (_current == c && turn == _turn) _finish('success', true);
  }

  String _ruleReply(String low, bool ok) {
    final k = content;
    return switch (task) {
      I4Task.reply => ok
          ? 'Baik, ${k.order} ya.'
          : low.contains(k.dish)
              ? k.followUp
              : 'Maaf, mau pesan apa?',
      I4Task.repeat => ok ? 'Oh maaf. Minumnya mau ${k.drink}?' : 'Iya? Minumnya mau apa?',
      I4Task.recall => 'Tadi sudah saya sebutkan ya, coba dicek lagi.',
    };
  }

  String get _goal {
    final k = content;
    return switch (task) {
      I4Task.reply => 'Pelanggan harus memesan ${k.order}. Tercapai hanya bila pelanggan jelas '
          'menyebut ${k.dish} DAN bahwa ia tidak mau ${k.modifier}. Jika baru menyebut ${k.dish} saja, '
          'tanyakan: "${k.followUp}". Jika tercapai, konfirmasi pesanannya. '
          'Jangan menyebut harga.',
      I4Task.repeat => 'Ucapan terakhirmu tadi tidak jelas terdengar. Pelanggan harus meminta kamu '
          'mengulang (misalnya "bisa ulangi?", "maaf?", "apa?", "tidak jelas"). Tercapai bila pelanggan '
          'meminta diulang; lalu ulangi dengan jelas: "Minumnya mau ${k.drink}?". '
          'Jika pelanggan menjawab hal lain, jawab singkat lalu tanyakan lagi minumnya mau apa.',
      I4Task.recall => 'Pelanggan seharusnya mencari sendiri total harga di aplikasinya. '
          'Jika ia menanyakan total, jawab: "Tadi sudah saya sebutkan ya, coba dicek lagi." '
          'Jangan menyebut angka total. Tercapai selalu false.',
    };
  }

  Future<({String reply, bool met})> _aiTurn() async {
    final k = content;
    final system = 'Kamu berperan sebagai kasir warung makan di Indonesia dalam uji coba aplikasi. '
        'Pelanggan adalah Teman Tuli yang mengetik pesan lewat aplikasi. Balas seperti kasir sungguhan: '
        'ramah, bahasa sehari-hari, maksimal 12 kata.\n'
        'Fakta: pesanan ${k.dish}, total harga ${k.total}, pilihan minum ${k.drink}, meja nomor tujuh.\n'
        'Tugas pelanggan: $_goal\n'
        'Jawab HANYA dengan JSON satu baris: {"balasan": "...", "tercapai": true/false}.';
    final convo = messages
        .where((m) => !m.partial && m.text.isNotEmpty)
        .map((m) => '${m.me ? 'Pelanggan' : 'Kasir'}: ${m.garbled ? 'Minumnya mau … (tidak jelas)' : m.text}')
        .join('\n');
    final out = await llm!.askWithSystem(system, 'Percakapan:\n$convo', temperature: 0.3);
    final js = RegExp(r'\{[\s\S]*\}').firstMatch(out)?.group(0);
    if (js == null) throw LlmException('no json');
    final j = jsonDecode(js) as Map<String, dynamic>;
    return (reply: '${j['balasan'] ?? ''}'.trim(), met: j['tercapai'] == true);
  }

  /// Replay of a spoken message (allowed, not an error).
  void replay(I4Message m) {
    m.spoken = false;
    _notify();
    _log('replay', {});
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      m.spoken = true;
      _notify();
    });
  }

  /// Taps on controls that cannot help with the task.
  void error(String kind) {
    final c = _current;
    if (!running || c == null) return;
    c.errors.add(kind);
    _log('task_error', {'kind': kind});
    _notify();
  }

  void track(String event) => _log(event, {});

  /// Stops the clock and asks the researcher to judge the task: used for T3
  /// ("Sudah ketemu") and whenever the researcher ends a task by hand.
  void endManually() {
    if (!running) return;
    _turn++; // drop any pending cashier reply / auto-finish
    _script++;
    _stopClock();
    _current!.manual = true;
    phase = I4Phase.mark;
    _log('task_end_manual', {});
    _notify();
  }

  void markAnswer(bool correct) {
    if (phase != I4Phase.mark) return;
    if (!correct) _current!.errors.add(task == I4Task.recall ? 'jawaban_salah' : 'tujuan_tidak_tercapai');
    _record(correct ? 'success' : 'wrong', correct);
  }

  void giveUp() => _finish('gave_up', false);

  /// Researcher ends the whole session early.
  void abort() {
    _script++;
    _timeout?.cancel();
    final c = _current;
    if (c != null) {
      c
        ..outcome = 'aborted'
        ..timeMs = _t0 == null ? 0 : DateTime.now().difference(_t0!).inMilliseconds;
      results.add(c);
      _current = null;
    }
    aborted = true;
    phase = I4Phase.done;
    _save();
    _notify();
  }

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
    _notify();
  }

  void nextOption() {
    if (phase != I4Phase.between) return;
    _script++;
    optionIndex++;
    taskIndex = 0;
    messages = [];
    phase = I4Phase.brief;
    _notify();
  }

  // ---------------- Tracking ----------------

  /// Called on pointer-up for taps only (scrolls/drags are filtered out).
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
      c.rage++; // reported separately from errors
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
      'run': startedAt.toIso8601String(),
      'variant': option.id,
      'screen': '/iter4/${option.id}',
      'task': task.id,
      'content_set': optionIndex,
      'in_task': running,
      ...props,
    });
  }

  Map<String, Object?> toJson() => {
        'type': 'iter4',
        'participant': participantId,
        'order': order.map((o) => o.id).toList(),
        'started_at': startedAt.toIso8601String(),
        'finished': phase == I4Phase.done && !aborted,
        'aborted': aborted,
        'tasks': results.map((r) => r.toJson()).toList(),
      };

  void _save() => storage.saveStudy('I4-$participantId', toJson());

  @override
  void dispose() {
    _disposed = true;
    _script++;
    _timeout?.cancel();
    super.dispose();
  }
}
