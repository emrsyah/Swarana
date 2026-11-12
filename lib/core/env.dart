/// Build-time configuration, passed with `--dart-define`.
class Env {
  static const openRouterKey = String.fromEnvironment('OPENROUTER_API_KEY');
  static const openRouterModel = String.fromEnvironment(
    'OPENROUTER_MODEL',
    // Benchmarked on OpenRouter with the suggestion prompt (median of 3):
    // qwen3.8-27b on Cerebras 1.04 s, gemini-3.5-flash-lite 1.42 s,
    // gemini-3.8-flash ~4 s. Qwen kept good Indonesian at the lowest latency.
    defaultValue: 'qwen/qwen3.8-27b',
  );

  /// Online speech-to-text model (OpenRouter /audio/transcriptions), used by
  /// the speaker-detection lab when on-device Gemma can't take audio.
  /// Measured: ~4.3 s and ~$0.0004 per 3 s sentence.
  static const openRouterAudioModel =
      String.fromEnvironment('OPENROUTER_AUDIO_MODEL', defaultValue: 'google/gemini-3.5-transcribe');

  static bool get hasLlm => openRouterKey.isNotEmpty;
}
