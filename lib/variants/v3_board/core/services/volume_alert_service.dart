import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class VolumeAlertService {
  VolumeAlertService._();

  static OverlayEntry? _overlayEntry;
  static Timer? _hideTimer;
  static bool _isShowing = false;

  static Future<void> showLowVolume(BuildContext context) async {
    if (_isShowing) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _isShowing = true;
    await _vibrate();

    _overlayEntry = OverlayEntry(
      builder: (context) => IgnorePointer(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: AnimatedOpacity(
                opacity: 1,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFFFB300)),
                      SizedBox(width: 12),
                      Text(
                        'Volume Handphone Terlalu Kecil',
                        style: TextStyle(
                          color: Color(0xFFFFB300),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);

    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), _hideAlert);
  }

  static void _hideAlert() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _hideTimer?.cancel();
    _hideTimer = null;
    _isShowing = false;
  }

  static Future<void> _vibrate() async {
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
}
