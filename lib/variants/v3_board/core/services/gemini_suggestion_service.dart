import 'v3_backend.dart';

/// Ported from iteration 3. Same API and behaviour (up to 6 suggestions from a
/// transcript), now backed by the shared LLM so both variants use one engine.
class GeminiSuggestionService {
  GeminiSuggestionService();

  Future<List<String>> suggestionsFromTranscript(String transcript) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return const [];
    try {
      return await V3Backend.services.llm.suggestionsFromTranscript(trimmed, max: 6);
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
