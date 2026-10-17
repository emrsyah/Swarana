import 'dart:async';

import 'package:flutter/material.dart';

import '../core/services/services.dart';
import '../core/services/stt_service.dart';
import '../iter4/iter4_session_page.dart' show TapTracker;
import '../ux_kit/ux_controller.dart';
import '../variant/variant.dart';
import '../variants/v5_chat/obrolan/obrolan_page.dart';
import '../variants/v5_chat/transkrip/transkrip_page.dart';
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
    _sttSub = _services.stt.events.where((e) => e.isFinal).listen((e) {
      s.partnerLine(e.text);
      // Simulation: the question appears as soon as the news has played.
      // After a reading pause, not instantly.
      if (_newsPhase && s.simulated && e.text == newsText) _startCountdown();
    });
    _services.stt.status.addListener(_onSttStatus);
    s.start();
  }

  // Interaction 1 runs in Transkrip; the teller part (2–5) in Obrolan.
  bool _newsPhase = true;
  bool _askingNews = false;
  bool _pendingRepeat = false;
  final _clearNews = ValueNotifier(0);

  // Reading pause after the news before the question opens.
  static const _readSeconds = 10;
  int? _countdown;
  Timer? _countdownTimer;

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = _readSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_countdown! <= 1) {
        _stopCountdown();
        _askNews();
      } else {
        setState(() => _countdown = _countdown! - 1);
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    if (mounted && _countdown != null) setState(() => _countdown = null);
  }

  /// A repeat asked while the transcript was stopped plays once it records again.
  void _onSttStatus() {
    if (_pendingRepeat && _services.stt.status.value == SttStatus.listening) {
      _pendingRepeat = false;
      _services.scripted?.repeatLast();
    }
  }

  Future<void> _askNews() async {
    if (!_newsPhase || _askingNews || !mounted) return;
    _stopCountdown();
    _askingNews = true;
    final ctl = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Pertanyaan'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Di mana alamat kantor cabang baru Bank Nusantara Jaya?', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Tulis jawabanmu', border: OutlineInputBorder()),
            ),
          ]),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(ctx, '__ulangi'),
              icon: const Icon(Icons.replay),
              label: const Text('Ulangi rekaman'),
            ),
            FilledButton(
              onPressed: () {
                if (ctl.text.trim().isNotEmpty) Navigator.pop(ctx, ctl.text);
              },
              child: const Text('Kirim jawaban'),
            ),
          ],
        ),
      ),
    );
    _askingNews = false;
    if (r == null || !mounted) return;
    if (r == '__ulangi') {
      s.repeatNews();
      _clearNews.value++; // the replay starts on a clean page
      if (!s.simulated) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Minta evaluator memutar ulang rekaman.')));
      } else if (_services.stt.status.value == SttStatus.listening) {
        _services.scripted?.repeatLast();
      } else {
        _pendingRepeat = true;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tekan tombol mikrofon untuk mendengarkan lagi.')));
      }
      return;
    }
    s.answerNews(r);
    _newsPhase = false;
    _pendingRepeat = false;
    await _services.stt.stop();
    _services.scripted?.userReplied(); // teller lines follow once Obrolan listens
    _nav.currentState?.pushNamedAndRemoveUntil(V5Routes.obrolan, (_) => false);
    // Make sure Obrolan is listening after the transition settles.
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted && _services.stt.status.value != SttStatus.listening) _services.stt.start();
    });
  }

  late final SttService _rootStt;
  bool _rootWasListening = false;
  StreamSubscription<SttEvent>? _sttSub;

  @override
  void dispose() {
    _sttSub?.cancel();
    _countdownTimer?.cancel();
    _clearNews.dispose();
    _services.stt.status.removeListener(_onSttStatus);
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
    if (rs.name == V5Routes.transkrip && _newsPhase) {
      return MaterialPageRoute(
          settings: rs, builder: (_) => TranskripPage(onStopped: (_) => _askNews(), clearSignal: _clearNews));
    }
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
                // Starts in Transkrip for the news (interaction 1).
                onGenerateInitialRoutes: (_, _) => [_route(const RouteSettings(name: V5Routes.transkrip))!],
                onGenerateRoute: _route,
                observers: [_observer],
              ),
            ),
            // Reading pause after the news: shows when the question will open.
            if (_countdown != null)
              Positioned(
                left: 16,
                right: 16,
                top: MediaQuery.paddingOf(context).top + 76,
                child: Material(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(14),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                    child: Row(children: [
                      Expanded(
                        child: Text('Baca dulu. Pertanyaan muncul dalam $_countdown detik',
                            style: const TextStyle(color: Colors.white, fontSize: 15)),
                      ),
                      TextButton(
                        onPressed: _askNews,
                        child: const Text('Jawab sekarang', style: TextStyle(color: Colors.white)),
                      ),
                    ]),
                  ),
                ),
              ),
            // Evaluator handle: a small red dot inside the status bar, so it
            // covers none of the app. Long-press it to finish (participant
            // can't end it by accident). No clock, to avoid time pressure.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              // Left of centre: the middle is the camera cut-out on most phones.
              child: Align(
                alignment: const Alignment(-0.3, 0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: _finish,
                  child: SizedBox(
                    width: 56,
                    height: MediaQuery.paddingOf(context).top.clamp(24, 48).toDouble(),
                    child: Align(
                      alignment: const Alignment(0, 0.2),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      ),
                    ),
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
