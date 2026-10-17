import 'dart:async';

import 'package:flutter/material.dart';

import '../core/services/services.dart';
import '../core/services/stt_service.dart';
import '../iter4/iter4_session_page.dart' show TapTracker;
import '../ux_kit/ux_controller.dart';
import '../variant/variant.dart';
import '../variants/v5_chat/obrolan/obrolan_page.dart';
import '../variants/v5_chat/v5_routes.dart';
import '../variants/v5_chat/v5_spec.dart';
import 'iter6_eval_page.dart';
import 'iter6_script.dart';
import 'iter6_session.dart';

/// Runs the Iterasi 5 interface (v5 Obrolan and its screens) for the Uji 4
/// role-play, in its own navigator and with its own services, while tracking
/// taps, sends and screens. The evaluator long-presses the timer to finish.
class Iter6RunPage extends StatefulWidget {
  const Iter6RunPage({super.key, required this.session});
  final Iter6Session session;

  @override
  State<Iter6RunPage> createState() => _Iter6RunPageState();
}

class _Iter6RunPageState extends State<Iter6RunPage> {
  final _nav = GlobalKey<NavigatorState>();
  late final Services _services;
  late final UxController _ux;
  late final UxEventSink _oldSink;
  late final ThemeData _theme;
  late final _RouteObserver _observer;
  bool _init = false;

  Iter6Session get s => widget.session;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final app = AppHandle.read(context);
    // The main app's chat is still mounted underneath and may be listening:
    // pause it so it doesn't hold the (singleton) recognizer, resume after.
    _rootStt = Services.read(context).stt;
    _rootWasListening = _rootStt.status.value == SttStatus.listening;
    if (_rootWasListening) _rootStt.pause();
    _services = Services.create(
      storage: app.storage,
      settings: app.settings,
      form: s.simulated ? I6Card.byId(s.card).form : null,
      onSignal: (_) {}, // the evaluator ends the role-play, not the script
    );
    _ux = app.ux;
    _oldSink = _ux.sink;
    _ux.sink = s; // capture the v5 app's own events
    _theme = V5Spec().theme;
    _observer = _RouteObserver(s.onRoute);
    _sttSub = _services.stt.events.where((e) => e.isFinal).listen((e) => s.partnerLine(e.text));
    s.start();
  }

  late final SttService _rootStt;
  bool _rootWasListening = false;
  StreamSubscription<SttEvent>? _sttSub;

  @override
  void dispose() {
    _sttSub?.cancel();
    _ux.sink = _oldSink;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _services.dispose();
      if (_rootWasListening) _rootStt.start();
    });
    super.dispose();
  }

  Route<dynamic>? _route(RouteSettings rs) {
    // No researcher tools inside a participant's run (2 s title press).
    if (rs.name == '/researcher' || rs.name == '/results') return null;
    final b = V5Spec().routes[rs.name];
    return MaterialPageRoute(
      settings: rs,
      builder: b ??
          (rs.name == V5Routes.obrolan || rs.name == '/'
              ? (_) => const ObrolanPage()
              : (ctx) => Scaffold(
                    appBar: AppBar(),
                    body: const Center(child: Text('Tidak tersedia saat pengujian')),
                  )),
    );
  }

  Future<void> _finish() async {
    final at = DateTime.now(); // stop the clock at the long-press, not after the dialog
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Formulir selesai?'),
        content: const Text('Stopwatch berhenti dan lanjut ke penilaian evaluator.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Belum')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Selesai')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    s.end(at: at);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      settings: const RouteSettings(name: '/iter6/eval'),
      builder: (_) => Iter6EvalPage(session: s),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _nav.currentState?.maybePop();
      },
      child: Theme(
        data: _theme,
        child: ServicesScope(
          services: _services,
          child: Stack(children: [
            TapTracker(
              onTap: (p) => s.onTap(p, size),
              child: Navigator(
                key: _nav,
                // Exactly one starting screen (initialRoute would also push '/'
                // and '/v5', mounting a second chat).
                onGenerateInitialRoutes: (_, _) => [_route(const RouteSettings(name: V5Routes.obrolan))!],
                onGenerateRoute: _route,
                observers: [_observer],
              ),
            ),
            // Evaluator pill: long-press to finish (participant can't end it by accident).
            Positioned(
              left: 8,
              bottom: MediaQuery.paddingOf(context).bottom + 96,
              child: GestureDetector(
                onLongPress: _finish,
                child: Material(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    // No visible clock (avoids time pressure); the time is on the
                    // evaluator's page. A dot shows the recording is running.
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(s.card, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RouteObserver extends NavigatorObserver {
  _RouteObserver(this.onRoute);
  final void Function(String) onRoute;

  void _r(Route<dynamic>? r) {
    final n = r?.settings.name;
    if (n != null) onRoute(n);
  }

  @override
  void didPush(Route route, Route? previousRoute) => _r(route);
  @override
  void didPop(Route route, Route? previousRoute) => _r(previousRoute);
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) => _r(newRoute);
}
