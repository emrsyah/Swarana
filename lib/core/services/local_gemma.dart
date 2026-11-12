import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

enum LocalGemmaStatus { unsupported, absent, downloading, loading, ready, error }

/// On-device Gemma 4 E2B (LiteRT-LM), loaded once for the app's lifetime.
///
/// The model (~2.6 GB) is not bundled in the APK: the user downloads it from
/// Pengaturan. Until it is ready the app keeps using OpenRouter (if a key was
/// built in) or canned answers.
class LocalGemma {
  LocalGemma._();
  static final instance = LocalGemma._();

  static const fileName = 'gemma-4-E2B-it.litertlm';
  static const url =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/$fileName';
  static const sizeLabel = '2,6 GB';

  final status = ValueNotifier(LocalGemmaStatus.absent);

  /// Download progress 0–100 while [status] is downloading.
  final progress = ValueNotifier(0);
  String? lastError;

  InferenceModel? _model;
  Future<void> _queue = Future.value();

  bool get isReady => status.value == LocalGemmaStatus.ready;

  /// Call once at startup (not awaited): registers the engine and, if the
  /// model was downloaded earlier, loads it.
  Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      status.value = LocalGemmaStatus.unsupported;
      return;
    }
    try {
      // Public (ungated) repo: no Hugging Face token. An empty string would
      // still send a bare "Bearer" header, so pass null.
      await FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]);
      if (await FlutterGemma.isModelInstalled(fileName)) await _activate();
    } catch (e) {
      _fail(e);
    }
  }

  /// Downloads the model (resumable, retried by the plugin) and loads it.
  Future<void> download() async {
    if (status.value == LocalGemmaStatus.downloading || status.value == LocalGemmaStatus.loading) return;
    status.value = LocalGemmaStatus.downloading;
    progress.value = 0;
    try {
      await _builder().withProgress((p) => progress.value = p).install();
      await _activate(installed: true);
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> delete() async {
    final m = _model;
    _model = null;
    status.value = LocalGemmaStatus.absent;
    await m?.close();
    await FlutterGemma.uninstallModel(fileName);
  }

  /// One prompt, one fresh session. Calls are serialised: the phone has one
  /// model in memory and suggestions/titles can fire at the same time.
  Future<String> complete(String system, String input, {double temperature = 0.4}) {
    final run = _queue.then((_) => _complete(system, input, temperature));
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<String> _complete(String system, String input, double temperature) async {
    final model = _model;
    if (model == null) throw StateError('Model lokal belum siap');
    final session = await model.createSession(
      temperature: temperature,
      topK: 40,
      systemInstruction: system,
      enableThinking: false,
      maxOutputTokens: 200,
    );
    try {
      await session.addQueryChunk(Message.text(text: input, isUser: true));
      return (await session.getResponse()).trim();
    } finally {
      await session.close();
    }
  }

  InferenceInstallationBuilder _builder() => FlutterGemma.installModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
      ).fromNetwork(url);

  Future<void> _activate({bool installed = false}) async {
    status.value = LocalGemmaStatus.loading;
    // Re-running install on an installed file only marks it active.
    if (!installed) await _builder().install();
    try {
      _model = await FlutterGemma.getActiveModel(maxTokens: 2048, preferredBackend: PreferredBackend.gpu);
    } catch (_) {
      // No usable GPU delegate on this phone.
      _model = await FlutterGemma.getActiveModel(maxTokens: 2048, preferredBackend: PreferredBackend.cpu);
    }
    lastError = null;
    status.value = LocalGemmaStatus.ready;
  }

  void _fail(Object e) {
    lastError = '$e';
    debugPrint('LocalGemma: $e');
    status.value = LocalGemmaStatus.error;
  }
}
