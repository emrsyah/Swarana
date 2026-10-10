import 'package:flutter/material.dart';

import 'core/models/scenario.dart';
import 'core/services/services.dart';
import 'core/services/storage.dart';
import 'core/settings.dart';
import 'ux_kit/results_page.dart';
import 'ux_kit/ux_controller.dart';
import 'ux_kit/ux_harness.dart';
import 'ux_kit/ux_navigator_observer.dart';
import 'variant/researcher_panel.dart';
import 'variant/variant.dart';
import 'variants/v3_board/v3_spec.dart';
import 'variants/v5_chat/v5_spec.dart';

/// Root: owns the shared services and the active variant. Switching variant
/// (or starting a study task) bumps [_epoch], which rebuilds the whole
/// MaterialApp with fresh services, navigator and observer.
class SwaranaApp extends StatefulWidget {
  const SwaranaApp({
    super.key,
    required this.storage,
    required this.settings,
    required this.ux,
    required this.scenarios,
  });

  final Storage storage;
  final AppSettings settings;
  final UxController ux;
  final Map<String, Scenario> scenarios;

  @override
  State<SwaranaApp> createState() => _SwaranaAppState();
}

class _SwaranaAppState extends State<SwaranaApp> implements AppHandle, UxHost {
  static final Map<AppVariant, VariantSpec> _specs = {
    AppVariant.v3Board: V3Spec(),
    AppVariant.v5Chat: V5Spec(),
  };

  late AppVariant _variant;
  late Services _services;
  int _epoch = 0;
  late GlobalKey<NavigatorState> _navKey;
  late UxNavigatorObserver _observer;

  @override
  UxController get ux => widget.ux;
  @override
  Storage get storage => widget.storage;
  @override
  AppSettings get settings => widget.settings;
  @override
  Map<String, Scenario> get scenarios => widget.scenarios;
  @override
  AppVariant get variant => _variant;

  @override
  void initState() {
    super.initState();
    final saved = settings.prefs.getString('variant');
    _variant = AppVariant.values.where((v) => v.name == saved).firstOrNull ?? AppVariant.v5Chat;
    _services = Services.create(storage: storage, settings: settings);
    _newShell();
    // Events are persisted through UxHost.log; the default sink mirrors them to the console.
    ux.host = this;
  }

  void _newShell() {
    _navKey = GlobalKey<NavigatorState>();
    _observer = UxNavigatorObserver(ux);
  }

  void _rebuild(AppVariant v, Services s) {
    final old = _services;
    setState(() {
      _variant = v;
      _services = s;
      _epoch++;
      _newShell();
    });
    // Dispose after the old tree is gone.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  // ---------------- AppHandle ----------------

  @override
  void switchVariant(AppVariant v) {
    settings.prefs.setString('variant', v.name);
    _rebuild(v, Services.create(storage: storage, settings: settings));
  }

  // ---------------- UxHost ----------------

  @override
  void prepareTask(AppVariant v, String scenarioId, String form) {
    final config = ux.config!;
    final f = scenarios[scenarioId]!.forms[form]!;
    _rebuild(
      v,
      Services.create(
        storage: storage,
        settings: settings,
        form: config.scripted ? f : null,
        onSignal: ux.signal,
      ),
    );
  }

  @override
  void endStudy() => switchVariant(_variant);

  @override
  Duration get scriptedWait => _services.scripted?.waited ?? Duration.zero;

  @override
  Future<void> save(String participantId, Map<String, Object?> json) =>
      storage.saveStudy(participantId, json);

  @override
  Future<void> log(String participantId, Map<String, Object?> event) =>
      storage.appendEvent(participantId, event);

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    final spec = _specs[_variant]!;
    return AppScope(
      handle: this,
      variant: _variant,
      child: ServicesScope(
        services: _services,
        child: MaterialApp(
          key: ValueKey((_variant, _epoch)),
          title: 'Swarana',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navKey,
          theme: spec.theme,
          home: spec.home(study: ux.inStudy),
          routes: {
            ...spec.routes,
            '/researcher': (_) => const ResearcherPanel(),
            '/results': (_) => ResultsPage(storage: storage),
          },
          navigatorObservers: [_observer],
          builder: (context, child) => UxHarness(
            ux: ux,
            scenarioTitle: (id) => scenarios[id]?.title ?? id,
            scenarioInstruction: (id, form) => scenarios[id]?.forms[form]?.instruction ?? '',
            onOpenResults: () => _navKey.currentState?.pushNamed('/results'),
            child: child!,
          ),
        ),
      ),
    );
  }
}
