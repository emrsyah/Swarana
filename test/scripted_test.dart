import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swarana/core/models/scenario.dart';
import 'package:swarana/core/services/scripted.dart';
import 'package:swarana/core/services/stt_service.dart';

void main() {
  final scenario = Scenario.parse(File('assets/scenarios/warung.json').readAsStringSync());

  test('all scenario files parse and both forms have the same interaction count', () {
    for (final name in ['warung', 'bank', 'cs']) {
      final s = Scenario.parse(File('assets/scenarios/$name.json').readAsStringSync());
      expect(s.forms.keys, containsAll(['A', 'B']));
      expect(s.forms['A']!.interactionCount, s.forms['B']!.interactionCount, reason: name);
    }
  });

  test('turns wait for listening, extra replies are ignored, done fires once', () async {
    final signals = <String>[];
    final stt = ScriptedStt(scenario.forms['A']!, onSignal: signals.add, wordDelay: Duration.zero);
    final finals = <String>[];
    stt.events.where((e) => e.isFinal).listen((e) => finals.add(e.text));

    stt.userReplied(); // not waiting yet: ignored
    await stt.start();
    await pumpEventQueue();
    expect(finals, ['Selamat siang, mau beli apa?']);
    expect(stt.isWaitingForUser, isTrue);

    await stt.pause();
    stt.userReplied();
    await pumpEventQueue();
    expect(finals.length, 1, reason: 'paused: next turn must wait');
    expect(stt.status.value, SttStatus.paused);

    await stt.start();
    await pumpEventQueue();
    expect(finals.length, 2);
    expect(stt.currentSuggestions, contains('Ini uangnya'));

    stt.userReplied();
    stt.userReplied();
    expect(signals, ['done']);
    expect(stt.waited, greaterThanOrEqualTo(Duration.zero));
  });
}
