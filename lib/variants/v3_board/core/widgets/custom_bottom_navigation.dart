// CustomBottomNavigation.dart

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:swarana/variants/v3_board/common/constant/assets.dart'; // Pastikan path ini benar
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:vibration/vibration.dart';


import '../../../../core/models/message.dart';
import '../services/board_input_focus_service.dart';
import '../services/v3_backend.dart';
import '../services/gemini_suggestion_service.dart';
import '../services/speech_service.dart'; // Pastikan path ini benar
import '../services/volume_alert_service.dart';

class CustomBottomNavigation extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<CustomBottomNavigation> createState() => _CustomBottomNavigationState();
}

class _CustomBottomNavigationState extends State<CustomBottomNavigation> {
  // ... (Tidak ada perubahan di sini)
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          SafeArea(
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _buildNavItem(
                      index: 0,
                      icon: IconAssets.messageText,
                      label: 'Bicara',
                      onTap: () => widget.onTap(0),
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      index: 1,
                      icon: IconAssets.transkrip,
                      label: 'Transkrip',
                      onTap: () => widget.onTap(1),
                    ),
                  ),
                  const SizedBox(width: 60),
                  Expanded(
                    child: _buildNavItem(
                      index: 2,
                      icon: IconAssets.history,
                      label: 'Riwayat',
                      onTap: () => widget.onTap(2),
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      index: 3,
                      icon: IconAssets.setting,
                      label: 'Pengaturan',
                      onTap: () => widget.onTap(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -25,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    color: HexColor('#3C37AF'),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: HexColor('#3C37AF').withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showListeningModal(context),
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: Icon(
                          IconsaxPlusBold.microphone_2,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Dengar",
                  style: TextStyle(
                    color: HexColor('#3C37AF'),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isActive = widget.currentIndex == index;
    final color = isActive ? HexColor('#3C37AF') : Colors.grey.shade400;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SvgPicture.asset(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showListeningModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ListeningModal(),
    );
  }
}

// =========================================================================
// MODIFIKASI UTAMA ADA DI DALAM LISTENINGMODAL
// =========================================================================

class ListeningModal extends StatefulWidget {
  const ListeningModal({super.key});

  @override
  State<ListeningModal> createState() => _ListeningModalState();
}

class _ListeningModalState extends State<ListeningModal>
    with TickerProviderStateMixin {
  final SpeechService _speechService = SpeechService();
  double _currentFontSize = 20.0;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _isFullScreen = false;
  late final FlutterTts _flutterTts;
  GeminiSuggestionService? _suggestionService;
  List<String> _suggestions = const [];
  bool _isFetchingSuggestions = false;
  String? _suggestionError;
  String? _currentPrompt;
  bool _hasExpandedForCurrentResult = false;
  bool _hasCompletedCurrentPrompt = false;
  bool _isSuggestionFetchQueued = false;
  int? _selectedSuggestionIndex;
  final TextEditingController _manualInputController = TextEditingController();
  String _manualInputDraft = '';
  bool _manualInputHasError = false;
  bool _hasSignaledEmptyCapture = false;

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    unawaited(_configureTts());
    _sheetController.addListener(_updateFullScreenState);
    _startSession();
  }

  void _updateFullScreenState() {
    final isCurrentlyFull = _sheetController.size > 0.9;
    if (isCurrentlyFull != _isFullScreen) {
      setState(() {
        _isFullScreen = isCurrentlyFull;
      });
    }
  }

  Future<void> _startSession() async {
    await Future.delayed(const Duration(milliseconds: 200));
    bool isInitialized = await _speechService.initialize();
    if (isInitialized) {
      _startListening();
    } else {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin mikrofon tidak diberikan atau tidak tersedia.'),
          ),
        );
      }
    }
  }

  Future<void> _startListening() async {
    if (mounted) {
      setState(() {
        _suggestions = const [];
        _suggestionError = null;
        _isFetchingSuggestions = false;
        _currentPrompt = null;
        _hasExpandedForCurrentResult = false;
        _hasCompletedCurrentPrompt = false;
        _isSuggestionFetchQueued = false;
        _selectedSuggestionIndex = null;
        _manualInputController.clear();
        _manualInputDraft = '';
        _manualInputHasError = false;
        _hasSignaledEmptyCapture = false;
      });
    }
    await _speechService.startListening(pauseFor: const Duration(seconds: 4));
  }

