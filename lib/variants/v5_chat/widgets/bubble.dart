import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/message.dart';
import '../copy.dart';
import '../design/tokens.dart';

/// One chat message. Partner bubbles carry the speaker's colour and name;
/// the user's bubbles show whether text-to-speech actually played.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.speaker,
    required this.showName,
    required this.textScale,
    this.onMenu,
    this.onSpeak,
    this.onRename,
    this.onSimplify,
    this.onCorrect,
  });

  final ChatMessage message;
  final Speaker speaker;
  final bool showName;
  final double textScale;
  final VoidCallback? onMenu;
  final VoidCallback? onSpeak;
  final VoidCallback? onRename;
  final VoidCallback? onSimplify;
  final VoidCallback? onCorrect;

  /// Long partner messages get a visible simplify button (not only long-press).
  bool get _isLong => message.text.split(' ').length > 25;

  @override
  Widget build(BuildContext context) {
    final me = message.isMe;
    final color = speakerColor(speaker.colorIndex);
    final body = TextStyle(fontSize: 17 * textScale, height: 1.45, color: V5Colors.ink);

    final radius = BorderRadius.circular(V5Radius.bubble);
    final speaking = me && message.tts == TtsState.speaking;
    final content = Padding(
        padding: const EdgeInsets.fromLTRB(V5Space.lg, V5Space.md, V5Space.lg, V5Space.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            message.text,
            style: message.partial ? body.copyWith(color: V5Colors.muted, fontStyle: FontStyle.italic) : body,
          ),
          if (message.partial) ...[
            const SizedBox(height: 6),
            Text('${speaker.name} sedang bicara…', style: const TextStyle(fontSize: 13, color: V5Colors.muted)),
          ],
          if (message.simplified != null) _Simplified(text: message.simplified!, scale: textScale),
          if (message.lowConfidence && !me)
            _InlineAction(icon: Icons.edit_outlined, label: 'Mungkin kurang tepat. Ketuk untuk perbaiki', onTap: onCorrect),
          if (!me && !message.partial && _isLong && message.simplified == null && onSimplify != null)
            _InlineAction(icon: Icons.auto_awesome, label: Copy.sederhanakan, onTap: onSimplify),
          if (me) _TtsStatus(state: message.tts, onSpeak: onSpeak),
        ]),
    );

    final bubble = Semantics(
      onLongPressHint: 'Pilihan pesan',
      onLongPress: message.partial ? null : onMenu,
      child: GestureDetector(
        onLongPress: message.partial ? null : onMenu,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.66),
          decoration: BoxDecoration(
            color: !me
                ? V5Colors.partnerBubble
                : speaking
                    ? V5Colors.myBubbleSpeaking
                    : V5Colors.myBubble,
            borderRadius: radius,
            border: Border.all(
              color: !me
                  ? V5Colors.border
                  : speaking
                      ? V5Colors.primary
                      : V5Colors.myBubble,
            ),
            boxShadow: me
                ? null
                : const [BoxShadow(color: Color(0x0A1F2A44), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: content,
        ),
      ),
    );

    final time = Text(DateFormat.Hm('id_ID').format(message.time),
        style: const TextStyle(fontSize: 12, color: V5Colors.muted));

    if (me) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: V5Space.lg, vertical: V5Space.xs),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [bubble, const SizedBox(height: 2), time]),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: V5Space.lg, vertical: V5Space.xs),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Avatar(name: speaker.name, color: color),
        const SizedBox(width: V5Space.sm),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (showName)
              InkWell(
                onTap: onRename,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: minTouch),
                  // Figma: name and pencil in the speaker's colour.
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(speaker.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
                    const SizedBox(width: 6),
                    Icon(Icons.edit_square, size: 16, color: color),
                  ]),
                ),
              ),
            bubble,
            const SizedBox(height: 2),
            time,
          ]),
        ),
      ]),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.color});
  final String name;
  final Color color;

  /// Figma: person glyph on a soft gradient of the speaker colour, white ring.
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(color, Colors.white, 0.35)!, color],
            ),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: const Icon(Icons.person_rounded, size: 18, color: Colors.white),
        ),
      );
}

class _Simplified extends StatelessWidget {
  const _Simplified({required this.text, required this.scale});
  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: V5Space.sm),
        padding: const EdgeInsets.all(V5Space.md),
        decoration: BoxDecoration(color: V5Colors.aiTint, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.auto_awesome, size: 14, color: V5Colors.primary),
            SizedBox(width: 4),
            Text('Versi sederhana', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: V5Colors.primary)),
          ]),
          const SizedBox(height: 4),
          Text(text, style: TextStyle(fontSize: 16 * scale, height: 1.45, color: V5Colors.ink)),
        ]),
      );
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: V5Space.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minTouch),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: V5Colors.primary),
              const SizedBox(width: 6),
              Flexible(child: Text(label, style: const TextStyle(fontSize: 14, color: V5Colors.primary, fontWeight: FontWeight.w500))),
            ]),
          ),
        ),
      );
}

/// REVIEW: Figma showed "Bunyikan Lagi" identically before, during and after
/// playback. A Deaf user needs to see what the phone did.
class _TtsStatus extends StatelessWidget {
  const _TtsStatus({required this.state, this.onSpeak});
  final TtsState state;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final Widget status = switch (state) {
      // Figma: outlined pill "🔊 Sedang disuarakan ••••".
      TtsState.speaking => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(V5Radius.pill),
            border: Border.all(color: V5Colors.pillBorder),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.volume_up_rounded, size: 16, color: V5Colors.primary),
            SizedBox(width: 6),
            Text(Copy.sedangDibunyikan, style: TextStyle(fontSize: 13, color: V5Colors.primary, fontWeight: FontWeight.w500)),
            SizedBox(width: 6),
            _Wave(),
          ]),
        ),
      TtsState.done => const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle, size: 16, color: V5Colors.success),
          SizedBox(width: 4),
          Text(Copy.sudahDibunyikan, style: TextStyle(fontSize: 13, color: V5Colors.success)),
        ]),
      TtsState.failed || TtsState.muted => Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.volume_off, size: 16, color: V5Colors.error),
          const SizedBox(width: 4),
          Text(state == TtsState.muted ? Copy.volumeNol : Copy.gagalDibunyikan,
              style: const TextStyle(fontSize: 13, color: V5Colors.error)),
        ]),
      TtsState.idle => const SizedBox.shrink(),
    };
    // Figma stacks status above the "Suarakan lagi" pill.
    return Padding(
      padding: const EdgeInsets.only(top: V5Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(liveRegion: true, child: status),
          if (state != TtsState.speaking && onSpeak != null)
            Padding(
              padding: EdgeInsets.only(top: state == TtsState.idle ? 0 : V5Space.xs),
              child: OutlinedButton.icon(
                onPressed: onSpeak,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  backgroundColor: V5Colors.aiTint,
                  side: const BorderSide(color: V5Colors.pillBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                icon: const Icon(Icons.volume_up_rounded, size: 16),
                label: const Text(Copy.bunyikanLagi),
              ),
            ),
        ],
      ),
    );
  }
}

class _Wave extends StatefulWidget {
  const _Wave();
  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Static bars when the system asks for reduced motion.
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        // Figma: a row of small dots that ripple while speaking.
        builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 9; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 3.5,
              height: 3.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: V5Colors.primary.withValues(
                    alpha: 0.35 + 0.65 * (0.5 + 0.5 * math.sin((_c.value - i * 0.1) * 2 * math.pi))),
              ),
            ),
        ]),
      );
}
