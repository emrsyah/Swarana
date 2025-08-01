import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../services/speech_service.dart';


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

class _CustomBottomNavigationState extends State<CustomBottomNavigation> 
    with TickerProviderStateMixin {
  bool isFloatingMenuOpen = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _animationController.stop();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PortalTarget(
      visible: isFloatingMenuOpen,
      portalFollower: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          if (!mounted) return;
          await _animationController.reverse();
          if (mounted) {
            setState(() {
              isFloatingMenuOpen = false;
            });
          }
        },
        child: Container(
          color: Colors.transparent,
          child: Center(
            child: _buildFloatingMenu(),
          ),
        ),
      ),
      anchor: const Aligned(
        follower: Alignment.center,
        target: Alignment.center,
      ),
      child: Container(
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
        child: SafeArea(
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _buildNavItem(
                    index: 0,
                    icon: IconsaxPlusLinear.message_text,
                    outlineIcon: IconsaxPlusLinear.message_text,
                    label: 'Bicara',
                    onTap: () => widget.onTap(0),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -25),
                  child: Container(
                    width: 75,
                    height: 75,
                    decoration: BoxDecoration(
                      color: isFloatingMenuOpen 
                          ? HexColor('#3C37AF').withOpacity(0.6)
                          : HexColor('#3C37AF'),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: HexColor('#3C37AF').withOpacity(0.4),
                          spreadRadius: 2,
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          if (!mounted) return;
                          
                          if (isFloatingMenuOpen) {
                            // Close the menu
                            await _animationController.reverse();
                            if (mounted) {
                              setState(() {
                                isFloatingMenuOpen = false;
                              });
                            }
                          } else {
                            // Open the menu
                            setState(() {
                              isFloatingMenuOpen = true;
                            });
                            _animationController.forward();
                          }
                        },
                        customBorder: const CircleBorder(),
                        child: Center(
                          child: Icon(
                            isFloatingMenuOpen 
                                ? Icons.close 
                                : IconsaxPlusBold.microphone_2,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    index: 2,
                    icon: Icons.history_rounded,
                    outlineIcon: Icons.history_outlined,
                    label: 'Riwayat',
                    onTap: () => widget.onTap(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingMenu() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: const Offset(0, -100),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Left button (Dengar)
              Transform.translate(
                offset: Offset(-10 * _animationController.value, 0),
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildFloatingButton(
                    label: 'Dengar',
                    icon: IconsaxPlusBold.microphone_2,
                    onTap: () async {
                      if (!mounted) return;
                      await _animationController.reverse();
                      if (mounted) {
                        setState(() {
                          isFloatingMenuOpen = false;
                        });
                        // Show listening modal
                        _showListeningModal(context);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 20), // Space for the mic button in the middle
              // Right button (Transkrip)
              Transform.translate(
                offset: Offset(10 * _animationController.value, 0),
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildFloatingButton(
                    label: 'Transkrip',
                    icon: Icons.subtitles,
                    onTap: () async {
                      if (!mounted) return;
                      await _animationController.reverse();
                      if (mounted) {
                        setState(() {
                          isFloatingMenuOpen = false;
                        });
                        // Navigate to Transkrip page
                        Navigator.pushNamed(context, '/transkrip');
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        decoration: BoxDecoration(
          color: HexColor('#3C37AF'),
          borderRadius: BorderRadius.circular(30),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData outlineIcon,
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
            Icon(
              isActive ? icon : outlineIcon,
              color: color,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color, 
                fontSize: 14,
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

class ListeningModal extends StatefulWidget {
  const ListeningModal({Key? key}) : super(key: key);

  @override
  State<ListeningModal> createState() => _ListeningModalState();
}

class _ListeningModalState extends State<ListeningModal>
    with TickerProviderStateMixin {
  bool isListening = false;
  bool showResult = false;
  bool _speechEnabled = false;
  String _recognizedText = '';
  String _statusMessage = '';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final SpeechService _speechService = SpeechService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    try {
      _speechEnabled = await _speechService.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );
      
      if (_speechEnabled) {
        setState(() {
          _statusMessage = 'Siap mendengarkan. Tekan mikrofon untuk memulai.';
        });
      } else {
        setState(() {
          _statusMessage = 'Speech recognition tidak tersedia di perangkat ini.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error menginisialisasi speech recognition: $e';
      });
    }
  }

  void _onSpeechStatus(String status) {
    setState(() {
      if (status == 'listening') {
        isListening = true;
        _statusMessage = 'Mendengarkan...';
        _pulseController.repeat(reverse: true);
      } else if (status == 'notListening') {
        isListening = false;
        _pulseController.stop();
        if (_recognizedText.isNotEmpty) {
          showResult = true;
          _statusMessage = 'Selesai mendengarkan';
        } else {
          _statusMessage = 'Tidak ada suara yang terdeteksi';
        }
      } else if (status == 'done') {
        isListening = false;
        showResult = true;
        _pulseController.stop();
        _statusMessage = 'Selesai';
      }
    });
  }

  void _onSpeechError(dynamic error) {
    setState(() {
      isListening = false;
      _pulseController.stop();
      _statusMessage = 'Error: ${error.toString()}';
    });
  }

  Future<void> _startListening() async {
    if (!_speechEnabled) return;
    
    try {
      setState(() {
        _recognizedText = '';
        showResult = false;
        _statusMessage = 'Memulai...';
      });
      
      await _speechService.startListening(
        onResult: (recognizedWords) {
          setState(() {
            _recognizedText = recognizedWords;
          });
        },
        localeId: 'id_ID',
        timeout: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Error memulai listening: $e';
      });
    }
  }

  Future<void> _stopListening() async {
    await _speechService.stopListening();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speechService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getHeaderText(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Status message
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Recognized text content
                  if (_recognizedText.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        _recognizedText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ] else if (!isListening && showResult) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Text(
                        'Tidak ada teks yang berhasil dikenali. Silakan coba lagi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 40),
                  
                  // Audio visualization or mic button
                  if (isListening) 
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: HexColor('#3C37AF'),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mic,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        );
                      },
                    )
                  else
                    Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: HexColor('#3C37AF'),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: _speechEnabled ? _startListening : null,
                            icon: const Icon(
                              Icons.mic,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _speechEnabled 
                              ? (showResult ? 'Tekan mic untuk ulang!' : 'Tekan mic untuk memulai!')
                              : 'Speech recognition tidak tersedia',
                          style: TextStyle(
                            fontSize: 14,
                            color: _speechEnabled ? Colors.grey : Colors.red.shade400,
                          ),
                        ),
                      ],
                    ),
                  
                  const Spacer(),
                  
                  // Stop listening button when actively listening
                  if (isListening)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _stopListening,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Berhenti Mendengarkan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  
                  // Bottom content  
                  if (showResult && _recognizedText.isNotEmpty) ...[
                    const Text(
                      'Menemukan kesalahan? Bantu kami meningkatkan akurasi dengan mengirimkan umpan balik.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Handle complaint submission
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HexColor('#3C37AF'),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Kirim komplain',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getHeaderText() {
    if (isListening) {
      return 'Mendengarkan...';
    } else if (showResult) {
      return 'Hasil Tangkapan';
    } else if (_speechEnabled) {
      return 'Speech Recognition';
    } else {
      return 'Speech Tidak Tersedia';
    }
  }
}