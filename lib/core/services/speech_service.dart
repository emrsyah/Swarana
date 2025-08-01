import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';
  List<stt.LocaleName> _locales = [];

  // Getters
  bool get isInitialized => _speechEnabled;
  bool get isListening => _isListening;
  String get lastWords => _lastWords;
  List<stt.LocaleName> get availableLocales => _locales;

  /// Initialize the speech service
  Future<bool> initialize({
    Function(String)? onStatus,
    Function(dynamic)? onError,
  }) async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: onStatus ?? _defaultStatusListener,
        onError: onError ?? _defaultErrorListener,
      );
      
      if (_speechEnabled) {
        _locales = await _speechToText.locales();
      }
      
      return _speechEnabled;
    } catch (e) {
      print('Speech initialization error: $e');
      return false;
    }
  }

  /// Start listening for speech
  Future<void> startListening({
    required Function(String) onResult,
    String? localeId,
    Duration? timeout,
    Duration? pauseFor,
    bool partialResults = true,
  }) async {
    if (!_speechEnabled) {
      throw Exception('Speech recognition not initialized');
    }

    if (_isListening) {
      return; // Already listening
    }

    try {
      await _speechToText.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          _isListening = _speechToText.isListening;
          onResult(result.recognizedWords);
        },
        localeId: localeId ?? 'id_ID', // Default to Indonesian
        listenFor: timeout ?? const Duration(seconds: 30),
        pauseFor: pauseFor ?? const Duration(seconds: 3),
        partialResults: partialResults,
        onSoundLevelChange: null,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
      
      _isListening = true;
    } catch (e) {
      print('Start listening error: $e');
      _isListening = false;
      throw Exception('Failed to start listening: $e');
    }
  }

  /// Stop listening for speech
  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
    _isListening = false;
  }

  /// Cancel speech recognition
  Future<void> cancelListening() async {
    if (_speechToText.isListening) {
      await _speechToText.cancel();
    }
    _isListening = false;
  }

  /// Get Indonesian locale if available
  stt.LocaleName? getIndonesianLocale() {
    try {
      return _locales.firstWhere(
        (locale) => locale.localeId.toLowerCase().startsWith('id'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get all locales that contain Indonesian language
  List<stt.LocaleName> getIndonesianLocales() {
    return _locales.where(
      (locale) => locale.localeId.toLowerCase().contains('id') ||
                  locale.name.toLowerCase().contains('indonesia'),
    ).toList();
  }

  /// Default status listener
  void _defaultStatusListener(String status) {
    print('Speech status: $status');
    _isListening = status == 'listening';
  }

  /// Default error listener
  void _defaultErrorListener(dynamic error) {
    print('Speech error: $error');
    _isListening = false;
  }

  /// Check if speech recognition is available on this device
  static Future<bool> isAvailable() async {
    final stt.SpeechToText speech = stt.SpeechToText();
    return await speech.initialize();
  }

  /// Dispose resources
  void dispose() {
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
  }
}