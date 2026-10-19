import 'package:flutter_test/flutter_test.dart';
import 'package:swarana/ux_kit/questionnaires.dart';

void main() {
  test('SUS: neutral answers score 50, ideal answers 100, worst 0', () {
    expect(susScore(List.filled(10, 3)), 50);
    expect(susScore([5, 1, 5, 1, 5, 1, 5, 1, 5, 1]), 100);
    expect(susScore([1, 5, 1, 5, 1, 5, 1, 5, 1, 5]), 0);
  });

  test('SUS: mixed answers', () {
    // odd: 4,4,3,5,4 -> 3+3+2+4+3 = 15; even: 2,1,2,2,3 -> 3+4+3+3+2 = 15
    expect(susScore([4, 2, 4, 1, 3, 2, 5, 2, 4, 3]), 75);
  });

  test('TLX raw is the unweighted mean', () {
    expect(tlxRaw({'a': 40, 'b': 60, 'c': 20, 'd': 80, 'e': 50, 'f': 50}), 50);
  });
}
