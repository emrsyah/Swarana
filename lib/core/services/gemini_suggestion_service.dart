import 'dart:async';
import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

class GeminiSuggestionService {
  GeminiSuggestionService({GenerativeModel? model}) : _model = model ?? _buildModel();

  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _modelName = 'gemini-2.0-flash-lite';
  static const Map<String, Object> _generationConfigPayload = {
    'maxOutputTokens': 160,
    'temperature': 0.6,
  };

  final GenerativeModel _model;

  static GenerativeModel _buildModel() {
    if (_apiKey.isEmpty) {
      throw const SuggestionGenerationException('GEMINI_API_KEY is not set.');
    }
    return GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        maxOutputTokens: _generationConfigPayload['maxOutputTokens'] as int,
        temperature: _generationConfigPayload['temperature'] as double,
      ),
    );
  }

  Future<List<String>> suggestionsFromTranscript(String transcript) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return const [];
    final prompt = _promptFor(trimmed);

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return _extractSegments(response.text);
    } on GenerativeAISdkException catch (error) {
      if (_isPromptFeedbackFormat(error)) {
        final fallback = await _fallbackGenerate(prompt);
        return _extractSegments(fallback);
      }
      throw SuggestionGenerationException('Gemini error: ${error.message}');
    } on GenerativeAIException catch (error) {
      throw SuggestionGenerationException('Gemini error: ${error.message}');
    } catch (error) {
      throw SuggestionGenerationException('Gagal menghasilkan saran: $error');
    }
  }

  static String _promptFor(String transcript) =>
      'Kamu adalah asisten komunikasi untuk aplikasi AAC yang digunakan oleh pengguna Tuli. '
      'Pengguna Tuli biasanya memiliki kosa kata terbatas dan menggunakan bahasa yang sangat sederhana. '
      'Dari transkrip berikut (hasil pembicaraan orang non-Tuli), berikan MAKSIMAL enam saran jawaban langsung, '
      'dalam bahasa Indonesia yang sangat sederhana, singkat, dan mudah dimengerti. '
      'Jawaban harus berupa kalimat atau frasa pendek yang bisa langsung dipakai untuk membalas. '
      'Jangan gunakan kata atau kalimat yang rumit. '
      'Jangan gunakan format list atau angka. Hanya gunakan teks biasa. '
      'Transkrip: "$transcript"';

  static List<String> _extractSegments(String? raw) {
    final cleaned = raw?.trim();
    if (cleaned == null || cleaned.isEmpty) return const [];
    return cleaned
        .split(RegExp(r'[\n\r•-]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(6)
        .toList();
  }

  static bool _isPromptFeedbackFormat(GenerativeAISdkException error) =>
      error.message.contains('PromptFeedback');

  static Uri _buildFallbackUri() => Uri.https(
        'generativelanguage.googleapis.com',
        'v1beta/models/$_modelName:generateContent',
      );

  static Future<String?> _fallbackGenerate(String prompt) async {
    if (_apiKey.isEmpty) {
      throw const SuggestionGenerationException('GEMINI_API_KEY is not set.');
    }

    final response = await http.post(
      _buildFallbackUri(),
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': _apiKey,
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': _generationConfigPayload,
      }),
    );

    if (response.statusCode >= 400) {
      final message = _extractErrorMessage(response.body);
      throw SuggestionGenerationException(
        'Gemini fallback error (${response.statusCode}): $message',
      );
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, Object?>) return null;
    final candidates = data['candidates'];
    if (candidates is! List) return null;

    final buffer = StringBuffer();
    var hasText = false;
    for (final candidate in candidates) {
      if (candidate is! Map<String, Object?>) continue;
      final content = candidate['content'];
      if (content is! Map<String, Object?>) continue;
      final parts = content['parts'];
      if (parts is! List) continue;
      for (final part in parts) {
        if (part is! Map<String, Object?>) continue;
        final text = part['text'];
        if (text is String) {
          if (hasText) buffer.write('\n');
          buffer.write(text);
          hasText = true;
        }
      }
    }

    final combined = buffer.toString().trim();
    return combined.isEmpty ? null : combined;
  }

  static String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        final error = decoded['error'];
        if (error is Map<String, Object?>) {
          final message = error['message'];
          if (message is String && message.isNotEmpty) {
            return message;
          }
        }
      }
    } catch (_) {}
    return body;
  }
}

class SuggestionGenerationException implements Exception {
  const SuggestionGenerationException(this.message);
  final String message;

  @override
  String toString() => 'SuggestionGenerationException: $message';
}
