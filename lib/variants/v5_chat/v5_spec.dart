import 'package:flutter/material.dart';

import '../../core/models/session.dart';
import '../../variant/variant.dart';
import 'design/theme.dart';
import 'obrolan/obrolan_page.dart';
import 'onboarding/onboarding_page.dart';
import 'onboarding/splash_page.dart';
import 'riwayat/obrolan_detail_page.dart';
import 'riwayat/riwayat_page.dart';
import 'settings/settings_page.dart';
import 'transkrip/transkrip_detail_page.dart';
import 'transkrip/transkrip_page.dart';
import 'v5_routes.dart';

/// Iteration-5 chat app.
class V5Spec implements VariantSpec {
  @override
  final ThemeData theme = buildV5Theme();

  /// Study tasks start straight in the chat; normal use goes through splash.
  @override
  Widget home({required bool study}) => study ? const ObrolanPage() : const SplashPage();

  static T? _arg<T>(BuildContext ctx) => ModalRoute.of(ctx)?.settings.arguments as T?;

  @override
  Map<String, WidgetBuilder> get routes => {
        V5Routes.splash: (_) => const SplashPage(),
        V5Routes.onboarding: (_) => const OnboardingPage(),
        V5Routes.obrolan: (ctx) => ObrolanPage(resume: _arg<ChatSession>(ctx)),
        V5Routes.transkrip: (_) => const TranskripPage(),
        V5Routes.transkripDetail: (ctx) => TranskripDetailPage(transcript: _arg<TranscriptSession>(ctx)!),
        V5Routes.riwayat: (_) => const RiwayatPage(),
        V5Routes.chatDetail: (ctx) => ObrolanDetailPage(session: _arg<ChatSession>(ctx)!),
        V5Routes.settings: (_) => SettingsPage(),
      };
}