  Future<void> _configureTts() async {
    await _flutterTts.setLanguage('id-ID');
    await _flutterTts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _speechService.stopListening();
    _sheetController.removeListener(_updateFullScreenState);
    _sheetController.dispose();
    _manualInputController.dispose();
    unawaited(_flutterTts.stop());
    super.dispose();
  }

  void _stopAndClose() {
    _speechService.stopListening();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // 1. Bungkus dengan ValueListenableBuilder untuk mendengarkan status isListening
    return ValueListenableBuilder<bool>(
      valueListenable: _speechService.isListeningNotifier,
      builder: (context, isListening, _) {
        // 2. Bungkus lagi untuk mendengarkan hasil teks
        return ValueListenableBuilder<String>(
          valueListenable: _speechService.recognizedTextNotifier,
          builder: (context, recognizedText, _) {
            // 3. Tentukan ukuran sheet berdasarkan kondisi
            final bool hasResults = recognizedText.isNotEmpty;
            double initialSize;
            double minSize;

            // Kondisi 1: Sedang mendengarkan ATAU belum ada hasil
            if (isListening || !hasResults) {
              initialSize = 0.25;
              minSize = 0.25;
            }
            // Kondisi 2: Selesai mendengarkan DAN sudah ada hasil
            else {
              initialSize = 0.5;
              minSize = 0.4;
            }

            // 4. Gunakan ukuran dinamis pada DraggableScrollableSheet
            return DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: initialSize, // <- Diubah
              minChildSize: minSize, // <- Diubah
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                _handleSpeechLifecycle(
                  isListening: isListening,
                  recognizedText: recognizedText,
                );
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            const SizedBox(height: 12),
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            if (isListening)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF8E6),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFFFB300),
                                      width: 1.5,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        color: Color(0xFFFFB300),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Pastikan mikrofon handphone mendekati sumber suara',
                                          style: TextStyle(
                                            color: Color(0xFFFFB300),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isListening
                                      ? 'Mendengarkan...'
                                      : 'Hasil tangkapan',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: HexColor("#717884"),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _stopAndClose,
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Logika untuk menampilkan view tidak perlu diubah
                            if (isListening)
                              _buildListeningView()
                            else if (hasResults)
                              _buildResultView(recognizedText)
                            else
                              _buildEmptyView(),
                          ],
                        ),
                      ),
                      // Bagian bawah ini juga tidak perlu diubah
                      if (!isListening) _buildFixedBottomSection(),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _handleSpeechLifecycle({
    required bool isListening,
    required String recognizedText,
  }) {
    if (isListening) {
      _hasExpandedForCurrentResult = false;
      return;
    }

    final trimmed = recognizedText.trim();
    if (trimmed.isEmpty) {
      if (!_hasSignaledEmptyCapture) {
        _hasSignaledEmptyCapture = true;
        unawaited(_vibrateBriefly());
      }
      return;
    }

    _hasSignaledEmptyCapture = false;

    if (!_hasExpandedForCurrentResult) {
      _hasExpandedForCurrentResult = true;
      _expandSheetFully();
    }

    _scheduleSuggestionFetch(trimmed);
  }

  void _scheduleSuggestionFetch(String prompt, {bool force = false}) {
    if (!force &&
        _currentPrompt == prompt &&
        (_isFetchingSuggestions ||
            _hasCompletedCurrentPrompt ||
            _isSuggestionFetchQueued)) {
      return;
    }
    _currentPrompt = prompt;
    _hasCompletedCurrentPrompt = false;
    _isSuggestionFetchQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isSuggestionFetchQueued = false;
      _fetchSuggestions(prompt);
    });
  }

  Future<void> _fetchSuggestions(String prompt) async {
    if (!mounted) return;
    setState(() {
      _isFetchingSuggestions = true;
      _suggestionError = null;
      _suggestions = const [];
      _selectedSuggestionIndex = null;
    });

    try {
      _suggestionService ??= GeminiSuggestionService();
      final results = await _suggestionService!.suggestionsFromTranscript(
        prompt,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _selectedSuggestionIndex = null;
      });
    } on SuggestionGenerationException catch (error) {
      if (!mounted) return;
      setState(() {
        _suggestionError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _suggestionError = 'Terjadi kesalahan: $error';
      });
    } finally {
      _hasCompletedCurrentPrompt = true;
      if (mounted) {
        setState(() {
          _isFetchingSuggestions = false;
        });
      } else {
        _isFetchingSuggestions = false;
      }
    }
  }

  void _expandSheetFully() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      double? size;
      try {
        size = _sheetController.size;
      } catch (_) {
        size = null;
      }
      if (size != null && size >= 0.9) return;
      _sheetController
          .animateTo(
            0.95,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          )
          .catchError((_) {});
    });
  }

  void _retrySuggestions() {
    final prompt = _currentPrompt;
    if (prompt == null) return;
    _scheduleSuggestionFetch(prompt, force: true);
  }

  void _onSuggestionTap(int index) {
    if (index < 0 || index >= _suggestions.length) return;
    final suggestion = _suggestions[index];
    setState(() {
      _selectedSuggestionIndex = index;
    });
    unawaited(_speakSuggestion(suggestion));
  }

  void _handleKeyboardTap() {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BoardInputFocusService.requestFocus();
    });
  }

  void _submitManualInput() {
    final manualText = _manualInputController.text.trim();
    if (manualText.isEmpty) {
      setState(() {
        _manualInputHasError = true;
      });
      return;
    }

    setState(() {
      _manualInputHasError = false;
      _manualInputDraft = manualText;
      _selectedSuggestionIndex = null;
      _hasSignaledEmptyCapture = false;
    });

    FocusScope.of(context).unfocus();
    _speechService.recognizedTextNotifier.value = manualText;
    _hasExpandedForCurrentResult = false;
    _scheduleSuggestionFetch(manualText, force: true);
  }

  Future<void> _checkVolumeAndWarn() async {
    try {
      final volume = await VolumeController.instance.getVolume();
      if (volume <= 0.2) {
        if (!mounted) return;
        VolumeAlertService.showLowVolume(context);
      }
    } on MissingPluginException {
      // Volume controller not available on this platform.
    } catch (_) {
      // ignore unsupported volume queries
    }
  }

  Future<void> _vibrateBriefly() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 120);
      } else {
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {
      await HapticFeedback.mediumImpact();
    }
  }

  Future<void> _speakSuggestion(String text) async {
    final phrase = text.trim();
    if (phrase.isEmpty) return;
    await _flutterTts.stop();
    V3Backend.sent(phrase, MessageSource.suggestion);
    await _checkVolumeAndWarn();
    await _flutterTts.speak(phrase);
  }

  // MODIFIKASI: Widget ini sekarang hanya berisi bagian yang di-scroll
  Widget _buildResultView(String recognizedText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                recognizedText,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: _currentFontSize,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard),
              color: HexColor('#3C37AF'),
              tooltip: 'Beralih ke input teks',
              onPressed: _handleKeyboardTap,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildFontSizeControl(),
        const SizedBox(height: 24),
        Visibility(visible: _isFullScreen, child: _buildSuggestionGrid()),
        const SizedBox(height: 20), // Padding di bawah sebelum konten fixed
      ],
    );
  }

  // MODIFIKASI: Widget ini sekarang hanya berisi bagian yang di-scroll
  Widget _buildEmptyView() {
    final primary = HexColor('#3C37AF');
    final accent = HexColor('#E3DEFF');
    final secondary = HexColor('#5B4CC4');
    final isSubmitEnabled = _manualInputDraft.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFEEF1),
              ),
              child: const Center(
                child: Icon(Icons.mic_off_rounded,
                    color: Color(0xFFD94C63), size: 34),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Suara Gagal Terdeteksi🥲',
              style: TextStyle(
                color: secondary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dekatkan mikrofon handphone ke sumber suara untuk deteksi optimal',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HexColor('#717884'),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Symbols.lift_to_talk,
                    color: secondary, size: 24),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded,
                    color: secondary, size: 20),
                const SizedBox(width: 8),
                Icon(MdiIcons.accountVoice
                , color: secondary, size: 24),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startListening,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Coba Lagi'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Atau coba ketik di sini',
              style: TextStyle(
                color: HexColor('#9197A6'),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manualInputController,
              onChanged: (value) {
                setState(() {
                  _manualInputDraft = value;
                  if (_manualInputHasError && value.trim().isNotEmpty) {
                    _manualInputHasError = false;
                  }
                });
              },
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Ketik pesan',
                hintStyle: TextStyle(color: HexColor('#B0B5C3'), fontSize: 12),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: accent.withOpacity(0.8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: accent.withOpacity(0.8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: primary, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
                ),
                errorText: _manualInputHasError
                    ? 'Tuliskan pesan untuk melanjutkan'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSubmitEnabled ? _submitManualInput : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: secondary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: accent.withOpacity(0.6),
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Cek Rekomendasi Jawaban'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // BARU: Widget untuk bagian bawah yang posisinya tetap
  Widget _buildFixedBottomSection() {
    // Cek apakah ada hasil untuk menampilkan teks feedback
    final bool hasResults =
        _speechService.recognizedTextNotifier.value.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        10,
        20,
        30,
      ), // Padding untuk bagian bawah
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: HexColor('#3C37AF'),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _startListening,
              icon: const Icon(Icons.mic, color: Colors.white, size: 50),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            'Tekan mic untuk lanjutkan obrolan',
            style: TextStyle(fontSize: 12, color: HexColor('#929292')),
          ),
          // Tampilkan teks feedback hanya jika ada hasil
          if (hasResults) ...[
            const SizedBox(height: 30),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(fontSize: 16.0),
                children: <TextSpan>[
                  const TextSpan(
                    text:
                        'Menemukan kesalahan? Bantu kami meningkatkan akurasi dengan mengirimkan ',
                    style: TextStyle(color: Colors.black, fontSize: 12),
                  ),
                  TextSpan(
                    text: 'umpan balik',
                    style: TextStyle(
                      color: HexColor("#3C37AF"),
                      decoration: TextDecoration.underline,
                      fontSize: 12,
                    ),
                    recognizer:
                        TapGestureRecognizer()
                          ..onTap = () {
                            print('Tautan "umpan balik" diklik!');
                          },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Tidak ada perubahan pada method di bawah ini
  Widget _buildListeningView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: HexColor('#D32F2F'),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.mic, color: Colors.white, size: 40),
      ),
    );
  }

  Widget _buildSuggestionGrid() {
    Widget content;
    if (_isFetchingSuggestions) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_suggestionError != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _suggestionError!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _retrySuggestions,
            child: const Text('Coba lagi'),
          ),
        ],
      );
    } else if (_suggestions.isEmpty) {
      content = const Center(
        child: Text(
          'Saran belum tersedia untuk transkrip ini.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      );
    } else {
      content = GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return _SuggestionCard(
            suggestion: suggestion,
            isSelected: _selectedSuggestionIndex == index,
            onTap: () => _onSuggestionTap(index),
          );
        },
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: HexColor('#3C37AF').withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }

  Widget _buildFontSizeControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Row(
        children: [
          const Text("Aa", style: TextStyle(fontSize: 12)),
          Expanded(
            child: Slider(
              value: _currentFontSize,
              min: 12.0,
              max: 28.0,
              activeColor: HexColor('#3C37AF'),
              onChanged: (newValue) {
                setState(() {
                  _currentFontSize = newValue;
                });
              },
            ),
          ),
          const Text("Aa", style: TextStyle(fontSize: 20)),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final String suggestion;
  final VoidCallback onTap;
  final bool isSelected;

  const _SuggestionCard({
    required this.suggestion,
    required this.onTap,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color:
              isSelected ? HexColor('#3C37AF').withOpacity(0.12) : Colors.white,
          border: Border.all(
            color: isSelected ? HexColor('#1E2A78') : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? HexColor('#3C37AF') : Colors.grey)
                  .withOpacity(isSelected ? 0.2 : 0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            suggestion,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
