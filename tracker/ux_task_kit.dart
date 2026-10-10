// ux_task_kit.dart
// A Maze-style usability testing layer for real Flutter apps.
// Handles: task briefing -> start -> live tracking -> finish -> ease rating.

import 'dart:async';
import 'package:flutter/material.dart';

// ============================================================================
// Models
// ============================================================================

enum TaskOutcome {
  directSuccess, // reached the goal via the expected path
  indirectSuccess, // reached the goal, but wandered
  selfReported, // participant tapped "I'm done" (no auto-detection)
  gaveUp,
  timedOut,
}

class UxTask {
  const UxTask({
    required this.id,
    required this.title,
    required this.instruction,
    this.startRoute,
    this.successRoute,
    this.successSignal,
    this.expectedPath = const [],
    this.timeLimit,
  });

  final String id;
  final String title;
  final String instruction;

  /// The app is reset to this screen when the task starts, so every
  /// participant begins from the same place.
  final String? startRoute;

  /// Task finishes automatically when the user lands on this named route...
  final String? successRoute;

  /// ...or when your app calls UxTestController.instance.signal(name),
  /// e.g. after a booking is confirmed or a form is submitted.
  final String? successSignal;

  /// The ideal sequence of screens. An exact match = direct success.
  final List<String> expectedPath;

  final Duration? timeLimit;
}

class TaskResult {
  TaskResult({
    required this.taskId,
    required this.outcome,
    required this.duration,
    required this.path,
    required this.taps,
    required this.rageClicks,
  });

  final String taskId;
  final TaskOutcome outcome;
  final Duration duration;
  final List<String> path;
  final int taps;
  final int rageClicks;
  int? easeRating; // 1–7 (Single Ease Question)

  bool get success =>
      outcome == TaskOutcome.directSuccess ||
      outcome == TaskOutcome.indirectSuccess;

  Map<String, Object?> toJson() => {
        'task_id': taskId,
        'outcome': outcome.name,
        'success': success,
        'duration_ms': duration.inMilliseconds,
        'path': path,
        'taps': taps,
        'rage_clicks': rageClicks,
        'ease_rating': easeRating,
      };
}

/// Where events go. Swap DebugSink for PostHog, Clarity, Firebase, your API...
abstract class UxEventSink {
  void send(String event, Map<String, Object?> props);
}

class DebugSink implements UxEventSink {
  @override
  void send(String event, Map<String, Object?> props) =>
      debugPrint('[ux] $event $props');
}

// ============================================================================
// Controller — the brain. One per test session.
// ============================================================================

class UxTestController extends ChangeNotifier {
  UxTestController._();
  static final instance = UxTestController._();

  UxEventSink sink = DebugSink();
  GlobalKey<NavigatorState>? navigatorKey;
  String participantId = 'anon';
  List<UxTask> tasks = [];
  final List<TaskResult> results = [];

  int _index = 0;
  DateTime? _startedAt;
  Timer? _timeout;
  String _currentRoute = '/';
  final List<String> _path = [];
  int _taps = 0;
  int _rage = 0;
  final List<({DateTime time, Offset pos})> _recentTaps = [];

  /// Set after a task ends, cleared once the participant rates it.
  TaskResult? awaitingRating;

  UxTask? get currentTask => _index < tasks.length ? tasks[_index] : null;
  int get taskNumber => _index + 1;
  bool get isRunning => _startedAt != null;
  bool get isFinished => tasks.isNotEmpty && _index >= tasks.length;
  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  void configure({
    required List<UxTask> tasks,
    required String participantId,
    GlobalKey<NavigatorState>? navigatorKey,
    UxEventSink? sink,
  }) {
    this.tasks = tasks;
    this.participantId = participantId;
    this.navigatorKey = navigatorKey;
    if (sink != null) this.sink = sink;
    _index = 0;
    results.clear();
    awaitingRating = null;
    _emit('test_started', {'task_count': tasks.length});
    notifyListeners();
  }

  // ---------------- Task lifecycle ----------------

  void startTask() {
    final task = currentTask;
    if (task == null || isRunning) return;

    // Reset the app to the task's start screen (before tracking begins).
    if (task.startRoute != null) {
      navigatorKey?.currentState
          ?.pushNamedAndRemoveUntil(task.startRoute!, (_) => false);
    }

    _startedAt = DateTime.now();
    _path
      ..clear()
      ..add(_currentRoute);
    _taps = 0;
    _rage = 0;
    _recentTaps.clear();

    if (task.timeLimit != null) {
      _timeout = Timer(task.timeLimit!, () => _finish(TaskOutcome.timedOut));
    }

    _emit('task_started', {'task_title': task.title});
    notifyListeners();
  }

  /// Call from your app code when a goal action happens.
  void signal(String name) {
    _emit('ux_signal', {'signal': name});
    if (isRunning && currentTask?.successSignal == name) _finishSuccess();
  }

  void completeManually() => _finish(TaskOutcome.selfReported);
  void giveUp() => _finish(TaskOutcome.gaveUp);

  void submitRating(int ease) {
    final result = awaitingRating;
    if (result == null) return;
    result.easeRating = ease;
    _emit('task_rated', {'ease_rating': ease});
    awaitingRating = null;
    _index++;
    if (isFinished) {
      _emit('test_completed', {
        'successes': results.where((r) => r.success).length,
        'task_count': tasks.length,
      });
    }
    notifyListeners();
  }

