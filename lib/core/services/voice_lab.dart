import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'local_gemma.dart';

/// One spoken turn heard by [VoiceLab].
class LabUtterance {
  LabUtterance({required this.speaker, required this.similarity, required this.seconds});

  /// 0-based speaker index, in order of first appearance.
  final int speaker;

  /// Cosine similarity to the matched speaker (1.0 for a new speaker).
  final double similarity;
  final double seconds;

  /// Null while Gemma is still transcribing.
  String? text;
  String? error;
  int? transcribeMs;
}

enum VoiceLabStatus { idle, preparing, listening, error }

/// Prototype of fully on-device speaker-aware transcription:
/// mic → Silero VAD (sentence clips) → CAM++ voice embedding (who) → Gemma (what).
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
  String? lastError;

  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _mic;
  sherpa.VoiceActivityDetector? _vad;
  sherpa.SpeakerEmbeddingExtractor? _embedder;
  final _centroids = <Float32List>[];
  final _counts = <int>[];

  Future<void> start() async {
    if (status.value != VoiceLabStatus.idle && status.value != VoiceLabStatus.error) return;
    status.value = VoiceLabStatus.preparing;
    try {
      if (!await _recorder.hasPermission()) throw StateError('Izin mikrofon ditolak');
      await _load();
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
    final vad = _vad;
    if (vad != null) {
      vad.flush();
      _drain(vad);
    }
    if (status.value == VoiceLabStatus.listening) status.value = VoiceLabStatus.idle;
  }

  /// Forget known voices and the transcript.
  void reset() {
    _centroids.clear();
    _counts.clear();
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
    for (var i = 0; i < f.length; i++) {
      f[i] = pcm.getInt16(i * 2, Endian.little) / 32768;
    }
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
    utterances.value = [...utterances.value, u];
    _transcribe(u, samples);
  }

  Future<void> _transcribe(LabUtterance u, Float32List samples) async {
    final sw = Stopwatch()..start();
    try {
      if (!LocalGemma.instance.hearsAudio) throw StateError('AI di ponsel belum aktif atau tidak menerima audio');
      u.text = await LocalGemma.instance.transcribe(_wav(samples, _sampleRate));
    } catch (e) {
      u.error = '$e';
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
    if (best >= 0 && bestSim >= threshold.value) {
      final c = _centroids[best];
      final n = ++_counts[best];
      for (var k = 0; k < c.length; k++) {
        c[k] += (e[k] - c[k]) / n;
      }
      return (best, bestSim);
    }
    _centroids.add(Float32List.fromList(e));
    _counts.add(1);
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
