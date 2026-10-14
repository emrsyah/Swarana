/// Build-time configuration, passed with `--dart-define`.
class Env {
  static const openRouterKey = String.fromEnvironment('OPENROUTER_API_KEY');
  static const openRouterModel = String.fromEnvironment(
    'OPENROUTER_MODEL',
    // Measured on OpenRouter: ~1.6 s with minimal reasoning vs ~4 s for
    // gemini-3.8-flash (reasoning cannot be disabled on either).
    defaultValue: 'google/gemini-3.5-flash-lite',
  );

  static bool get hasLlm => openRouterKey.isNotEmpty;
}