  void _finishSuccess() {
    final expected = currentTask!.expectedPath;
    final direct = expected.isEmpty || _sameList(_path, expected);
    _finish(direct ? TaskOutcome.directSuccess : TaskOutcome.indirectSuccess);
  }

  void _finish(TaskOutcome outcome) {
    if (!isRunning) return;
    _timeout?.cancel();
    final result = TaskResult(
      taskId: currentTask!.id,
      outcome: outcome,
      duration: elapsed,
      path: List.of(_path),
      taps: _taps,
      rageClicks: _rage,
    );
    _startedAt = null;
    results.add(result);
    awaitingRating = result;
    _emit('task_completed', result.toJson());
    notifyListeners();
  }

  // ---------------- Tracking inputs ----------------

  void onRoute(String route) {
    _currentRoute = route;
    _emit('ux_screen', {'screen': route});
    if (!isRunning) return;
    _path.add(route);
    if (currentTask?.successRoute == route) _finishSuccess();
  }

  void onTap(Offset pos, Size screen) {
    final now = DateTime.now();
    if (isRunning) _taps++;

    // Normalized 0–1 coords so heatmaps work across screen sizes.
    _emit('ux_tap', {
      'x': pos.dx / screen.width,
      'y': pos.dy / screen.height,
      'screen': _currentRoute,
    });

    // Rage click: 3+ taps within 1s inside a ~40px radius.
    _recentTaps
      ..removeWhere((t) => now.difference(t.time) > const Duration(seconds: 1))
      ..add((time: now, pos: pos));
    final cluster =
        _recentTaps.where((t) => (t.pos - pos).distance < 40).length;
    if (cluster >= 3) {
      if (isRunning) _rage++;
      _emit('ux_rage_click', {
        'x': pos.dx / screen.width,
        'y': pos.dy / screen.height,
        'screen': _currentRoute,
      });
      _recentTaps.clear();
    }
  }

  void _emit(String name, Map<String, Object?> props) {
    sink.send(name, {
      'participant_id': participantId,
      'task_id': currentTask?.id,
      'in_task': isRunning,
      'elapsed_ms': elapsed.inMilliseconds,
      ...props,
    });
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ============================================================================
// Navigator observer — builds the path. Requires named routes.
// ============================================================================

class UxNavigatorObserver extends NavigatorObserver {
  void _report(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null) UxTestController.instance.onRoute(name);
  }

  @override
  void didPush(Route route, Route? previousRoute) => _report(route);
  @override
  void didPop(Route route, Route? previousRoute) => _report(previousRoute);
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) => _report(newRoute);
}

// ============================================================================
// Harness — wrap your app; shows briefing, live task bar, rating, thank-you.
// ============================================================================

class UxTestHarness extends StatefulWidget {
  const UxTestHarness({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  State<UxTestHarness> createState() => _UxTestHarnessState();
}

class _UxTestHarnessState extends State<UxTestHarness> {
  final c = UxTestController.instance;
  Timer? _ticker;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
  }

  void _onChange() {
    _ticker?.cancel();
    if (c.isRunning) {
      _ticker = Timer.periodic(
          const Duration(seconds: 1), (_) => setState(() {}));
    }
    setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final size = MediaQuery.sizeOf(context);
    return Stack(children: [
      Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => c.onTap(e.position, size),
        child: widget.child,
      ),
      if (!_closed && c.tasks.isNotEmpty) _overlay(context),
    ]);
  }

  Widget _overlay(BuildContext context) {
    if (c.awaitingRating != null) return _modal(_ratingCard());
    if (c.isFinished) return _modal(_doneCard());
    if (!c.isRunning) return _modal(_briefCard());
    return _taskBar(context);
  }

  // ---------- Pieces ----------

  Widget _modal(Widget card) => Positioned.fill(
        child: ColoredBox(
          color: Colors.black54,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Material(
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(padding: const EdgeInsets.all(24), child: card),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _briefCard() {
    final t = c.currentTask!;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Task ${c.taskNumber} of ${c.tasks.length}', style: text.labelMedium),
        const SizedBox(height: 8),
        Text(t.title, style: text.titleLarge),
        const SizedBox(height: 8),
        Text(t.instruction, style: text.bodyMedium),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
              onPressed: c.startTask, child: const Text('Start task')),
        ),
      ],
    );
  }

  Widget _taskBar(BuildContext context) {
    final t = c.currentTask!;
    final secs = c.elapsed.inSeconds;
    final clock =
        '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 12,
      right: 12,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          child: Row(children: [
            Expanded(
              child: Text(t.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text(clock),
            TextButton(
                onPressed: c.completeManually, child: const Text("I'm done")),
            TextButton(onPressed: c.giveUp, child: const Text('Give up')),
          ]),
        ),
      ),
    );
  }

  Widget _ratingCard() {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('How easy was that task?', style: text.titleMedium),
        const SizedBox(height: 4),
        Text('1 = very hard, 7 = very easy', style: text.bodySmall),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 1; i <= 7; i++)
              OutlinedButton(
                onPressed: () => c.submitRating(i),
                child: Text('$i'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _doneCard() {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('That was the last task', style: text.titleLarge),
        const SizedBox(height: 8),
        const Text('Thanks for testing. You can close this and keep exploring.'),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => setState(() => _closed = true),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
