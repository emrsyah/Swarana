import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildV5Theme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: V5Colors.primary,
    primary: V5Colors.primary,
    surface: V5Colors.surface,
    error: V5Colors.error,
  ).copyWith(onSurface: V5Colors.ink, onSurfaceVariant: V5Colors.muted, outline: V5Colors.border);

  const text = TextTheme(
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: V5Colors.ink),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: V5Colors.ink),
    titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: V5Colors.ink),
    titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: V5Colors.ink),
    // Chat and transcript body: 17 px, generous line height, never justified.
    bodyLarge: TextStyle(fontSize: 17, height: 1.45, color: V5Colors.ink),
    bodyMedium: TextStyle(fontSize: 15, height: 1.4, color: V5Colors.ink),
    bodySmall: TextStyle(fontSize: 13, height: 1.35, color: V5Colors.muted),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: V5Colors.muted),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: scheme,
    scaffoldBackgroundColor: V5Colors.page,
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: V5Colors.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: V5Colors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w500, color: V5Colors.ink),
    ),
    dividerTheme: const DividerThemeData(color: V5Colors.border, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(minTouch, minTouch),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(minTouch, minTouch),
        shape: const StadiumBorder(),
        side: const BorderSide(color: V5Colors.primary),
        foregroundColor: V5Colors.primary,
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(minTouch, minTouch)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      hintStyle: const TextStyle(color: V5Colors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: V5Colors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: V5Colors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: V5Colors.primary, width: 1.5)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: V5Colors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: V5Colors.surface, surfaceTintColor: Colors.transparent),
    drawerTheme: const DrawerThemeData(backgroundColor: V5Colors.surface, surfaceTintColor: Colors.transparent),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        // Selected segment must read as selected (on device the white-on-grey
        // version looked like the unselected one).
        selectedBackgroundColor: V5Colors.aiTint,
        selectedForegroundColor: V5Colors.primary,
        backgroundColor: V5Colors.surface,
        side: const BorderSide(color: V5Colors.border),
        minimumSize: const Size(0, 44),
      ),
    ),
  );
}
