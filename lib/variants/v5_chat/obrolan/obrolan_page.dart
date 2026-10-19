import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/models/message.dart';
import '../../../core/models/session.dart';
import '../../../core/services/alerts.dart';
import '../../../core/services/services.dart';
import '../../../core/services/stt_service.dart';
import '../../../ux_kit/ux_controller.dart';
import '../../../variant/variant.dart';
import '../copy.dart';
import '../design/tokens.dart';
import '../drawer.dart';
import '../v5_routes.dart';
import '../widgets/alert_banner.dart';
import '../widgets/bubble.dart';
import '../widgets/composer.dart';
import '../widgets/dialogs.dart';
import '../widgets/header_status.dart';
import '../widgets/message_menu.dart';
import '../widgets/suggestions.dart';
import 'board_sheet.dart';
import 'face_mode.dart';
import 'obrolan_controller.dart';

/// Ruang Cakap: one chat screen for listening and replying, 1:1 or group.
class ObrolanPage extends StatefulWidget {
  const ObrolanPage({super.key, this.resume});

  /// Continue a saved conversation ("Lanjutkan obrolan").
  final ChatSession? resume;

  @override
  State<ObrolanPage> createState() => _ObrolanPageState();
}

class _ObrolanPageState extends State<ObrolanPage> {
  ObrolanController? _c;
  final _composer = ComposerController();
  final _scroll = ScrollController();
  final _scaffold = GlobalKey<ScaffoldState>();
  bool _awayFromBottom = false;
  bool _newBelow = false;
  bool _offerTypingNotice = false;
  int _lastCount = 0;

