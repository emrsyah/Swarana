import 'package:flutter_test/flutter_test.dart';
import 'package:swarana/core/services/llm_service.dart';

void main() {
  test('parseContent reads the first choice', () {
    const body =
        '{"id":"x","choices":[{"message":{"role":"assistant","content":"  Halo  "}}]}';
    expect(OpenRouterLlm.parseContent(body), 'Halo');
  });

  test('parseContent throws on empty content or no choices', () {
    expect(() => OpenRouterLlm.parseContent('{"choices":[]}'),
        throwsA(isA<LlmException>()));
    expect(
        () => OpenRouterLlm.parseContent(
            '{"choices":[{"message":{"content":" "}}]}'),
        throwsA(isA<LlmException>()));
  });

  test('parseLines strips numbering, bullets, quotes and caps the count', () {
    const content = '1. "Baik, saya setuju"\n- Bisa diulangi?\n\n2) Tidak, terima kasih\n• Extra';
    expect(OpenRouterLlm.parseLines(content),
        ['Baik, saya setuju', 'Bisa diulangi?', 'Tidak, terima kasih']);
  });
}
