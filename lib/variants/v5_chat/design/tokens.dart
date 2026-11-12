import 'package:flutter/material.dart';

/// v5 design tokens, read from design/v5/screens/*.png.
/// Deviations from Figma are marked "REVIEW:" and listed in
/// docs/design-deviations.md.
class V5Colors {
  static const primary = Color(0xFF1F4FFF);
  static const primaryDark = Color(0xFF1539C7);
  static const ink = Color(0xFF1A1A1A);

  /// Secondary text. Darkened from the Figma grey (#9CA3AF-ish) to pass 4.5:1.
  static const muted = Color(0xFF5B6270);
  static const border = Color(0xFFE3E6EC);
  static const page = Color(0xFFF7F9FC);
  static const surface = Colors.white;

  /// Figma: own bubbles grey once spoken, light blue with a blue outline
  /// while being spoken; partner bubbles white with a thin border.
  static const myBubble = Color(0xFFF1F2F5);
  static const myBubbleSpeaking = Color(0xFFE6ECFF);
  static const partnerBubble = Colors.white;
  static const aiTint = Color(0xFFEAF0FF);
  static const pillBorder = Color(0xFF8EA6FF);

  static const warningBg = Color(0xFFFFF8E6);
  static const warningBorder = Color(0xFFF5C451);
  static const warningIcon = Color(0xFFB45309);
  static const error = Color(0xFFDC2626);
  static const errorBg = Color(0xFFFEF2F2);
  static const success = Color(0xFF15803D);
  static const highlight = Color(0xFFF5B000);
  static const recording = Color(0xFFEF4444);
}

/// Per-speaker colours, Figma order: Pembicara 1 blue, Pembicara 2 green.
/// All pass 4.5:1 on white for the coloured name label.
const speakerPalette = [
  Color(0xFF2F55E4),
  Color(0xFF15803D),
  Color(0xFFC2410C),
  Color(0xFF7E3AF2),
  Color(0xFFBE185D),
  Color(0xFF0F766E),
];

Color speakerColor(int index) => speakerPalette[index % speakerPalette.length];

class V5Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class V5Radius {
  static const bubble = 14.0;
  static const card = 16.0;
  static const pill = 999.0;
}

/// Minimum touch target (Material/WCAG).
const minTouch = 48.0;
