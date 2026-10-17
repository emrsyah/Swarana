import 'package:flutter_test/flutter_test.dart';
import 'package:swarana/core/services/storage.dart';
import 'package:swarana/iter4/iter4_controller.dart';

class _MemStorage extends Storage {
  @override
  Future<void> writeEvents(String p, List<Map<String, Object?>> e) async {}
  @override
  Future<void> appendEvent(String p, Map<String, Object?> e) async {}
  @override
  Future<void> saveStudy(String p, Map<String, Object?> j) async {}
}

void main() {
  // P3 → order square 0: Opsi 1 first, content set 0 (nasi goreng / pedas).
  Iter4Controller make() => Iter4Controller(participantId: 'P3', storage: _MemStorage());

  // Without an LLM the cashier uses rule replies; a met goal ends the task
  // after the reply is shown (~0.5 s wait + typing + 1.5 s).
  const settle = Duration(seconds: 4);

  test('T1 accepts only the correct order, cashier always answers', () async {
    for (final (text, ok) in [
      ('nasi goreng pedas', false),
      ('tidak mau nasi goreng pedas', false),
      ('Es teh', false),
      ('Nasi goreng, tidak pedas ya', true),
      ('nasi goreng gak pakai pedas', true),
    ]) {
      final c = make()..startTask();
      c.send(text);
      await Future<void>.delayed(settle);
      expect(c.results.isNotEmpty && c.results.single.completed, ok, reason: text);
      expect(c.messages.last.me, isFalse, reason: 'cashier replied to "$text"');
      c.dispose();
    }
  });

  test('dish only gets the follow-up question', () async {
    final c = make()..startTask();
    c.send('mau pesan nasi goreng');
    await Future<void>.delayed(settle);
    expect(c.results, isEmpty);
    expect(c.messages.last.text, I4Content.sets[0].followUp);
    c.dispose();
  });

  test('researcher can end a task by hand', () async {
    final c = make()..startTask();
    c.send('nasi goreng, yang biasa aja');
    c.endManually();
    expect(c.phase, I4Phase.mark);
    c.markAnswer(true);
    expect(c.results.single.completed, isTrue);
    expect(c.results.single.manual, isTrue);
    c.dispose();
  });

  test('T2 needs the garbled line first and a real repeat request', () async {
    final c = make()..startTask();
    c.send('nasi goreng tidak pedas'); // finish T1
    await Future<void>.delayed(settle);
    c.startTask(); // T2
    c.send('Bisa ulangi?'); // before the garbled line → not success
    expect(c.results.length, 1);
    await Future<void>.delayed(const Duration(seconds: 5)); // let the script finish
    c.send('es teh lagi'); // not a repeat request
    await Future<void>.delayed(settle);
    expect(c.results.length, 1);
    c.send('Maaf');
    await Future<void>.delayed(settle);
    expect(c.results.length, 2);
    expect(c.results[1].completed, isTrue);
    expect(c.results[1].autoDetected, isTrue);
    expect(c.results[1].errors, containsAll(['terlalu_cepat', 'pesan_salah']));
    c.dispose();
  });
}
