import 'package:flutter/material.dart';

import '../core/models/app_variant.dart';
import '../core/models/scenario.dart';
import '../core/services/storage.dart';
import '../core/settings.dart';
import '../ux_kit/ux_controller.dart';

export '../core/models/app_variant.dart';

/// Everything a variant contributes: its own design system and screens.
/// Variants never import each other.
abstract class VariantSpec {
  ThemeData get theme;

  /// First screen. [study] skips splash/onboarding so tasks start in the chat.
  Widget home({required bool study});

  Map<String, WidgetBuilder> get routes;
}

/// App-level handle the screens and researcher panel talk to.
abstract class AppHandle {
  UxController get ux;
  Storage get storage;
  AppSettings get settings;
  Map<String, Scenario> get scenarios;
  AppVariant get variant;

  /// Free-use switch (no study running).
  void switchVariant(AppVariant v);

  static AppHandle of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.handle;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.handle, required this.variant, required super.child});

  final AppHandle handle;
  final AppVariant variant;

  @override
  bool updateShouldNotify(AppScope old) => old.variant != variant;
}
