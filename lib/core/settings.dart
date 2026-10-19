import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences shared across variants, persisted in SharedPreferences.
class AppSettings {
  AppSettings(this._prefs)
      : textScale = ValueNotifier(_prefs.getDouble('textScale') ?? 1.0),
        separateSpeakers = ValueNotifier(_prefs.getBool('separateSpeakers') ?? true),
        haptics = ValueNotifier(_prefs.getBool('haptics') ?? true),
        onboarded = ValueNotifier(_prefs.getBool('onboarded') ?? false) {
    textScale.addListener(() => _prefs.setDouble('textScale', textScale.value));
    separateSpeakers.addListener(() => _prefs.setBool('separateSpeakers', separateSpeakers.value));
    haptics.addListener(() => _prefs.setBool('haptics', haptics.value));
    onboarded.addListener(() => _prefs.setBool('onboarded', onboarded.value));
  }

  final SharedPreferences _prefs;

  /// Reading text size: one setting used by Obrolan and Transkrip.
  static const textScaleSteps = [1.0, 1.2, 1.45, 1.75];
  final ValueNotifier<double> textScale;

  /// "Pisahkan pembicara": show each partner voice as its own speaker.
  final ValueNotifier<bool> separateSpeakers;
  final ValueNotifier<bool> haptics;
  final ValueNotifier<bool> onboarded;

  SharedPreferences get prefs => _prefs;
}
