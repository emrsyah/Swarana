import 'dart:async';

import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiSuggestionService {
  GeminiSuggestionService({GenerativeModel? model}) : _model = model ?? _buildModel();

  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _modelName = 'gemini-2.0-flash-exp';

  final GenerativeModel _model;

  static GenerativeModel _buildModel() {
    if (_apiKey.isEmpty) {
      throw const SuggestionGenerationException('GEMINI_API_KEY is not set.');
    }
    return GenerativeModel(
      model: _modelName,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(maxOutputTokens: 160, temperature: 0.6),
    );
  }

  Future<List<String>> suggestionsFromTranscript(String transcript) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return const [];

    try {
      final response = await _model.generateContent([
        Content.text(
          'Kamu adalah asisten komunikasi. Dari transkrip berikut, berikan maksimal enam saran singkat yang merupakan JAWABAN LANGSUNG.'
          'dalam bahasa Indonesia untuk melanjutkan percakapan. Jawab dalam teks biasa. '
          'Transkrip: "$trimmed"',
        ),
      ]);

      final raw = response.text?.trim();
      if (raw == null || raw.isEmpty) return const [];

      final segments = raw
          .split(RegExp(r'[\n\r•-]+'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .take(6)
          .toList();
      return segments;
    } on GenerativeAIException catch (error) {
      throw SuggestionGenerationException('Gemini error: ${error.message}');
    } catch (error) {
      throw SuggestionGenerationException('Gagal menghasilkan saran: $error');
    }
  }
}

class SuggestionGenerationException implements Exception {
  const SuggestionGenerationException(this.message);
  final String message;

  @override
  String toString() => 'SuggestionGenerationException: $message';
}
