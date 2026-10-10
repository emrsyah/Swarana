import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:swarana/core/models/app_variant.dart';
import 'package:swarana/core/models/message.dart';
import 'package:swarana/ux_kit/ux_controller.dart';
import 'package:swarana/ux_kit/ux_models.dart';

class _Sink implements UxEventSink {
  final events = <String>[];
  @override
  void send(String event, Map<String, Object?> props) => events.add(event);
}

class _Host implements UxHost {
  final prepared = <String>[];
  Duration wait = Duration.zero;
  @override
  void prepareTask(AppVariant v, String s, String f) => prepared.add('${v.name}/$s/$f');
  @override
  void endStudy() {}
  @override
  Duration get scriptedWait => wait;
  @override
  Future<void> save(String p, Map<String, Object?> j) async {}
  @override
  Future<void> log(String p, Map<String, Object?> e) async {}
}

void main() {
  late DateTime now;
  late UxController c;
  late _Sink sink;
  late _Host host;
  const screen = Size(400, 800);

  setUp(() {
    now = DateTime(2026);
    sink = _Sink();
    host = _Host();
    c = UxController(clock: () => now)
      ..sink = sink
      ..host = host;
  });

  StudyConfig cfg(String pid) => StudyConfig(
        participantId: pid,
        order: [AppVariant.v5Chat, AppVariant.v3Board],
        scenarioIds: ['warung', 'bank', 'cs'],
        scripted: true,
      );

  test('scenario order and forms rotate by participant', () {
    expect(cfg('P01').scenarioOrder(), ['bank', 'cs', 'warung']);
    expect(cfg('P03').scenarioOrder(), ['warung', 'bank', 'cs']);
    // Form order follows bit 1, variant order bit 0: not confounded.
    expect([for (final p in ['P00', 'P01', 'P02', 'P03']) cfg(p).formFor(0)], ['A', 'A', 'B', 'B']);
    expect(cfg('P02').formFor(1), 'A');
  });

  test('rage clicks counted only while a task runs', () {
    c.startStudy(cfg('P03'));
    for (var i = 0; i < 3; i++) {
      c.onTap(const Offset(100, 100), screen);
    }
    expect(sink.events.where((e) => e == 'ux_rage_click'), isEmpty);

    c.startTask();
    for (var i = 0; i < 3; i++) {
      now = now.add(const Duration(milliseconds: 200));
      c.onTap(const Offset(100, 100), screen);
    }
    c.endTask(TaskOutcome.fail);
    expect(c.pending!.rageClicks, 1);
    expect(c.pending!.taps, 3);
  });

  test('time is raw, scripted wait recorded separately; auto signal is a hint only', () {
    c.startStudy(cfg('P03'));
    c.startTask();
    now = now.add(const Duration(seconds: 40));
    host.wait = const Duration(seconds: 10);
    c.signal('done');
    expect(c.phase, StudyPhase.outcome);
    expect(c.pending!.duration, const Duration(seconds: 40));
    expect(c.pending!.waited, const Duration(seconds: 10));
    expect(c.pending!.outcome, TaskOutcome.success);
    expect(c.pending!.autoDetected, isTrue);

    c.confirmOutcome(TaskOutcome.partial);
    c.submitSeq(5);
    expect(c.blocks.first.tasks.single.outcome, TaskOutcome.partial);
    expect(c.phase, StudyPhase.briefing);
    expect(host.prepared, ['v5Chat/warung/B', 'v5Chat/bank/B']);
  });

  test('input mix buckets by majority source', () {
    c.startStudy(cfg('P03'));
    c.startTask();
    c.messageSent('halo', Composition(typed: 4));
    c.messageSent('mi instan dua', Composition(board: 10, typed: 3));
    c.messageSent('Ini uangnya', Composition(suggestion: 11));
    c.endTask(TaskOutcome.success);
    expect(c.pending!.inputMix, {'keyboard': 1, 'board': 1, 'suggestion': 1});
  });

  test('full study walks blocks, questionnaires and rest', () {
    final s = StudyConfig(
        participantId: 'P00',
        order: [AppVariant.v3Board, AppVariant.v5Chat],
        scenarioIds: ['warung'],
        scripted: true);
    c.startStudy(s);
    for (var b = 0; b < 2; b++) {
      c.startTask();
      c.endTask(TaskOutcome.success);
      c.confirmOutcome(TaskOutcome.success);
      c.submitSeq(6);
      expect(c.phase, StudyPhase.sus);
      c.submitSus(List.filled(10, 3), 50);
      c.submitTlx({'mental': 40}, 40);
      if (b == 0) {
        expect(c.phase, StudyPhase.rest);
        c.finishRest();
      }
    }
    expect(c.phase, StudyPhase.done);
    expect(host.prepared, ['v3Board/warung/A', 'v5Chat/warung/B']);
  });
}
