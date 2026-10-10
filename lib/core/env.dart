/// Build-time configuration, passed with `--dart-define`.
class Env {
  static const openRouterKey = String.fromEnvironment('OPENROUTER_API_KEY');
  static const openRouterModel = String.fromEnvironment(
    'OPENROUTER_MODEL',
    defaultValue: 'google/gemini-3.8-flash',
  );

  static bool get hasLlm => openRouterKey.isNotEmpty;
}
