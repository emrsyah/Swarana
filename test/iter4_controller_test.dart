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

  test('T1 accepts only the correct order', () async {
    for (final (text, ok) in [
      ('nasi goreng pedas', false),
      ('tidak mau nasi goreng pedas', false),
      ('Es teh', false),
      ('Nasi goreng, tidak pedas ya', true),
      ('nasi goreng gak pakai pedas', true),
    ]) {
      final c = make()..startTask();
      c.send(text);
      expect(c.results.isNotEmpty && c.results.single.completed, ok, reason: text);
      c.dispose();
    }
  });

  test('T2 needs the garbled line first and a real repeat request', () async {
    final c = make()..startTask();
    c.send('nasi goreng tidak pedas'); // finish T1
    c.startTask(); // T2
    c.send('Bisa ulangi?'); // before the garbled line → not success
    expect(c.results.length, 1);
    expect(c.results.length, 1);
    await Future<void>.delayed(const Duration(seconds: 5)); // let the script finish
    c.send('es teh lagi'); // not a repeat request
    expect(c.results.length, 1);
    c.send('Maaf');
    expect(c.results.length, 2);
    expect(c.results[1].completed, isTrue);
    expect(c.results[1].errors, containsAll(['terlalu_cepat', 'pesan_salah']));
    c.dispose();
  });
}
