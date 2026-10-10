import 'dart:async';
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';

import '../core/models/app_variant.dart';
import '../core/models/message.dart';
import 'ux_models.dart';

/// Where events go. Swap for PostHog, Firebase, a file...
abstract class UxEventSink {
  void send(String event, Map<String, Object?> props);
}

class DebugSink implements UxEventSink {
  @override
  void send(String event, Map<String, Object?> props) => debugPrint('[ux] $event $props');
}

/// The app side of a study: switches variants and builds fresh services for
/// each task. Implemented by SwaranaApp.
abstract class UxHost {
  /// Rebuild the app on [variant] with services for this scenario/form.
  void prepareTask(AppVariant variant, String scenarioId, String form);

  /// Leave study mode (live services, free use).
  void endStudy();

  /// Scripted wait time to exclude from the current task.
  Duration get scriptedWait;

  /// Persist the study (and raw events).
  Future<void> save(String participantId, Map<String, Object?> json);
  Future<void> log(String participantId, Map<String, Object?> event);
}

enum StudyPhase { idle, briefing, running, outcome, seq, sus, tlx, rest, done }

/// The brain of a moderated within-subject study:
/// for each variant block: (briefing → running → outcome → SEQ) per scenario,
/// then SUS → NASA-TLX, then a rest before the next variant.
class UxController extends ChangeNotifier {
  UxController({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final DateTime Function() _now;
  UxEventSink sink = DebugSink();
  UxHost? host;

  StudyConfig? config;
  final List<VariantBlock> blocks = [];
  StudyPhase phase = StudyPhase.idle;
  int blockIndex = 0;
  int taskIndex = 0;
  DateTime? startedAt;
  DateTime? restUntil;

  // Live task tracking
  DateTime? _taskStart;
  Duration? _frozenElapsed;
  Timer? _timeout;
  bool _autoDone = false;
  final List<String> _path = [];
  int _taps = 0;
  int _rage = 0;
  final List<({DateTime time, Offset pos})> _recentTaps = [];
  final Map<String, int> _mix = {};
  final List<Map<String, Object?>> _messages = [];
  String _route = '/';

  TaskResult? pending;
  bool _aborted = false;

  bool get inStudy => phase != StudyPhase.idle && phase != StudyPhase.done;
  bool get isRunning => phase == StudyPhase.running;
  AppVariant? get variant => config == null ? null : config!.order[blockIndex];
  List<String> get scenarios => config?.scenarioOrder() ?? const [];
  String? get scenarioId => taskIndex < scenarios.length ? scenarios[taskIndex] : null;
  String get form => config?.formFor(blockIndex) ?? 'A';
  int get taskNumber => taskIndex + 1;
  Duration get elapsed => _frozenElapsed ??
      (_taskStart == null ? Duration.zero : _now().difference(_taskStart!));

  // ---------------- Study lifecycle ----------------

  void startStudy(StudyConfig c) {
    config = c;
    blocks
      ..clear()
      ..addAll(c.order.map(VariantBlock.new));
    blockIndex = 0;
    taskIndex = 0;
    startedAt = _now();
    _emit('study_started', c.toJson());
    _toBriefing();
  }

  /// Continue an unfinished study from its saved JSON (restarts current task).
  void resume(Map<String, Object?> json) {
    config = StudyConfig.fromJson((json['config'] as Map).cast());
    blocks
      ..clear()
      ..addAll((json['blocks'] as List).map((e) => VariantBlock.fromJson((e as Map).cast())));
    startedAt = DateTime.tryParse(json['started_at'] as String? ?? '') ?? _now();
    final cursor = (json['cursor'] as Map).cast<String, Object?>();
    blockIndex = (cursor['block'] as num).toInt();
    taskIndex = (cursor['task'] as num).toInt();
    final saved = StudyPhase.values.byName(cursor['phase'] as String);
    _emit('study_resumed', {'phase': saved.name});
    switch (saved) {
      case StudyPhase.sus || StudyPhase.tlx || StudyPhase.rest:
        // Show the variant the questionnaire is about.
        host?.prepareTask(variant!, scenarios.last, form);
        if (saved == StudyPhase.rest) {
          final until = DateTime.tryParse(json['rest_until'] as String? ?? '');
          restUntil = until ?? _now();
        }
        _set(saved);
      default:
        _toBriefing();
    }
  }

  void abortStudy() {
    _timeout?.cancel();
    _aborted = true;
    _emit('study_aborted', {});
    _save();
    _aborted = false;
    _reset();
    host?.endStudy();
  }

  void _reset() {
    phase = StudyPhase.idle;
    config = null;
    blocks.clear();
    pending = null;
    notifyListeners();
  }

  void _toBriefing() {
    host?.prepareTask(variant!, scenarioId!, form);
    _set(StudyPhase.briefing);
  }

  void startTask() {
    if (phase != StudyPhase.briefing) return;
    _taskStart = _now();
    _frozenElapsed = null;
    _autoDone = false;
    _path
      ..clear()
      ..add(_route);
    _taps = 0;
    _rage = 0;
    _recentTaps.clear();
    _mix.clear();
    _messages.clear();
    _timeout?.cancel();
    _timeout = Timer(config!.timeLimit, () => endTask(TaskOutcome.timedOut));
    _emit('task_started', {'form': form});
    _set(StudyPhase.running);
  }

  /// The scripted partner finished, or the app reached the goal. Only a hint:
  /// the researcher still confirms the outcome.
  void signal(String name) {
    _emit('ux_signal', {'signal': name});
    if (isRunning && name == 'done') {
      _autoDone = true;
      endTask(null);
    }
  }

  /// Stops the clock and asks the researcher to confirm. [hint] preselects.
  void endTask(TaskOutcome? hint) {
    if (!isRunning) return;
    _timeout?.cancel();
    final waited = host?.scriptedWait ?? Duration.zero;
    final raw = elapsed;
    _frozenElapsed = raw;
    pending = TaskResult(
      scenarioId: scenarioId!,
      form: form,
      variant: variant!,
      outcome: hint ?? (_autoDone ? TaskOutcome.success : TaskOutcome.fail),
      autoDetected: _autoDone,
      // Raw active time. Scripted waiting is recorded separately, not
      // subtracted: in v3 it includes the mic re-tap cost the study compares.
      duration: raw,
      waited: waited,
      block: blockIndex,
      position: taskIndex,
      path: List.of(_path),
      taps: _taps,
      rageClicks: _rage,
      inputMix: Map.of(_mix),
      messages: List.of(_messages),
    );
    _emit('task_ended', {'hint': pending!.outcome.name, 'raw_ms': raw.inMilliseconds});
    _set(StudyPhase.outcome);
  }

  void confirmOutcome(TaskOutcome outcome) {
    final p = pending;
    if (p == null || phase != StudyPhase.outcome) return;
    p.outcome = outcome;
    _emit('task_outcome', {'outcome': outcome.name});
    _set(StudyPhase.seq);
  }

  void submitSeq(int ease) {
    final p = pending;
    if (p == null || phase != StudyPhase.seq) return;
    p.seq = ease;
    blocks[blockIndex].tasks.add(p);
    _emit('task_completed', p.toJson());
    pending = null;
    taskIndex++;
    if (taskIndex < scenarios.length) {
      _toBriefing();
    } else {
      _set(StudyPhase.sus);
    }
  }

  void submitSus(List<int> answers, double score) {
    blocks[blockIndex]
      ..susAnswers = answers
      ..sus = score;
    _emit('sus_submitted', {'sus': score});
    _set(StudyPhase.tlx);
  }

  void submitTlx(Map<String, int> values, double raw) {
    blocks[blockIndex]
      ..tlx = values
      ..tlxRaw = raw;
    _emit('tlx_submitted', {'tlx_raw': raw});
    if (blockIndex + 1 < blocks.length) {
      restUntil = _now().add(config!.breakDuration);
      _set(StudyPhase.rest);
    } else {
      _emit('study_completed', {});
      _set(StudyPhase.done);
    }
  }

  void finishRest() {
    if (phase != StudyPhase.rest) return;
    blockIndex++;
    taskIndex = 0;
    _toBriefing();
  }

  void closeDone() {
    _reset();
    host?.endStudy();
  }

  void _set(StudyPhase p) {
    phase = p;
    _save();
    notifyListeners();
  }

  // ---------------- Tracking inputs ----------------

  void onRoute(String route, {bool pop = false}) {
    _route = route;
    _emit('ux_screen', {'screen': route, 'pop': pop});
    if (isRunning) _path.add(pop ? '<$route' : route);
  }

  void onTap(Offset pos, Size screen) {
    if (!isRunning) return;
    final now = _now();
    _taps++;
    _emit('ux_tap', {'x': pos.dx / screen.width, 'y': pos.dy / screen.height, 'screen': _route});
    // Rage click: 3+ taps within 1 s inside a ~40 px radius.
    _recentTaps
      ..removeWhere((t) => now.difference(t.time) > const Duration(seconds: 1))
      ..add((time: now, pos: pos));
    if (_recentTaps.where((t) => (t.pos - pos).distance < 40).length >= 3) {
      _rage++;
      _emit('ux_rage_click', {'x': pos.dx / screen.width, 'y': pos.dy / screen.height, 'screen': _route});
      _recentTaps.clear();
    }
  }

  /// A message the user sent, with where its characters came from.
  void messageSent(String text, Composition c, {MessageSource? override}) {
    final bucket = mixKey(override ?? c.majority);
    _emit('message_sent', {'bucket': bucket, 'composition': c.toJson(), 'length': text.length});
    if (!isRunning) return;
    _mix[bucket] = (_mix[bucket] ?? 0) + 1;
    _messages.add({'bucket': bucket, 'composition': c.toJson(), 'text': text, 'at_ms': elapsed.inMilliseconds});
  }

  /// Any other noteworthy UI event (listen started, simplify used...).
  void track(String event, [Map<String, Object?> props = const {}]) => _emit(event, props);

  void _emit(String name, Map<String, Object?> props) {
    final c = config;
    final e = {
      'event': name,
      'at': _now().toIso8601String(),
      'participant': c?.participantId,
      'variant': variant?.name,
      'order_position': c == null ? null : blockIndex + 1,
      'scenario': inStudy ? scenarioId : null,
      'in_task': isRunning,
      'elapsed_ms': elapsed.inMilliseconds,
      ...props,
    };
    sink.send(name, e);
    if (c != null) host?.log(c.participantId, e);
  }

  Map<String, Object?> toJson() => {
        'config': config?.toJson(),
        'started_at': startedAt?.toIso8601String(),
        'finished': phase == StudyPhase.done,
        'aborted': _aborted,
        'rest_until': restUntil?.toIso8601String(),
        'cursor': {'block': blockIndex, 'task': taskIndex, 'phase': phase.name},
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  void _save() {
    final c = config;
    if (c != null) host?.save(c.participantId, toJson());
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }
}
