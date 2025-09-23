import 'package:flutter/foundation.dart'; // Import ini untuk ValueNotifier
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;

  // GANTI STATE LAMA DENGAN VALUENOTIFIER
  final ValueNotifier<bool> isListeningNotifier = ValueNotifier(false);
  final ValueNotifier<String> recognizedTextNotifier = ValueNotifier('');
  final ValueNotifier<String> statusNotifier = ValueNotifier('notListening');

  List<stt.LocaleName> _locales = [];

  // Getters
  bool get isInitialized => _speechEnabled;
  // Kita tidak butuh getter isListening dan lastWords lagi, karena akan diakses via notifier

  List<stt.LocaleName> get availableLocales => _locales;

  /// Initialize the speech service
  Future<bool> initialize() async {
    // Hapus parameter callback dari sini
    try {
      if (_speechEnabled) return true; // Langsung return jika sudah init

      _speechEnabled = await _speechToText.initialize(
        onStatus: _onSpeechStatus, // Selalu gunakan listener internal
        onError: _onSpeechError, // Selalu gunakan listener internal
      );

      if (_speechEnabled) {
        _locales = await _speechToText.locales();
      }

      return _speechEnabled;
    } catch (e) {
      print('Speech initialization error: $e');
      _speechEnabled = false;
      return false;
    }
  }

  /// Start listening for speech
  Future<void> startListening({
    // Hapus parameter onResult
    String? localeId,
    Duration? timeout,
    Duration? pauseFor,
    bool partialResults = true,
  }) async {
    if (!_speechEnabled) throw Exception('Speech recognition not initialized');
    if (isListeningNotifier.value) return; // Cek dari notifier

    recognizedTextNotifier.value = ''; // Reset teks setiap kali mulai

    try {
      await _speechToText.listen(
        onResult: (result) {
          // Update notifier dengan hasil teks
          recognizedTextNotifier.value = result.recognizedWords;
        },
        localeId: localeId ?? 'id_ID',
        listenFor: timeout ?? const Duration(seconds: 30),
        pauseFor: pauseFor ?? const Duration(seconds: 3),
        partialResults: partialResults,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );

      // Update status via listener internal
      isListeningNotifier.value = true;
      statusNotifier.value = 'listening';
    } catch (e) {
      print('Start listening error: $e');
      isListeningNotifier.value = false;
      throw Exception('Failed to start listening: $e');
    }
  }

  /// Stop listening for speech
  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
      isListeningNotifier.value = false; // Update manual jika di-stop
    }
  }

  /// Cancel speech recognition
  Future<void> cancelListening() async {
    if (_speechToText.isListening) {
      await _speechToText.cancel();
      isListeningNotifier.value = false; // Update manual jika di-cancel
    }
  }

  // LISTENER INTERNAL SERVICE
  void _onSpeechStatus(String status) {
    print('Internal Speech status: $status');
    isListeningNotifier.value = status == 'listening';
    statusNotifier.value = status;
  }

  void _onSpeechError(dynamic error) {
    print('Internal Speech error: $error');
    isListeningNotifier.value = false;
  }

  // Sisa kode service (getIndonesianLocale, dispose, etc.) bisa tetap sama
  // ...
  stt.LocaleName? getIndonesianLocale() {
    try {
      return _locales.firstWhere((locale) => locale.localeId.toLowerCase().startsWith('id'));
    } catch (e) {
      return null;
    }
  }

  List<stt.LocaleName> getIndonesianLocales() {
    return _locales
        .where((locale) => locale.localeId.toLowerCase().contains('id') || locale.name.toLowerCase().contains('indonesia'))
        .toList();
  }

  static Future<bool> isAvailable() async {
    final stt.SpeechToText speech = stt.SpeechToText();
    return await speech.initialize();
  }

  void dispose() {
    // Kosongkan saja, karena singleton tidak seharusnya di-dispose
  }
}
