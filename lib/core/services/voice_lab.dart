import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../env.dart';
import 'llm_service.dart';
import 'local_gemma.dart';

/// One spoken turn heard by [VoiceLab].
class LabUtterance {
  LabUtterance({required this.speaker, required this.similarity, required this.seconds});

  /// 0-based speaker index, in order of first appearance.
  final int speaker;

  /// Cosine similarity to the matched speaker (1.0 for a new speaker).
  final double similarity;
  final double seconds;

  /// Null while still transcribing.
  String? text;
  String? error;
  int? transcribeMs;

  /// Which AI wrote [text]: 'ponsel' (Gemma) or 'online' (OpenRouter).
  String? backend;

  bool get done => text != null || error != null;
}

enum VoiceLabStatus { idle, preparing, listening, error }

/// Speaker-aware transcription, used by the chats (via [SpeakerSttService])
/// and the lab page:
/// mic → Silero VAD (sentence clips) → CAM++ voice embedding (who, always on
/// the phone) → Gemma on the phone for one person, OpenRouter for a group (what).
///
/// The two small sherpa-onnx models (~30 MB) download on first use. Speaker
/// grouping is online: each clip joins the closest known voice if similar
/// enough, otherwise it starts a new speaker.
class VoiceLab {
  VoiceLab._();
  static final instance = VoiceLab._();

  static const _sampleRate = 16000;
  static const _models = {
    'silero_vad.onnx': 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx',
    'campplus_zh_en.onnx':
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/3dspeaker_speech_campplus_sv_zh_en_16k-common_advanced.onnx',
  };

  /// Same-speaker cutoff for cosine similarity. Tunable from the lab page.
  final threshold = ValueNotifier(0.5);
  final status = ValueNotifier(VoiceLabStatus.idle);
  final utterances = ValueNotifier<List<LabUtterance>>(const []);

  /// People heard so far in this session (see [_minSpeechToCount]). Drives
  /// routing: one person → on-device Gemma, two or more → online.
  final people = ValueNotifier(0);

  /// 0..1 input level for a meter.
  final level = ValueNotifier(0.0);

  /// Each utterance twice: when its clip is cut (not [LabUtterance.done]) and
  /// once transcribed. Finished ones arrive in speaking order.
  Stream<LabUtterance> get heard => _heard.stream;
  String? lastError;

  final _heard = StreamController<LabUtterance>.broadcast();
  Future<void> _inOrder = Future.value();
  bool _forceNew = false;

  /// A voice counts as a person only after this much speech in total, so a
  /// single short clip that was mis-grouped doesn't flip routing to online.
  static const _minSpeechToCount = 2.0;

  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _mic;
  sherpa.VoiceActivityDetector? _vad;
  sherpa.SpeakerEmbeddingExtractor? _embedder;
  final _centroids = <Float32List>[];
  final _counts = <int>[];
  final _seconds = <double>[];

  Future<void> start() async {
    if (status.value != VoiceLabStatus.idle && status.value != VoiceLabStatus.error) return;
    status.value = VoiceLabStatus.preparing;
    try {
      await prepare();
      final pcm = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
      ));
      _mic = pcm.listen(_onPcm);
      lastError = null;
      status.value = VoiceLabStatus.listening;
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> stop() async {
    await _mic?.cancel();
    _mic = null;
    await _recorder.stop();
    level.value = 0;
    final vad = _vad;
    if (vad != null) {
      vad.flush();
      _drain(vad);
    }
    if (status.value == VoiceLabStatus.listening) status.value = VoiceLabStatus.idle;
  }

  /// Mic permission plus the two voice models (downloaded once, ~30 MB).
  /// Throws if either is unavailable.
  Future<void> prepare() async {
    if (!await _recorder.hasPermission()) throw StateError('Izin mikrofon ditolak');
    await _load();
  }

  /// The next clip starts a new speaker (manual "someone else is talking").
  void forceNewSpeaker() => _forceNew = true;

  /// Forget known voices and the transcript.
  void reset() {
    _centroids.clear();
    _counts.clear();
    _seconds.clear();
    people.value = 0;
    utterances.value = const [];
  }

  Future<void> _load() async {
    if (_vad != null) return;
    sherpa.initBindings();
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/voice_lab');
    await dir.create(recursive: true);
    final paths = {for (final e in _models.entries) e.key: await _fetch(dir, e.key, e.value)};
    _vad = sherpa.VoiceActivityDetector(
      config: sherpa.VadModelConfig(
        sileroVad: sherpa.SileroVadModelConfig(
          model: paths['silero_vad.onnx']!,
          minSilenceDuration: 0.6,
          maxSpeechDuration: 20, // Gemma takes up to ~30 s of audio
        ),
        sampleRate: _sampleRate,
        debug: false,
      ),
      bufferSizeInSeconds: 30,
    );
    _embedder = sherpa.SpeakerEmbeddingExtractor(
      config: sherpa.SpeakerEmbeddingExtractorConfig(model: paths['campplus_zh_en.onnx']!, numThreads: 2, debug: false),
    );
  }

  static Future<String> _fetch(Directory dir, String name, String url) async {
    final file = File('${dir.path}/$name');
    if (await file.exists()) return file.path;
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw HttpException('Unduh $name gagal (${res.statusCode})');
    final tmp = File('${file.path}.part');
    await tmp.writeAsBytes(res.bodyBytes, flush: true);
    await tmp.rename(file.path);
    return file.path;
  }

