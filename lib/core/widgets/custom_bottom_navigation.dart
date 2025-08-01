import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;


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
  late stt.SpeechToText _speechToText;
  bool _speechEnabled = false;
  String _lastWords = '';
  bool isListening = false;
  bool showResult = false;
  bool _isInitialized = false;
  String _currentStatus = '';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
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
    
    _initSpeech();
  }

  /// Initialize speech recognition
  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: (status) {
          if (mounted) {
            setState(() {
              _currentStatus = status;
              if (status == 'notListening') {
                isListening = false;
                _pulseController.stop();
                if (_lastWords.isNotEmpty) {
                  showResult = true;
                }
              }
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              isListening = false;
              _currentStatus = 'Error: ${error.errorMsg}';
              showResult = true;
            });
            _pulseController.stop();
          }
        },
      );
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        
        // Auto start listening when modal opens if speech is enabled
        if (_speechEnabled) {
          _startListening();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentStatus = 'Failed to initialize: $e';
          _isInitialized = true;
        });
      }
    }
  }

  /// Start listening for speech
  void _startListening() async {
    if (!_speechEnabled) return;
    
    setState(() {
      isListening = true;
      showResult = false;
      _lastWords = '';
    });
    _pulseController.repeat(reverse: true);
    
    await _speechToText.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _lastWords = result.recognizedWords;
          });
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: 'id_ID', // Indonesian locale
      cancelOnError: true,
      listenMode: stt.ListenMode.confirmation,
    );
  }

  /// Stop listening for speech
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      isListening = false;
      showResult = true;
    });
    _pulseController.stop();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speechToText.stop();
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
                  !_isInitialized 
                      ? 'Mempersiapkan...'
                      : !_speechEnabled 
                          ? 'Speech tidak tersedia'
                          : isListening 
                              ? 'Mendengarkan...' 
                              : 'Hasil tangkapan',
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
                  // Text content
                  if (!_isInitialized)
                    const Text(
                      'Mempersiapkan pengenalan suara...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    )
                  else if (!_speechEnabled)
                    Text(
                      _currentStatus.isNotEmpty 
                          ? _currentStatus 
                          : 'Speech recognition tidak tersedia.\nPastikan Anda telah memberikan izin microphone.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    )
                  else
                    Column(
                      children: [
                        Text(
                          _lastWords.isNotEmpty 
                              ? _lastWords 
                              : (isListening 
                                  ? 'Silakan berbicara...' 
                                  : 'Tekan tombol mic untuk mulai mendengarkan'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: _lastWords.isNotEmpty ? FontWeight.w500 : FontWeight.w400,
                            color: _lastWords.isNotEmpty ? Colors.black : Colors.grey,
                          ),
                        ),
                        if (isListening && _lastWords.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              '(masih mendengarkan...)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  
                  const SizedBox(height: 40),
                  
                  // Audio visualization or mic button
                  if (!_speechEnabled)
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic_off,
                        color: Colors.white,
                        size: 40,
                      ),
                    )
                  else if (isListening) 
                    Column(
                      children: [
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
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _stopListening,
                          child: const Text(
                            'Berhenti mendengarkan',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
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
                            onPressed: _startListening,
                            icon: const Icon(
                              Icons.mic,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _lastWords.isNotEmpty ? 'Tekan mic untuk ulang!' : 'Tekan mic untuk memulai!',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  
                  const Spacer(),
                  
                  // Bottom content
                  if (showResult && _lastWords.isNotEmpty) ...[
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
}