import 'package:flutter_test/flutter_test.dart';
import 'package:swarana/ux_kit/simulated_data.dart';
import 'package:swarana/ux_kit/ux_models.dart';

void main() {
  final blocks = [
    for (final s in simulatedStudies())
      for (final b in (s['blocks'] as List)) VariantBlock.fromJson((b as Map).cast()),
  ];
  Iterable<VariantBlock> of(String v) => blocks.where((b) => b.variant.name == v);
  double mean(Iterable<num> xs) => xs.fold<double>(0, (a, b) => a + b) / xs.length;

  test('matches the report: times, success, TLX, SUS, SEQ', () {
    for (final (sc, v3, v5) in [('warung', 43, 36), ('bank', 146, 131), ('cs', 198, 127)]) {
      double t(String v) => mean(of(v).expand((b) => b.tasks).where((r) => r.scenarioId == sc).map((r) => r.duration.inSeconds));
      expect(t('v3Board').round(), v3, reason: sc);
      expect(t('v5Chat').round(), v5, reason: sc);
    }
    int ok(String v) => of(v).expand((b) => b.tasks).fold(0, (a, r) => a + (r.okInteractions ?? 0));
    expect(ok('v3Board'), 18);
    expect(ok('v5Chat'), 27);
    expect(mean(of('v3Board').map((b) => b.tlxRaw!)), 51);
    expect(mean(of('v5Chat').map((b) => b.tlxRaw!)), 37);
    for (final b in blocks) {
      expect(mean(b.tlx!.values), b.tlxRaw, reason: 'TLX dims average to raw');
    }
    expect(mean(of('v5Chat').map((b) => b.sus).whereType<double>()).toStringAsFixed(1), '85.8');
    final seq = of('v5Chat').expand((b) => b.tasks).map((r) => r.seq).whereType<int>();
    expect(mean(seq).toStringAsFixed(1), '6.2');
  });
}
