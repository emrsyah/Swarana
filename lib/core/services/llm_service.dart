import 'dart:convert';

import 'package:http/http.dart' as http;

import '../env.dart';
import '../models/message.dart';
import 'local_gemma.dart';

class LlmException implements Exception {
  LlmException(this.message);
  final String message;
  @override
  String toString() => 'LlmException: $message';
}

abstract class LlmService {
  /// Three short replies for the user, given the conversation so far.
  Future<List<String>> suggestReplies(
    List<ChatMessage> history,
    Map<String, Speaker> speakers, {
    String draft = '',
  });

  /// v3 behaviour: suggestions from a single transcript, up to [max].
  Future<List<String>> suggestionsFromTranscript(String text, {int max = 6});

  Future<String> simplify(String text);
  Future<String> explainWord(String word, String context);
  Future<String> titleFor(String text);
}

/// The real AI backend for live use: OpenRouter when a key was built in,
/// falling back per call to on-device Gemma (offline, errors, timeouts).
/// Null when neither is available, so callers use canned answers.
PromptLlm? liveLlm() {
  if (!Env.hasLlm) return LocalGemma.instance.isReady ? LocalGemmaLlm() : null;
  return FallbackLlm([OpenRouterLlm(), LocalGemmaLlm()]);
}

/// Tries each backend in order and returns the first answer. A backend that
/// is not ready (e.g. Gemma not downloaded) fails fast and is skipped.
class FallbackLlm extends PromptLlm {
  FallbackLlm(this.chain) : assert(chain.isNotEmpty);
  final List<PromptLlm> chain;

  @override
  Future<String> complete(String system, String input, {double temperature = 0.4}) async {
    final errors = <String>[];
    for (final llm in chain) {
      try {
        return await llm.complete(system, input, temperature: temperature);
      } on Exception catch (e) {
        // Also catches malformed bodies (FormatException), not just LlmException.
        errors.add('$e');
      }
    }
    throw LlmException(errors.join('; '));
  }
}

/// Shared prompts, so every backend gets the same instructions. Prompts follow
/// the Role / User context / Task / Constraint framework adopted in
/// iteration 2; a backend only implements [complete].
abstract class PromptLlm implements LlmService {
  static const _role =
      'Kamu adalah asisten komunikasi untuk Teman Tuli di Indonesia. '
      'Gunakan bahasa Indonesia sehari-hari yang sopan dan mudah dipahami.';

  Future<String> complete(String system, String input, {double temperature = 0.4});

  /// Call with a complete system prompt of its own (e.g. a role-play partner).
  Future<String> askWithSystem(String system, String input, {double temperature = 0.4}) =>
      complete(system, input, temperature: temperature);

  Future<String> _ask(String task, String input, {double temperature = 0.4}) =>
      complete('$_role\n\n$task', input, temperature: temperature);

  static String _historyText(List<ChatMessage> history, Map<String, Speaker> speakers) =>
      history
          .where((m) => !m.partial)
          .toList()
          .reversed
          .take(8)
          .toList()
          .reversed
          .map((m) => '${m.isMe ? 'Saya (Teman Tuli)' : speakers[m.speakerId]?.name ?? 'Lawan bicara'}: ${m.text}')
          .join('\n');

  @override
  Future<List<String>> suggestReplies(
    List<ChatMessage> history,
    Map<String, Speaker> speakers, {
    String draft = '',
  }) async {
    final task = 'Tugas: beri tepat 3 balasan yang bisa diucapkan Teman Tuli '
        'berikutnya dalam percakapan lisan ini, ditulis sebagai Teman Tuli (orang pertama).\n'
        'Batasan: tiap balasan maksimal 6 kata, maksud berbeda-beda '
        '(misalnya menjawab, bertanya balik, minta diulang), jangan pakai tanda kurung '
        'atau placeholder seperti [Nama], jangan mengarang nama orang, '
        'satu balasan per baris, tanpa nomor dan tanpa penjelasan.'
        '${draft.isNotEmpty ? ' Lanjutkan atau perbaiki draf pengguna.' : ''}';
    final input = 'Percakapan:\n${_historyText(history, speakers)}'
        '${draft.isNotEmpty ? '\n\nDraf pengguna: $draft' : ''}';
    return OpenRouterLlm.parseLines(await _ask(task, input, temperature: 0.6));
  }

