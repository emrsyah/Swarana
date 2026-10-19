import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/services/stt_service.dart';
import '../../../variant/researcher_trigger.dart';
import '../copy.dart';
import '../design/tokens.dart';

/// Screen header with a listening status the user can trust.
///
/// REVIEW: Figma showed a red dot + "Mendengarkan…" in every state (even
/// before recording). Here each state looks different, the level bars move
/// with real sound, and the Jeda button lives in the header instead of a
/// floating button over the messages.
class HeaderStatus extends StatelessWidget {
  const HeaderStatus({
    super.key,
    required this.title,
    required this.status,
    required this.level,
    this.onTogglePause,
    this.actions = const [],
    this.onMenu,
  });

  final String title;
  final SttStatus status;
  final ValueListenable<double> level;
  final VoidCallback? onTogglePause;
  final List<Widget> actions;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: V5Colors.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(V5Space.xl, V5Space.md, V5Space.lg, V5Space.md),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: V5Colors.border))),
          // Title + actions on top; status + Jeda on their own full-width row
          // so the status is never truncated on narrow phones (seen on device).
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: ResearcherTrigger(child: Text(title, style: t.titleLarge))),
              ...actions,
              if (onMenu != null) ...[
                const SizedBox(width: V5Space.sm),
                _RoundIconButton(icon: Icons.menu, tooltip: 'Menu', onTap: onMenu!),
              ],
            ]),
            const SizedBox(height: V5Space.xs),
            Row(children: [
              Expanded(child: _StatusRow(status: status, level: level)),
              if (onTogglePause != null && status != SttStatus.unavailable)
                _PauseButton(listening: status == SttStatus.listening, onTap: onTogglePause!),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status, required this.level});
  final SttStatus status;
  final ValueListenable<double> level;

  @override
  Widget build(BuildContext context) {
    final (Widget icon, String label, Color color) = switch (status) {
      SttStatus.listening => (const _PulseDot(), Copy.listening, V5Colors.ink),
      SttStatus.paused => (const Icon(Icons.pause_circle_filled, size: 18, color: V5Colors.muted), Copy.paused, V5Colors.muted),
      SttStatus.idle => (const Icon(Icons.mic_off, size: 18, color: V5Colors.muted), Copy.idle, V5Colors.muted),
      SttStatus.unavailable => (const Icon(Icons.mic_off, size: 18, color: V5Colors.error), Copy.micUnavailable, V5Colors.error),
      SttStatus.error => (const Icon(Icons.error, size: 18, color: V5Colors.error), 'Gangguan mikrofon', V5Colors.error),
    };
    return Semantics(
      liveRegion: true,
      label: label,
      child: Row(children: [
        icon,
        const SizedBox(width: V5Space.sm),
        if (status == SttStatus.listening) ...[
          _LevelBars(level: level),
          const SizedBox(width: V5Space.sm),
        ],
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
        ),
      ]),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: V5Colors.recording.withValues(alpha: reduce ? 0.2 : 0.15 + 0.2 * _c.value),
        ),
        child: Container(width: 9, height: 9, decoration: const BoxDecoration(shape: BoxShape.circle, color: V5Colors.recording)),
      ),
    );
  }
}

/// Five bars driven by the real input level.
class _LevelBars extends StatelessWidget {
  const _LevelBars({required this.level});
  final ValueListenable<double> level;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: level,
        builder: (_, v, _) => Row(children: [
          for (var i = 0; i < 5; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: 4 + 14 * (v * (1 - (i - 2).abs() * 0.25)).clamp(0.0, 1.0),
              decoration: BoxDecoration(color: V5Colors.primary, borderRadius: BorderRadius.circular(2)),
            ),
        ]),
      );
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.listening, required this.onTap});
  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: V5Colors.primary,
          backgroundColor: V5Colors.aiTint,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        icon: Icon(listening ? Icons.pause : Icons.mic, size: 20),
        label: Text(listening ? Copy.jeda : Copy.lanjutkan),
      );
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: Container(
            width: minTouch,
            height: minTouch,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: V5Colors.border)),
            child: Icon(icon, color: V5Colors.ink),
          ),
        ),
      );
}
