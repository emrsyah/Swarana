// CustomBottomNavigation.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:swarana/common/constant/assets.dart';

import '../services/speech_service.dart';

class CustomBottomNavigation extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigation({super.key, required this.currentIndex, required this.onTap});

  @override
  State<CustomBottomNavigation> createState() => _CustomBottomNavigationState();
}

class _CustomBottomNavigationState extends State<CustomBottomNavigation> {
  // SEMUA LOGIKA DAN STATE SPEECH RECOGNITION DIHAPUS DARI SINI

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
                      // Hanya panggil fungsi untuk menampilkan modal
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
      // Konstruktor ListeningModal tidak lagi memerlukan parameter state
      builder: (context) => const ListeningModal(),
    );
  }
}

class ListeningModal extends StatefulWidget {
  const ListeningModal({super.key});

  @override
  State<ListeningModal> createState() => _ListeningModalState();
}

class _ListeningModalState extends State<ListeningModal> with TickerProviderStateMixin {
  final SpeechService _speechService = SpeechService();
  double _currentFontSize = 16.0;

  @override
  void initState() {
    super.initState();
    _startSession();
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
    super.dispose();
  }

  void _stopAndClose() {
    _speechService.stopListening();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
      child: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: ValueListenableBuilder<bool>(
          valueListenable: _speechService.isListeningNotifier,
          builder: (context, isListening, child) {
            return ValueListenableBuilder<String>(
              valueListenable: _speechService.recognizedTextNotifier,
              builder: (context, recognizedText, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 10, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isListening ? 'Mendengarkan...' : 'Hasil Tangkapan',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          IconButton(onPressed: _stopAndClose, icon: const Icon(Icons.close)),
                        ],
                      ),
                    ),
                    _buildListeningView(isListening, recognizedText),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildListeningView(bool isListening, String recognizedText) {
    final bool showResult = !isListening && recognizedText.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        children: [
          if (recognizedText.isNotEmpty)
            Text(
              recognizedText,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: _currentFontSize, fontWeight: FontWeight.w500, height: 1.5),
            )
          else if (isListening)
            Text("")
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text("Tidak ada suara yang terdeteksi.", style: TextStyle(color: Colors.grey[600])),
            ),
          const SizedBox(height: 30),
          if (isListening)
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(color: HexColor('#D32F2F'), shape: BoxShape.circle),
              child: const Icon(Icons.mic, color: Colors.white, size: 40),
            )
          else
            Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(color: HexColor('#3C37AF'), shape: BoxShape.circle),
                  child: IconButton(onPressed: _startListening, icon: const Icon(Icons.mic, color: Colors.white, size: 40)),
                ),
                const SizedBox(height: 15),
                const Text('Tekan mic untuk lanjutkan obrolan', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          if (showResult) ...[
            const SizedBox(height: 30),
            _buildFontSizeControl(),
            const SizedBox(height: 20),
            const Text(
              'Menemukan kesalahan? Bantu kami meningkatkan akurasi dengan mengirimkan umpan balik.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFontSizeControl() {
    return Row(
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
    );
  }
}