  /// Captured here: looking it up from a listener (which can fire while the
  /// page is being torn down) registers an inherited dependency on a
  /// deactivating element and trips '_dependents.isEmpty' (seen on device).
  FlutterView? _view;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = View.of(context);
    if (_c != null) return;
    final app = AppHandle.of(context);
    final c = ObrolanController(Services.of(context), app.ux, resume: widget.resume);
    final sid = app.ux.inStudy ? app.ux.scenarioId : null;
    if (sid != null) c.seedSpeakerNames(app.scenarios[sid]!.speakers);
    c.addListener(_onChange);
    _c = c;
    _lastCount = c.messages.length;
    _ux = app.ux..addListener(_onStudyPhase);
    // In a study, listen only while the task runs (not during briefing or
    // questionnaires), so partner lines never play before "Mulai".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!app.ux.inStudy || app.ux.isRunning) c.startListening();
    });
    _scroll.addListener(() {
      final away = _scroll.hasClients && _scroll.offset > 120;
      if (away != _awayFromBottom) {
        setState(() {
          _awayFromBottom = away;
          if (!away) _newBelow = false;
        });
      }
    });
  }

  UxController? _ux;
  bool _wasRunning = false;

  void _onStudyPhase() {
    final ux = _ux!, c = _c!;
    if (!ux.inStudy) return;
    if (ux.isRunning && !_wasRunning) {
      c.startListening();
    } else if (!ux.isRunning && _wasRunning && c.sttStatus == SttStatus.listening) {
      c.s.stt.pause();
    }
    _wasRunning = ux.isRunning;
  }

  String? _announced;

  void _onChange() {
    final c = _c!;
    if (c.messages.length > _lastCount && _awayFromBottom) _newBelow = true;
    _lastCount = c.messages.length;
    // Screen readers: announce each finished partner message once.
    final last = c.messages.where((m) => !m.isMe && !m.partial).lastOrNull;
    final view = _view;
    if (last != null && last.id != _announced && view != null) {
      _announced = last.id;
      SemanticsService.sendAnnouncement(view, '${c.speaker(last.speakerId).name}: ${last.text}', TextDirection.ltr);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ux?.removeListener(_onStudyPhase);
    _c?.removeListener(_onChange);
    _c?.dispose();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------------- Actions ----------------

  void _send(String text, Composition comp, {MessageSource? source}) {
    _offerTypingNotice = false;
    _c!.send(text, comp, source: source);
    _jumpToBottom();
  }

  void _jumpToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _openBoard() {
    final study = _c!.studyMode;
    BoardSheet.show(
      context,
      onWord: (w) {
        _composer.insert(w, MessageSource.board);
        setState(() {});
      },
      onSentence: (s) => _send(s, Composition(board: s.length)),
      onQuickPhrase: study ? null : (p) => _send(p, Composition(), source: MessageSource.quickPhrase),
    );
  }

  // "Minta ulangi" is a quick phrase: hidden in study mode (v3 has none).
  Future<void> _onMenu(ChatMessage m) =>
      showMessageMenu(context, message: m, allowAskRepeat: !_c!.studyMode, onAction: (a) async {
        final c = _c!;
        switch (a) {
          case MessageAction.speak:
            c.speak(m);
          case MessageAction.simplify:
            final r = await c.simplify(m);
            if (r == null && mounted) _snack('Gagal menyederhanakan. Periksa internet.');
          case MessageAction.explain:
            if (!mounted) return;
            showExplainSheet(context, text: m.text, explain: (w) => c.explain(w, m.text));
          case MessageAction.correct:
            _correct(m);
          case MessageAction.askRepeat:
            _send('Maaf, bisa diulangi?', Composition(), source: MessageSource.quickPhrase);
          case MessageAction.copy:
            break;
        }
      });

  Future<void> _correct(ChatMessage m) async {
    final t = await showTextDialog(context, title: 'Perbaiki tulisan', initial: m.text, label: 'Tulisan yang benar', maxLines: 4);
    if (t != null && t.trim().isNotEmpty) _c!.correct(m, t.trim());
  }

  Future<void> _rename(Speaker sp) async {
    final n = await showTextDialog(context, title: 'Ganti nama pembicara', initial: sp.name);
    if (n != null) _c!.renameSpeaker(sp.id, n);
  }

  Future<void> _endChat() async {
    final c = _c!;
    if (c.isEmpty) return;
    final wasListening = c.sttStatus == SttStatus.listening;
    await c.s.stt.pause();
    if (!mounted) return;
    final suggested = c.suggestTitle();
    final r = await showSaveDialog(context, heading: 'Akhiri dan simpan obrolan?', suggestedTitle: suggested);
    if (!mounted) return;
    if (r == null) {
      // Batal: only resume if it was listening before (never a false "listening").
      if (wasListening) await c.s.stt.start();
      return;
    }
    if (r.$1 == SaveChoice.save) {
      await c.save(r.$2.trim().isEmpty ? await suggested : r.$2);
      if (mounted) _snack('Obrolan disimpan di Riwayat');
    }
    if (mounted) Navigator.of(context).pushReplacementNamed(V5Routes.obrolan);
  }

  void _faceMode() {
    final c = _c!;
    final mine = c.messages.where((m) => m.isMe).lastOrNull?.text;
    final theirs = c.messages.where((m) => !m.isMe && !m.partial).lastOrNull?.text;
    c.ux.track('face_mode_opened');
    Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: V5Routes.faceMode),
      builder: (_) => FaceModePage(forPartner: mine ?? FaceModePage.introCard, partnerLast: theirs),
    ));
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    final c = _c!;
    final settings = c.s.settings;
    final study = c.studyMode;
    final manualSpeaker = c.s.scripted == null && settings.separateSpeakers.value && c.sttStatus == SttStatus.listening;
    final msgs = c.messages.reversed.toList();

    return Scaffold(
      key: _scaffold,
      endDrawer: V5Drawer(current: V5Routes.obrolan, onEndChat: c.isEmpty ? null : _endChat),
      body: EdgeFlash(
        trigger: c.alert,
        child: Column(children: [
          HeaderStatus(
            title: Copy.obrolan,
            status: c.sttStatus,
            level: c.level,
            onTogglePause: c.togglePause,
            onMenu: () => _scaffold.currentState!.openEndDrawer(),
            actions: [
              if (manualSpeaker)
                IconButton(
                  tooltip: '${Copy.orangLainBicara} (pembicara baru)',
                  onPressed: c.otherPersonSpeaking,
                  icon: const Icon(Icons.group_add_outlined, color: V5Colors.primary),
                ),
              if (!study)
                IconButton(
                  tooltip: 'Tunjukkan ke lawan bicara',
                  onPressed: _faceMode,
                  icon: const Icon(Icons.screen_rotation_alt, color: V5Colors.primary),
                ),
            ],
          ),
          if (c.alert != null)
            AlertBanner(
              kind: c.alert!,
              onClose: c.dismissAlert,
              onAction: switch (c.alert!) {
                AlertKind.speechWhilePaused => () {
                    c.dismissAlert();
                    c.togglePause();
                  },
                AlertKind.micDenied => openAppSettings,
                _ => null,
              },
            ),
          Expanded(
            child: Stack(children: [
              if (c.isEmpty)
                _EmptyState(onIntro: study ? null : _faceMode)
              else
                ValueListenableBuilder<double>(
                  valueListenable: settings.textScale,
                  builder: (_, scale, _) => ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: V5Space.lg),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = msgs[i];
                      final sp = c.speaker(m.speakerId);
                      return MessageBubble(
                        key: ValueKey(m.id),
                        message: m,
                        speaker: sp,
                        showName: c.isGroup && !m.isMe,
                        textScale: scale,
                        onMenu: () => _onMenu(m),
                        onSpeak: () => c.speak(m),
                        onRename: () => _rename(sp),
                        onSimplify: () => c.simplify(m),
                        onCorrect: () => _correct(m),
                      );
                    },
                  ),
                ),
              if (_newBelow)
                Positioned(
                  bottom: V5Space.md,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FilledButton.icon(
                      onPressed: _jumpToBottom,
                      icon: const Icon(Icons.arrow_downward),
                      label: const Text('Pesan baru'),
                    ),
                  ),
                ),
            ]),
          ),
          SuggestionsPanel(
            state: c.suggestState,
            items: c.suggestions,
            onSend: (s) => _send(s, Composition(suggestion: s.length)),
            onEdit: (s) {
              _composer.insert(s, MessageSource.suggestion);
              setState(() {});
            },
            onClose: c.hideSuggestions,
            onRetry: c.retrySuggestions,
          ),
          if (_offerTypingNotice && !study)
            Padding(
              padding: const EdgeInsets.fromLTRB(V5Space.lg, V5Space.sm, V5Space.lg, 0),
              // Full-width button so the phrase wraps (a chip clipped it on device).
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(minTouch),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.centerLeft,
                ),
                icon: const Icon(Icons.volume_up, size: 18),
                label: const Text('Beri tahu: "Mohon tunggu, saya sedang mengetik"', softWrap: true),
                onPressed: () {
                  setState(() => _offerTypingNotice = false);
                  final m = ChatMessage(
                    id: 'notice${DateTime.now().millisecondsSinceEpoch}',
                    speakerId: Speaker.meId,
                    text: 'Mohon tunggu, saya sedang mengetik.',
                    time: DateTime.now(),
                  );
                  c.s.tts.speak(m.id, m.text);
                  c.ux.track('typing_notice_spoken');
                },
              ),
            ),
          Composer(
            controller: _composer,
            onSend: (t, comp) => _send(t, comp),
            onOpenBoard: _openBoard,
            onChanged: c.onDraftChanged,
            onTypingLong: study ? null : () => setState(() => _offerTypingNotice = true),
          ),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onIntro});
  final VoidCallback? onIntro;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(V5Space.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.forum_outlined, size: 48, color: V5Colors.primary),
          const SizedBox(height: V5Space.md),
          Text('Mulai obrolan', style: t.titleLarge),
          const SizedBox(height: V5Space.sm),
          Text(
            'Swarana mendengarkan dan menuliskan ucapan lawan bicara di sini. '
            'Ketik balasanmu di bawah, Swarana akan membunyikannya.',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: V5Colors.muted),
          ),
          if (onIntro != null) ...[
            const SizedBox(height: V5Space.xl),
            OutlinedButton.icon(
              onPressed: onIntro,
              icon: const Icon(Icons.badge_outlined),
              label: const Text('Tunjukkan kartu perkenalan'),
            ),
          ],
        ]),
      ),
    );
  }
}
