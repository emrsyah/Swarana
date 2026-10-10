import 'dart:async';

import 'package:flutter/material.dart';

import 'questionnaires.dart';
import 'ux_controller.dart';
import 'ux_models.dart';

/// Wraps the app during a study: briefing, a small task pill, the
/// researcher's outcome check, SEQ, SUS, NASA-TLX, rest and done screens.
///
/// It sits above the Navigator, so it brings its own Overlay + Material to
/// let sliders and text fields work.
class UxHarness extends StatefulWidget {
  const UxHarness({
    super.key,
    required this.ux,
    required this.child,
    required this.scenarioTitle,
    required this.scenarioInstruction,
    this.onOpenResults,
  });

  final UxController ux;
  final Widget child;
  final String Function(String scenarioId) scenarioTitle;
  final String Function(String scenarioId, String form) scenarioInstruction;
  final VoidCallback? onOpenResults;

  @override
  State<UxHarness> createState() => _UxHarnessState();
}

class _UxHarnessState extends State<UxHarness> {
  UxController get c => widget.ux;
  Timer? _ticker;
  bool _pillOpen = false;
  bool _confirmAbort = false;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
    _onChange();
  }

  void _onChange() {
    _ticker?.cancel();
    if (c.isRunning || c.phase == StudyPhase.rest) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Stack(children: [
      Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => c.onTap(e.position, size),
        child: widget.child,
      ),
      if (c.inStudy || c.phase == StudyPhase.done)
        Positioned.fill(
          child: Overlay(initialEntries: [
            OverlayEntry(builder: (_) => Material(type: MaterialType.transparency, child: _overlay())),
          ]),
        ),
    ]);
  }

  Widget _overlay() => switch (c.phase) {
        StudyPhase.briefing => _modal(_brief()),
        StudyPhase.running => _pill(),
        StudyPhase.outcome => _modal(_outcome()),
        StudyPhase.seq => _modal(SeqForm(onDone: c.submitSeq)),
        StudyPhase.sus => _modal(SusForm(
            key: ValueKey('sus-${c.blockIndex}'),
            variantLabel: c.variant!.label,
            onDone: c.submitSus)),
        StudyPhase.tlx => _modal(TlxForm(
            key: ValueKey('tlx-${c.blockIndex}'),
            variantLabel: c.variant!.label,
            onDone: c.submitTlx)),
        StudyPhase.rest => _modal(_rest()),
        StudyPhase.done => _modal(_done()),
        StudyPhase.idle => const SizedBox.shrink(),
      };

  Widget _modal(Widget card) => ColoredBox(
        color: Colors.black54,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(padding: const EdgeInsets.all(24), child: card),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _brief() {
    final t = Theme.of(context).textTheme;
    final id = c.scenarioId!;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${c.variant!.label} · Tugas ${c.taskNumber} dari ${c.scenarios.length}', style: t.labelLarge),
      const SizedBox(height: 8),
      Text(widget.scenarioTitle(id), style: t.headlineSmall),
      const SizedBox(height: 12),
      Text(widget.scenarioInstruction(id, c.form), style: t.bodyLarge?.copyWith(height: 1.5)),
      const SizedBox(height: 8),
      Text('Bentuk ${c.form} · ${c.config!.scripted ? 'lawan bicara otomatis' : 'lawan bicara manusia'}',
          style: t.bodySmall),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: c.startTask,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: const Text('Mulai'),
      ),
      const SizedBox(height: 4),
      Center(
        child: _confirmAbort
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                TextButton(onPressed: () => setState(() => _confirmAbort = false), child: const Text('Batal')),
                TextButton(
                  onPressed: () {
                    _confirmAbort = false;
                    c.abortStudy();
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                  child: const Text('Ya, hentikan'),
                ),
              ])
            : TextButton(
                onPressed: () => setState(() => _confirmAbort = true),
                child: const Text('Hentikan sesi uji'),
              ),
      ),
    ]);
  }

  /// Small pill at the bottom-left so it never covers v5's header status.
  Widget _pill() {
    final secs = c.elapsed.inSeconds;
    final clock = '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
    return Align(
      alignment: Alignment.bottomLeft,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 96),
          child: Material(
            elevation: 4,
            color: Colors.black87,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => setState(() => _pillOpen = !_pillOpen),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(clock, style: const TextStyle(color: Colors.white, fontFeatures: [FontFeature.tabularFigures()])),
                  if (_pillOpen) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => c.endTask(null),
                      child: const Text('Selesai', style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: () => c.endTask(TaskOutcome.gaveUp),
                      child: const Text('Menyerah', style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _outcome() {
    final t = Theme.of(context).textTheme;
    final p = c.pending!;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Untuk peneliti', style: t.labelLarge),
      const SizedBox(height: 8),
      Text('Apakah tugas berhasil?', style: t.titleLarge),
      const SizedBox(height: 4),
      Text(
        'Waktu aktif ${p.duration.inSeconds} detik'
        '${p.waited > Duration.zero ? ' (tunggu ${p.waited.inSeconds} detik tidak dihitung)' : ''}.'
        '${p.autoDetected ? ' Skrip mendeteksi semua giliran selesai.' : ''}',
        style: t.bodyMedium,
      ),
      const SizedBox(height: 20),
      for (final o in [TaskOutcome.success, TaskOutcome.partial, TaskOutcome.fail])
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: o == p.outcome
              ? FilledButton(
                  onPressed: () => c.confirmOutcome(o),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text(o.label))
              : OutlinedButton(
                  onPressed: () => c.confirmOutcome(o),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text(o.label)),
        ),
      if (p.outcome == TaskOutcome.gaveUp || p.outcome == TaskOutcome.timedOut)
        TextButton(onPressed: () => c.confirmOutcome(p.outcome), child: Text('Simpan sebagai "${p.outcome.label}"')),
    ]);
  }

  Widget _rest() {
    final t = Theme.of(context).textTheme;
    final left = c.restUntil!.difference(DateTime.now());
    final over = left <= Duration.zero;
    final m = left.inMinutes, s = left.inSeconds % 60;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Istirahat dulu', style: t.headlineSmall),
      const SizedBox(height: 8),
      Text('Selanjutnya kamu akan mencoba versi aplikasi yang lain.', style: t.bodyLarge, textAlign: TextAlign.center),
      const SizedBox(height: 20),
      Text(over ? '00:00' : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
          style: t.displaySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
      const SizedBox(height: 20),
      GestureDetector(
        // Researcher can skip the wait with a long press.
        onLongPress: c.finishRest,
        child: FilledButton(
          onPressed: over ? c.finishRest : null,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Lanjut ke versi berikutnya'),
        ),
      ),
    ]);
  }

  Widget _done() {
    final t = Theme.of(context).textTheme;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Terima kasih!', style: t.headlineSmall),
      const SizedBox(height: 8),
      Text('Semua tugas sudah selesai.', style: t.bodyLarge),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: () {
          c.closeDone();
          widget.onOpenResults?.call();
        },
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: const Text('Lihat hasil'),
      ),
      TextButton(onPressed: c.closeDone, child: const Text('Tutup')),
    ]);
  }
}
