import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/models/session.dart';
import '../../../core/services/alerts.dart';
import '../../../core/services/services.dart';
import '../../../core/services/stt_service.dart';
import '../../../variant/variant.dart';
import '../copy.dart';
import '../design/tokens.dart';
import '../drawer.dart';
import '../v5_routes.dart';
import '../widgets/alert_banner.dart';
import '../widgets/dialogs.dart';
import '../widgets/header_status.dart';
import '../widgets/text_size_slider.dart';

/// One-way live captions for media, meetings, announcements.
class TranskripPage extends StatefulWidget {
  const TranskripPage({super.key});

  @override
  State<TranskripPage> createState() => _TranskripPageState();
}

class _Para {
  _Para(this.at, this.text);
  final Duration at;
  String text;
}

class _TranskripPageState extends State<TranskripPage> {
  late Services _s;
  final _scaffold = GlobalKey<ScaffoldState>();
  final _scroll = ScrollController();
  final List<_Para> _paras = [];
  String _partial = '';
  DateTime? _startedAt;
  StreamSubscription<SttEvent>? _sub;
  StreamSubscription<AlertKind>? _alertSub;
  AlertKind? _alert;
  bool _quietHint = false;
  Timer? _quietTimer;
  bool _following = true;

  bool get _running => _startedAt != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Runs again on theme/MediaQuery changes: register listeners only once.
    if (_sub != null) return;
    _s = Services.of(context);
    _s.stt.status.addListener(_rebuild);
    _sub = _s.stt.events.listen(_onStt);
    _alertSub = _s.alerts.stream.listen((k) => setState(() => _alert = k));
    _scroll.addListener(() {
      final f = !_scroll.hasClients || _scroll.offset >= _scroll.position.maxScrollExtent - 40;
      if (f != _following) setState(() => _following = f);
    });
  }

  void _rebuild() => setState(() {});

  void _onStt(SttEvent e) {
    if (!_running) return;
    _quietTimer?.cancel();
    _quietHint = false;
    if (e.isFinal) {
      final at = DateTime.now().difference(_startedAt!);
      // New paragraph (with a time mark) every 30 seconds.
      if (_paras.isEmpty || at - _paras.last.at > const Duration(seconds: 30)) {
        _paras.add(_Para(at, e.text));
      } else {
        _paras.last.text = '${_paras.last.text} ${e.text}';
      }
      _partial = '';
    } else {
      _partial = e.text;
    }
    _armQuietHint();
    setState(() {});
    if (_following) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  void _armQuietHint() {
    _quietTimer?.cancel();
    _quietTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _running) setState(() => _quietHint = true);
    });
  }

  Future<void> _start() async {
    final ux = AppHandle.of(context).ux;
    if (!await _s.stt.init()) {
      _s.alerts.raise(AlertKind.micDenied);
      return;
    }
    setState(() {
      _startedAt = DateTime.now();
      _paras.clear();
      _partial = '';
    });
    _armQuietHint();
    await _s.stt.start();
    ux.track('transcript_started');
  }

  Future<void> _stop() async {
    await _s.stt.stop();
    _quietTimer?.cancel();
    final started = _startedAt!;
    final duration = DateTime.now().difference(started);
    final text = [..._paras.map((p) => p.text), if (_partial.isNotEmpty) _partial].join('\n\n');
    setState(() {
      _startedAt = null;
      _quietHint = false;
    });
    if (text.trim().isEmpty || !mounted) return;
    final r = await showSaveDialog(
      context,
      heading: 'Simpan transkrip?',
      suggestedTitle: _s.llm.titleFor(text).catchError((_) => 'Transkrip ${started.day}/${started.month}'),
    );
    if (r == null || r.$1 == SaveChoice.discard || !mounted) return;
    final t = TranscriptSession(
      id: started.microsecondsSinceEpoch.toString(),
      title: r.$2.trim().isEmpty ? 'Transkrip' : r.$2.trim(),
      createdAt: started,
      duration: duration,
      text: text,
    );
    await _s.storage.saveTranscript(t);
    if (mounted) Navigator.of(context).pushNamed(V5Routes.transkripDetail, arguments: t);
  }

  @override
  void dispose() {
    _s.stt.status.removeListener(_rebuild);
    _sub?.cancel();
    _alertSub?.cancel();
    _quietTimer?.cancel();
    _s.stt.stop();
    _scroll.dispose();
    super.dispose();
  }

  String _mark(Duration d) => '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final settings = _s.settings;
    return Scaffold(
      key: _scaffold,
      endDrawer: const V5Drawer(current: V5Routes.transkrip),
      body: Column(children: [
        HeaderStatus(
          title: Copy.transkrip,
          status: _s.stt.status.value,
          level: _s.stt.level,
          onMenu: () => _scaffold.currentState!.openEndDrawer(),
        ),
        if (_alert != null)
          AlertBanner(
            kind: _alert!,
            onClose: () => setState(() => _alert = null),
            onAction: _alert == AlertKind.micDenied ? openAppSettings : null,
          ),
        if (_quietHint) _QuietHint(onClose: () => setState(() => _quietHint = false)),
        Expanded(
          child: Stack(children: [
            if (!_running && _paras.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(V5Space.xl),
                  child: Text(
                    'Ubah suara dari video, berita, atau rapat menjadi tulisan. Dekatkan ponsel ke sumber suara.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: V5Colors.muted, fontSize: 16, height: 1.4),
                  ),
                ),
              )
            else
              ValueListenableBuilder<double>(
                valueListenable: settings.textScale,
                builder: (_, scale, _) => ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(V5Space.xl),
                  children: [
                    for (final p in _paras) ...[
                      Text(_mark(p.at), style: const TextStyle(fontSize: 13, color: V5Colors.muted)),
                      const SizedBox(height: 4),
                      Text(p.text, style: TextStyle(fontSize: 24 * scale, height: 1.4, fontWeight: FontWeight.w500)),
                      const SizedBox(height: V5Space.lg),
                    ],
                    if (_partial.isNotEmpty)
                      Text(_partial, style: TextStyle(fontSize: 24 * scale, height: 1.4, color: V5Colors.muted)),
                  ],
                ),
              ),
            if (_running && !_following)
              Positioned(
                bottom: V5Space.md,
                left: 0,
                right: 0,
                child: Center(
                  child: FilledButton.icon(
                    onPressed: () => _scroll.animateTo(_scroll.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                    icon: const Icon(Icons.arrow_downward),
                    label: const Text('Ke teks terbaru'),
                  ),
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: V5Space.xl),
          child: TextSizeSlider(value: settings.textScale),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: V5Space.lg, top: V5Space.sm),
            child: _RecordButton(running: _running, onTap: _running ? _stop : _start),
          ),
        ),
      ]),
    );
  }
}

