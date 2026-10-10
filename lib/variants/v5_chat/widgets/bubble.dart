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

    final bubble = GestureDetector(
      onLongPress: message.partial ? null : onMenu,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        padding: const EdgeInsets.fromLTRB(V5Space.lg, V5Space.md, V5Space.lg, V5Space.md),
        decoration: BoxDecoration(
          color: me ? V5Colors.myBubble : V5Colors.partnerBubble,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(me ? V5Radius.bubble : 4),
            topRight: Radius.circular(me ? 4 : V5Radius.bubble),
            bottomLeft: const Radius.circular(V5Radius.bubble),
            bottomRight: const Radius.circular(V5Radius.bubble),
          ),
          border: Border(
            left: BorderSide(color: me ? V5Colors.myBubble : color, width: me ? 1 : 4),
            top: BorderSide(color: me ? V5Colors.myBubble : V5Colors.border),
            right: BorderSide(color: me ? V5Colors.myBubble : V5Colors.border),
            bottom: BorderSide(color: me ? V5Colors.myBubble : V5Colors.border),
          ),
        ),
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
                  constraints: const BoxConstraints(minHeight: 36),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(speaker.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
                    const SizedBox(width: 4),
                    Icon(Icons.edit_outlined, size: 14, color: color.withValues(alpha: 0.7)),
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

  @override
  Widget build(BuildContext context) {
    // Initial from the name, or the number for "Pembicara 2".
    final parts = name.trim().split(' ');
    final initial = RegExp(r'^\d+$').hasMatch(parts.last) ? parts.last : name.trim().characters.first.toUpperCase();
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: 18,
        backgroundColor: color,
        child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
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
            constraints: const BoxConstraints(minHeight: 36),
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
      TtsState.speaking => const Row(mainAxisSize: MainAxisSize.min, children: [
          _Wave(),
          SizedBox(width: 6),
          Text(Copy.sedangDibunyikan, style: TextStyle(fontSize: 13, color: V5Colors.primary, fontWeight: FontWeight.w500)),
        ]),
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
    return Padding(
      padding: const EdgeInsets.only(top: V5Space.sm),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: V5Space.sm,
        runSpacing: V5Space.xs,
        children: [
          Semantics(liveRegion: true, child: status),
          if (state != TtsState.speaking && onSpeak != null)
            OutlinedButton.icon(
              onPressed: onSpeak,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              icon: const Icon(Icons.volume_up, size: 18),
              label: const Text(Copy.bunyikanLagi),
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
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(children: [
          for (var i = 0; i < 4; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 3,
              height: 5 + 9 * (0.5 + 0.5 * math.sin((_c.value + i * 0.2) * 2 * math.pi)),
              decoration: BoxDecoration(color: V5Colors.primary, borderRadius: BorderRadius.circular(2)),
            ),
        ]),
      );
}