  void _onPcm(Uint8List bytes) {
    final vad = _vad;
    if (vad == null) return;
    // Platform buffers may be unaligned for Int16List views; read via ByteData.
    final pcm = ByteData.sublistView(bytes);
    final f = Float32List(bytes.length ~/ 2);
    var energy = 0.0;
    for (var i = 0; i < f.length; i++) {
      f[i] = pcm.getInt16(i * 2, Endian.little) / 32768;
      energy += f[i] * f[i];
    }
    if (f.isNotEmpty) level.value = (math.sqrt(energy / f.length) * 8).clamp(0.0, 1.0);
    vad.acceptWaveform(f);
    _drain(vad);
  }

  void _drain(sherpa.VoiceActivityDetector vad) {
    while (!vad.isEmpty()) {
      final samples = vad.front().samples;
      vad.pop();
      _onSpeech(samples);
    }
  }

  void _onSpeech(Float32List samples) {
    final (speaker, sim) = _identify(_embed(samples));
    final u = LabUtterance(speaker: speaker, similarity: sim, seconds: samples.length / _sampleRate);
    _seconds[speaker] += u.seconds;
    people.value = _seconds.where((s) => s >= _minSpeechToCount).length;
    final list = utterances.value;
    utterances.value = [...list.skip(list.length >= 200 ? 1 : 0), u];
    _heard.add(u);
    final done = _transcribe(u, samples);
    // Online clips can finish out of order; deliver in speaking order.
    _inOrder = _inOrder.then((_) => done).then((_) => _heard.add(u));
  }

  // Chat models may answer a spoken question instead of transcribing it, so
  // the instruction says explicitly not to.
  static const _instruction = 'Tulis ulang ucapan dalam audio ini kata demi kata, dalam bahasa aslinya. '
      'Jangan menjawab atau menanggapi isinya, walaupun berupa pertanyaan. '
      'Jawab hanya dengan teksnya. Jika tidak ada ucapan, jawab tepat: (kosong)';

  /// One person → on-device Gemma first; two or more → OpenRouter first.
  /// The other is the fallback (offline, errors, Gemma without audio).
  Future<void> _transcribe(LabUtterance u, Float32List samples) async {
    final wav = _wav(samples, _sampleRate);
    final local = <(String, Future<String> Function())>[
      if (LocalGemma.instance.hearsAudio) ('ponsel', () => LocalGemma.instance.transcribe(wav, _instruction)),
    ];
    final online = <(String, Future<String> Function())>[
      if (Env.hasLlm) ('online', () => OpenRouterLlm().transcribe(wav, _instruction)),
    ];
    final backends = people.value >= 2 ? [...online, ...local] : [...local, ...online];
    final sw = Stopwatch()..start();
    final errors = <String>[];
    for (final (name, run) in backends) {
      try {
        final t = await run();
        u.text = t == '(kosong)' ? '' : t;
        u.backend = name;
        break;
      } catch (e) {
        errors.add('$name: $e');
      }
    }
    if (u.text == null) {
      u.error = backends.isEmpty ? 'Tidak ada AI: unduh AI di ponsel atau pakai versi dengan AI online.' : errors.join('\n');
    }
    u.transcribeMs = sw.elapsedMilliseconds;
    utterances.value = [...utterances.value]; // notify
  }

  Float32List _embed(Float32List samples) {
    final ex = _embedder!;
    final stream = ex.createStream();
    try {
      stream.acceptWaveform(samples: samples, sampleRate: _sampleRate);
      stream.inputFinished();
      return ex.compute(stream);
    } finally {
      stream.free();
    }
  }

  /// Closest known speaker if similar enough, else a new one. Centroids are
  /// running means so a voice settles as it speaks more.
  (int, double) _identify(Float32List e) {
    var best = -1;
    var bestSim = -1.0;
    for (var i = 0; i < _centroids.length; i++) {
      final s = _cosine(e, _centroids[i]);
      if (s > bestSim) (best, bestSim) = (i, s);
    }
    final forceNew = _forceNew;
    _forceNew = false;
    if (!forceNew && best >= 0 && bestSim >= threshold.value) {
      final c = _centroids[best];
      final n = ++_counts[best];
      for (var k = 0; k < c.length; k++) {
        c[k] += (e[k] - c[k]) / n;
      }
      return (best, bestSim);
    }
    _centroids.add(Float32List.fromList(e));
    _counts.add(1);
    _seconds.add(0);
    return (_centroids.length - 1, 1.0);
  }

  static double _cosine(Float32List a, Float32List b) {
    var dot = 0.0, na = 0.0, nb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    return dot / (math.sqrt(na * nb) + 1e-9);
  }

  void _fail(Object e) {
    lastError = '$e';
    debugPrint('VoiceLab: $e');
    status.value = VoiceLabStatus.error;
  }
}

/// 16-bit mono PCM WAV bytes for [samples] in [-1, 1].
Uint8List _wav(Float32List samples, int sampleRate) {
  final data = samples.length * 2;
  final b = ByteData(44 + data);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + data, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little); // fmt chunk size
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  b.setUint16(32, 2, Endian.little); // block align
  b.setUint16(34, 16, Endian.little); // bits per sample
  tag(36, 'data');
  b.setUint32(40, data, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    b.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}
