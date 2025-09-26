// CustomBottomNavigation.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:swarana/common/constant/assets.dart'; // Pastikan path ini benar

import '../services/speech_service.dart'; // Pastikan path ini benar

class CustomBottomNavigation extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigation({super.key, required this.currentIndex, required this.onTap});

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
          BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 0, blurRadius: 10, offset: const Offset(0, -5)),
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
                    child: _buildNavItem(index: 2, icon: IconAssets.history, label: 'Riwayat', onTap: () => widget.onTap(2)),
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
                    boxShadow: [BoxShadow(color: HexColor('#3C37AF').withOpacity(0.3), blurRadius: 10, spreadRadius: 2)],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showListeningModal(context),
                      customBorder: const CircleBorder(),
                      child: Center(child: Icon(IconsaxPlusBold.microphone_2, color: Colors.white, size: 40)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text("Dengar", style: TextStyle(color: HexColor('#3C37AF'), fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({required int index, required String icon, required String label, required VoidCallback onTap}) {
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
              style: TextStyle(color: color, fontSize: 10, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400),
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

class _ListeningModalState extends State<ListeningModal> with TickerProviderStateMixin {
  final SpeechService _speechService = SpeechService();
  double _currentFontSize = 20.0;
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Izin mikrofon tidak diberikan atau tidak tersedia.')));
      }
    }
  }

  Future<void> _startListening() async {
    await _speechService.startListening(pauseFor: const Duration(seconds: 4));
  }

  @override
  void dispose() {
    _speechService.stopListening();
    _sheetController.removeListener(_updateFullScreenState);
    _sheetController.dispose();
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
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
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
                                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isListening ? 'Mendengarkan...' : 'Hasil tangkapan',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: HexColor("#717884")),
                                ),
                                IconButton(onPressed: _stopAndClose, icon: const Icon(Icons.close)),
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

  // MODIFIKASI: Widget ini sekarang hanya berisi bagian yang di-scroll
  Widget _buildResultView(String recognizedText) {
    return Column(
      children: [
        Text(
          recognizedText,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: _currentFontSize, fontWeight: FontWeight.w500, height: 1.5),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Text(
        "Tidak ada suara yang terdeteksi.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[600], fontSize: 16),
      ),
    );
  }

  // BARU: Widget untuk bagian bawah yang posisinya tetap
  Widget _buildFixedBottomSection() {
    // Cek apakah ada hasil untuk menampilkan teks feedback
    final bool hasResults = _speechService.recognizedTextNotifier.value.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30), // Padding untuk bagian bawah
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(color: HexColor('#3C37AF'), shape: BoxShape.circle),
            child: IconButton(onPressed: _startListening, icon: const Icon(Icons.mic, color: Colors.white, size: 50)),
          ),
          const SizedBox(height: 15),
          Text('Tekan mic untuk lanjutkan obrolan', style: TextStyle(fontSize: 12, color: HexColor('#929292'))),
          // Tampilkan teks feedback hanya jika ada hasil
          if (hasResults) ...[
            const SizedBox(height: 30),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(fontSize: 16.0),
                children: <TextSpan>[
                  const TextSpan(
                    text: 'Menemukan kesalahan? Bantu kami meningkatkan akurasi dengan mengirimkan ',
                    style: TextStyle(color: Colors.black, fontSize: 12),
                  ),
                  TextSpan(
                    text: 'umpan balik',
                    style: TextStyle(color: HexColor("#3C37AF"), decoration: TextDecoration.underline, fontSize: 12),
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
        decoration: BoxDecoration(color: HexColor('#D32F2F'), shape: BoxShape.circle),
        child: const Icon(Icons.mic, color: Colors.white, size: 40),
      ),
    );
  }

  Widget _buildSuggestionGrid() {
    final suggestions = [
      'Saya baik-baik saja',
      'Saya merasa pusing',
      'Saya merasa mual',
      'Saya membutuhkan bantuan',
      'Saya butuh istirahat',
      'Saya merasa lelah',
    ];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: HexColor('#3C37AF').withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        shrinkWrap: true,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          // final isSelected = _selectedText == sentence.text;

          return _SuggestionCard(suggestion: suggestion);
        },
      ),
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

  const _SuggestionCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Text(
          suggestion,
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
        ),
      ),
    );
  }
}
