import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/models/scenario.dart';
import 'core/services/storage.dart';
import 'core/settings.dart';
import 'ux_kit/ux_controller.dart';

const _scenarioIds = ['warung', 'bank', 'cs'];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  final prefs = await SharedPreferences.getInstance();
  final storage = Storage();
  await storage.init();
  final scenarios = {
    for (final id in _scenarioIds)
      id: Scenario.parse(await rootBundle.loadString('assets/scenarios/$id.json')),
  };
  runApp(SwaranaApp(
    storage: storage,
    settings: AppSettings(prefs),
    ux: UxController(),
    scenarios: scenarios,
  ));
}
