import 'dart:convert';

import 'package:http/http.dart' as http;

import '../env.dart';
import '../models/message.dart';

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

/// OpenRouter chat completions. Prompts follow the Role / User context /
/// Task / Constraint framework adopted in iteration 2.
class OpenRouterLlm implements LlmService {
  OpenRouterLlm({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  static final _url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

  static const _role =
      'Kamu adalah asisten komunikasi untuk Teman Tuli di Indonesia. '
      'Gunakan bahasa Indonesia sehari-hari yang sopan dan mudah dipahami.';

  Future<String> _ask(String task, String input, {double temperature = 0.4}) async {
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
              // Short, latency-sensitive tasks: keep thinking to a minimum.
              'reasoning': {'effort': 'minimal'},
              'max_tokens': 300,
              'messages': [
                {'role': 'system', 'content': '$_role\n\n$task'},
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
    return parseLines(await _ask(task, input, temperature: 0.6));
  }

  @override
  Future<List<String>> suggestionsFromTranscript(String text, {int max = 6}) async {
    final task = 'Tugas: beri $max balasan singkat untuk ucapan lawan bicara. '
        'Batasan: tiap balasan maksimal 8 kata, satu per baris, tanpa nomor.';
    return parseLines(await _ask(task, text, temperature: 0.6), max: max);
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
    return parseLines(t, max: 1).firstOrNull ?? 'Obrolan baru';
  }
}