/// Gentle hint when nothing has been heard for a while (Figma's
/// "Pastikan mikrofon mendekati sumber suara", shown only when relevant).
class _QuietHint extends StatelessWidget {
  const _QuietHint({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(V5Space.lg, V5Space.md, V5Space.lg, 0),
        padding: const EdgeInsets.fromLTRB(V5Space.md, V5Space.sm, V5Space.xs, V5Space.sm),
        decoration: BoxDecoration(
          color: V5Colors.warningBg,
          border: Border.all(color: V5Colors.warningBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: V5Colors.warningIcon),
          const SizedBox(width: V5Space.sm),
          const Expanded(child: Text('Belum ada suara terdengar. Dekatkan mikrofon ponsel ke sumber suara.')),
          IconButton(onPressed: onClose, tooltip: 'Tutup', icon: const Icon(Icons.close, color: V5Colors.muted)),
        ]),
      );
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.running, required this.onTap});
  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Semantics(
          button: true,
          label: running ? 'Hentikan transkrip' : 'Mulai transkrip',
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: V5Colors.border, width: 2)),
              alignment: Alignment.center,
              // REVIEW: idle shows a mic (Figma used a red dot for both states).
              child: running
                  ? Container(width: 32, height: 32, decoration: BoxDecoration(color: V5Colors.error, borderRadius: BorderRadius.circular(8)))
                  : Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(color: V5Colors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.mic, color: Colors.white, size: 34),
                    ),
            ),
          ),
        ),
        const SizedBox(height: V5Space.sm),
        Text(running ? 'Hentikan transkrip' : 'Tekan untuk mulai transkrip',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ]);
}