  @override
  Future<List<String>> suggestionsFromTranscript(String text, {int max = 6}) async {
    final task = 'Tugas: beri $max balasan singkat untuk ucapan lawan bicara. '
        'Batasan: tiap balasan maksimal 8 kata, satu per baris, tanpa nomor.';
    return OpenRouterLlm.parseLines(await _ask(task, text, temperature: 0.6), max: max);
  }

  @override
  Future<String> simplify(String text) => _ask(
        'Tugas: tulis ulang teks berikut agar mudah dipahami. '
        'Batasan: kalimat pendek (maksimal 12 kata per kalimat), kata sehari-hari, '
        'tanpa istilah sulit. Pertahankan semua angka, nama, tanggal, dan tempat. '
        'Jawab hanya dengan teks hasil.',
        text,
        temperature: 0.2,
      );

  @override
  Future<String> explainWord(String word, String context) => _ask(
        'Tugas: jelaskan arti kata atau frasa yang diminta sesuai konteksnya. '
        'Batasan: satu kalimat sederhana, maksimal 15 kata, jawab hanya penjelasannya.',
        'Kata: "$word"\nKonteks: $context',
        temperature: 0.2,
      );

  @override
  Future<String> titleFor(String text) async {
    final t = await _ask(
      'Tugas: beri judul 2 sampai 4 kata untuk percakapan atau transkrip ini. '
      'Batasan: huruf kapital hanya di awal, tanpa tanda kutip, jawab hanya judulnya.',
      text.length > 2000 ? text.substring(0, 2000) : text,
      temperature: 0.3,
    );
    return OpenRouterLlm.parseLines(t, max: 1).firstOrNull ?? 'Obrolan baru';
  }
}

/// Gemma 4 E2B on the phone (see [LocalGemma]). Works offline and nothing
/// leaves the device; speed depends on the phone.
class LocalGemmaLlm extends PromptLlm {
  @override
  Future<String> complete(String system, String input, {double temperature = 0.4}) async {
    final String out;
    try {
      out = await LocalGemma.instance
          .complete(system, input, temperature: temperature)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw LlmException('local: $e');
    }
    if (out.isEmpty) throw LlmException('empty response');
    return out;
  }
}

/// OpenRouter chat completions.
class OpenRouterLlm extends PromptLlm {
  OpenRouterLlm({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  static final _url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

  @override
  Future<String> complete(String system, String input, {double temperature = 0.4}) async {
    final http.Response res;
    try {
      res = await _http
          .post(
            _url,
            headers: {
              'Authorization': 'Bearer ${Env.openRouterKey}',
              'Content-Type': 'application/json',
              'X-Title': 'Swarana',
            },
            body: jsonEncode({
              'model': Env.openRouterModel,
              'temperature': temperature,
              ..._speedOptions(Env.openRouterModel),
              'max_tokens': 300,
              'messages': [
                {'role': 'system', 'content': system},
                {'role': 'user', 'content': input},
              ],
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on Exception catch (e) {
      throw LlmException('network: $e');
    }
    if (res.statusCode != 200) throw LlmException('HTTP ${res.statusCode}');
    return parseContent(utf8.decode(res.bodyBytes));
  }

  /// Short, latency-sensitive tasks: no or minimal "thinking", fastest host.
  static Map<String, Object> _speedOptions(String model) => {
        if (model.startsWith('google/gemini'))
          'reasoning': {'effort': 'minimal'}
        else
          'reasoning': {'enabled': false},
        if (model.startsWith('qwen/') || model.startsWith('openai/gpt-oss'))
          'provider': {
            'order': ['Cerebras', 'Groq'],
            'allow_fallbacks': true,
          }
        else
          'provider': {'sort': 'latency'},
      };

  static String parseContent(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    final choices = j['choices'] as List?;
    final content = (choices == null || choices.isEmpty)
        ? null
        : (choices.first as Map)['message']?['content'];
    if (content is! String || content.trim().isEmpty) {
      throw LlmException('empty response');
    }
    return content.trim();
  }

  static List<String> parseLines(String content, {int max = 3}) => content
      .split('\n')
      .map((l) => l
          .replaceFirst(RegExp(r'^\s*([-*•]|\d+[.)])\s*'), '')
          .replaceAll(RegExp(r'^"+|"+$'), '')
          .trim())
      .where((l) => l.isNotEmpty)
      .take(max)
      .toList();
}
