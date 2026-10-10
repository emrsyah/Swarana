import '../core/models/app_variant.dart';
import '../core/models/message.dart';

/// Researcher-judged outcome (auto-detection is only a hint).
enum TaskOutcome { success, partial, fail, gaveUp, timedOut }

extension TaskOutcomeLabel on TaskOutcome {
  String get label => switch (this) {
        TaskOutcome.success => 'Berhasil',
        TaskOutcome.partial => 'Sebagian',
        TaskOutcome.fail => 'Gagal',
        TaskOutcome.gaveUp => 'Menyerah',
        TaskOutcome.timedOut => 'Waktu habis',
      };
  bool get isSuccess => this == TaskOutcome.success;
}

class StudyConfig {
  StudyConfig({
    required this.participantId,
    required this.order,
    required this.scenarioIds,
    required this.scripted,
    this.breakDuration = const Duration(minutes: 15),
    this.timeLimit = const Duration(minutes: 5),
  });

  final String participantId;
  final List<AppVariant> order;
  final List<String> scenarioIds;
  final bool scripted;
  final Duration breakDuration;
  final Duration timeLimit;

  /// Numeric part of the participant id, used to rotate scenarios and forms.
  int get index => int.tryParse(participantId.replaceAll(RegExp(r'\D'), '')) ??
      participantId.codeUnits.fold(0, (a, b) => a + b);

  /// Latin-square rotation of scenario order for this participant.
  List<String> scenarioOrder() {
    final n = scenarioIds.length;
    if (n == 0) return const [];
    final shift = index % n;
    return [for (var i = 0; i < n; i++) scenarioIds[(i + shift) % n]];
  }

  /// Parallel form for a block. Uses bit 1 of the index while variant order
  /// is suggested from bit 0, so form and variant are not confounded:
  /// P0 A→B, P1 A→B, P2 B→A, P3 B→A, ...
  String formFor(int block) => ((index ~/ 2) + block).isEven ? 'A' : 'B';

  Map<String, Object?> toJson() => {
        'participant': participantId,
        'order': order.map((v) => v.name).toList(),
        'scenarios': scenarioIds,
        'scripted': scripted,
        'breakSeconds': breakDuration.inSeconds,
        'timeLimitSeconds': timeLimit.inSeconds,
      };

  factory StudyConfig.fromJson(Map<String, Object?> j) => StudyConfig(
        participantId: j['participant'] as String,
        order: (j['order'] as List).map((e) => AppVariant.values.byName(e as String)).toList(),
        scenarioIds: (j['scenarios'] as List).cast<String>(),
        scripted: j['scripted'] == true,
        breakDuration: Duration(seconds: (j['breakSeconds'] as num?)?.toInt() ?? 900),
        timeLimit: Duration(seconds: (j['timeLimitSeconds'] as num?)?.toInt() ?? 300),
      );
}

class TaskResult {
  TaskResult({
    required this.scenarioId,
    required this.form,
    required this.variant,
    required this.outcome,
    required this.autoDetected,
    required this.duration,
    required this.waited,
    this.block = 0,
    this.position = 0,
    required this.path,
    required this.taps,
    required this.rageClicks,
    required this.inputMix,
    required this.messages,
    this.seq,
  });

  final String scenarioId;
  final String form;
  final AppVariant variant;
  TaskOutcome outcome;
  final bool autoDetected;

  /// Active time: start tap to end, minus scripted waiting.
  final Duration duration;
  final Duration waited;

  /// 0 = first variant block; position within the block (order effects).
  final int block;
  final int position;
  final List<String> path;
  final int taps;
  final int rageClicks;

  /// Sent messages per majority source (keyboard / suggestion / board).
  final Map<String, int> inputMix;
  final List<Map<String, Object?>> messages;
  int? seq;

  Map<String, Object?> toJson() => {
        'scenario': scenarioId,
        'form': form,
        'variant': variant.name,
        'outcome': outcome.name,
        'success': outcome.isSuccess,
        'auto_detected': autoDetected,
        'duration_ms': duration.inMilliseconds,
        'waited_ms': waited.inMilliseconds,
        'block_index': block,
        'task_position': position,
        'path': path,
        'taps': taps,
        'rage_clicks': rageClicks,
        'input_mix': inputMix,
        'messages': messages,
        'seq': seq,
      };

  factory TaskResult.fromJson(Map<String, Object?> j) => TaskResult(
        scenarioId: j['scenario'] as String,
        form: j['form'] as String,
        variant: AppVariant.values.byName(j['variant'] as String),
        outcome: TaskOutcome.values.byName(j['outcome'] as String),
        autoDetected: j['auto_detected'] == true,
        duration: Duration(milliseconds: (j['duration_ms'] as num).toInt()),
        waited: Duration(milliseconds: (j['waited_ms'] as num?)?.toInt() ?? 0),
        block: (j['block_index'] as num?)?.toInt() ?? 0,
        position: (j['task_position'] as num?)?.toInt() ?? 0,
        path: (j['path'] as List).cast<String>(),
        taps: (j['taps'] as num).toInt(),
        rageClicks: (j['rage_clicks'] as num).toInt(),
        inputMix: (j['input_mix'] as Map).map((k, v) => MapEntry(k as String, (v as num).toInt())),
        messages: (j['messages'] as List).map((e) => (e as Map).cast<String, Object?>()).toList(),
        seq: (j['seq'] as num?)?.toInt(),
      );
}

class VariantBlock {
  VariantBlock(this.variant, {List<TaskResult>? tasks}) : tasks = tasks ?? [];

  final AppVariant variant;
  final List<TaskResult> tasks;
  List<int>? susAnswers;
  double? sus;
  Map<String, int>? tlx;
  double? tlxRaw;

  Map<String, Object?> toJson() => {
        'variant': variant.name,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'sus_answers': susAnswers,
        'sus': sus,
        'tlx': tlx,
        'tlx_raw': tlxRaw,
      };

  factory VariantBlock.fromJson(Map<String, Object?> j) => VariantBlock(
        AppVariant.values.byName(j['variant'] as String),
        tasks: (j['tasks'] as List).map((e) => TaskResult.fromJson((e as Map).cast())).toList(),
      )
        ..susAnswers = (j['sus_answers'] as List?)?.cast<int>()
        ..sus = (j['sus'] as num?)?.toDouble()
        ..tlx = (j['tlx'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt()))
        ..tlxRaw = (j['tlx_raw'] as num?)?.toDouble();
}

/// Bucket name used in the input-mix metric.
String mixKey(MessageSource s) => switch (s) {
      MessageSource.board => 'board',
      MessageSource.suggestion => 'suggestion',
      MessageSource.quickPhrase => 'quick_phrase',
      _ => 'keyboard',
    };
