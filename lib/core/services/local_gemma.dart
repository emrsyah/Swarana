import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:path_provider/path_provider.dart';

enum LocalGemmaStatus { unsupported, absent, downloading, importing, loading, ready, error }

/// On-device Gemma 4 E2B (LiteRT-LM), loaded once for the app's lifetime.
///
/// The model (~2.6 GB) is not bundled in the APK. From Pengaturan the user
/// either downloads it in-app (single connection, can be slow) or imports a
/// copy fetched with the browser / a download manager ([importFrom]). Until it
/// is ready the app uses OpenRouter (if a key was built in) or canned answers.
class LocalGemma {
  LocalGemma._();
  static final instance = LocalGemma._();

  static const fileName = 'gemma-4-E2B-it.litertlm';
  static const url =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/$fileName';
  static const sizeLabel = '2,6 GB';

  final status = ValueNotifier(LocalGemmaStatus.absent);

  /// Progress 0–100 while [status] is downloading or importing.
  final progress = ValueNotifier(0);
  String? lastError;

  /// Why the audio encoder failed to load (text AI still works), if it did.
  String? audioError;

  InferenceModel? _model;
  bool _audio = false;
  CancelToken? _download;
  Future<void> _queue = Future.value();

  bool get isReady => status.value == LocalGemmaStatus.ready;

  bool get _busy => const {
        LocalGemmaStatus.downloading,
        LocalGemmaStatus.importing,
        LocalGemmaStatus.loading,
      }.contains(status.value);

  /// Whether the loaded model accepts audio ([transcribe]).
  bool get hearsAudio => isReady && _audio;

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
    if (_busy) return;
    status.value = LocalGemmaStatus.downloading;
    progress.value = 0;
    final token = _download = CancelToken();
    try {
      await (await _builder()).withCancelToken(token).withProgress((p) => progress.value = p).install();
      await _activate(installed: true);
    } catch (e) {
      if (!token.isCancelled) _fail(e); // cancelled by importFrom, which owns status now
    } finally {
      if (identical(_download, token)) _download = null;
    }
  }

  /// Installs a model file the user already downloaded elsewhere. [bytes] is
  /// copied into app storage (the picked file may be removed afterwards);
  /// a running in-app download is cancelled.
  Future<void> importFrom(Stream<List<int>> bytes, int totalBytes) async {
    if (status.value == LocalGemmaStatus.importing || status.value == LocalGemmaStatus.loading) return;
    _download?.cancel('Diganti dengan file yang diimpor');
    status.value = LocalGemmaStatus.importing;
    progress.value = 0;
    final dst = await _importedFile();
    final tmp = File('${dst.path}.part');
    try {
      final sink = tmp.openWrite();
      var done = 0;
      try {
        await for (final chunk in bytes) {
          sink.add(chunk);
          done += chunk.length;
          if (totalBytes > 0) progress.value = (done * 100 ~/ totalBytes).clamp(0, 100);
        }
      } finally {
        await sink.close();
      }
      if (done < 1 << 30) throw const FormatException('File terlalu kecil, sepertinya bukan model Gemma');
      await tmp.rename(dst.path);
      await (await _builder()).install();
      await _activate(installed: true);
    } catch (e) {
      if (await tmp.exists()) await tmp.delete();
      _fail(e);
    }
  }

  Future<void> delete() async {
    final m = _model;
    _model = null;
    status.value = LocalGemmaStatus.absent;
    await m?.close();
    await FlutterGemma.uninstallModel(fileName);
    // The plugin leaves external (imported) files alone.
    final f = await _importedFile();
    if (await f.exists()) await f.delete();
  }

  /// One prompt, one fresh session. Calls are serialised: the phone has one
  /// model in memory and suggestions/titles can fire at the same time.
  Future<String> complete(String system, String input, {double temperature = 0.4}) =>
      _enqueue(Message.text(text: input, isUser: true), system: system, temperature: temperature);

  /// Speech to text from a WAV clip (16 kHz mono, under ~30 s).
  Future<String> transcribe(Uint8List wav) {
    if (!_audio) return Future.error(StateError('Model ini tidak bisa menerima audio'));
    return _enqueue(
      Message.withAudio(
        text: 'Tulis ulang ucapan dalam audio ini kata demi kata, dalam bahasa aslinya. '
            'Jawab hanya dengan teksnya. Jika tidak ada ucapan, jawab kosong.',
        audioBytes: wav,
        isUser: true,
      ),
      temperature: 0,
    );
  }

  Future<String> _enqueue(Message msg, {String? system, required double temperature}) {
    final run = _queue.then((_) => _run(msg, system, temperature));
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<String> _run(Message msg, String? system, double temperature) async {
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
      await session.addQueryChunk(msg);
      return (await session.getResponse()).trim();
    } finally {
      await session.close();
    }
  }

  static Future<File> _importedFile() async =>
      File('${(await getApplicationSupportDirectory()).path}/$fileName');

  /// Imported file if there is one, else the network source.
  Future<InferenceInstallationBuilder> _builder() async {
    final b = FlutterGemma.installModel(modelType: ModelType.gemma4, fileType: ModelFileType.litertlm);
    final imported = await _importedFile();
    return await imported.exists() ? b.fromFile(imported.path) : b.fromNetwork(url);
  }

  Future<void> _activate({bool installed = false}) async {
    status.value = LocalGemmaStatus.loading;
    // Re-running install on an installed file only marks it active.
    if (!installed) await (await _builder()).install();
    // Best first: GPU with the audio encoder. CPU covers phones without a
    // usable GPU delegate; the last try drops audio so text AI still works.
    const attempts = [
      (PreferredBackend.gpu, true),
      (PreferredBackend.cpu, true),
      (PreferredBackend.cpu, false),
    ];
    for (final (i, (backend, audio)) in attempts.indexed) {
      try {
        _model = await FlutterGemma.getActiveModel(maxTokens: 2048, preferredBackend: backend, supportAudio: audio);
        _audio = audio;
        if (audio) audioError = null; // an earlier GPU attempt may have failed
        break;
      } catch (e) {
        if (i == attempts.length - 1) rethrow;
        debugPrint('LocalGemma: $backend audio=$audio failed: $e');
        if (audio) audioError = '$e';
      }
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
