import 'package:flutter/widgets.dart';

import '../env.dart';
import '../models/scenario.dart';
import '../settings.dart';
import 'alerts.dart';
import 'haptics.dart';
import 'llm_service.dart';
import 'scripted.dart';
import 'storage.dart';
import 'stt_service.dart';
import 'tts_service.dart';

/// Everything both variants share, so the A/B compares only the interface.
/// A new bundle is created for every study task (fresh STT/LLM state).
class Services {
  Services._({
    required this.stt,
    required this.llm,
    required this.tts,
    required this.haptics,
    required this.alerts,
    required this.storage,
    required this.settings,
    this.scripted,
  });

  final SttService stt;
  final LlmService llm;
  final TtsService tts;
  final Haptics haptics;
  final Alerts alerts;
  final Storage storage;
  final AppSettings settings;

  /// Non-null when this bundle plays a role-play script.
  final ScriptedStt? scripted;

  static Services create({
    required Storage storage,
    required AppSettings settings,
    ScenarioForm? form,
    void Function(String signal)? onSignal,
  }) {
    final haptics = Haptics()..enabled = settings.haptics.value;
    final alerts = Alerts(haptics);
    final scripted = form == null ? null : ScriptedStt(form, onSignal: onSignal);
    final SttService stt = scripted ?? LiveSttService();
    final LlmService llm = scripted != null
        ? ScriptedLlm(stt: scripted, glossary: form!.glossary)
        : Env.hasLlm
            ? OpenRouterLlm()
            : ScriptedLlm.generic();
    final tts = TtsService(alerts: alerts, haptics: haptics)..stt = stt;
    tts.init();
    return Services._(
      stt: stt,
      llm: llm,
      tts: tts,
      haptics: haptics,
      alerts: alerts,
      storage: storage,
      settings: settings,
      scripted: scripted,
    );
  }

  void dispose() {
    tts.dispose();
    stt.dispose();
  }

  static Services of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ServicesScope>()!.services;

  /// For event handlers and callbacks: reads without registering a dependency.
  static Services read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ServicesScope>()!.services;
}

class ServicesScope extends InheritedWidget {
  const ServicesScope({super.key, required this.services, required super.child});

  final Services services;

  @override
  bool updateShouldNotify(ServicesScope old) => old.services != services;
}
