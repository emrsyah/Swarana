import 'package:flutter/material.dart';

import '../../../core/services/alerts.dart';
import '../design/tokens.dart';

/// Visual twin of every audio problem: the user cannot hear that the room is
/// noisy or that the phone is muted, so it is shown (and vibrated, see Alerts).
class AlertBanner extends StatelessWidget {
  const AlertBanner({super.key, required this.kind, required this.onClose, this.onAction});

  final AlertKind kind;
  final VoidCallback onClose;
  final VoidCallback? onAction;

  static (String, String?, bool) content(AlertKind k) => switch (k) {
        AlertKind.noisy => ('Suasana terlalu bising. Dekatkan ponsel ke orang yang bicara.', null, false),
        AlertKind.volumeLow => ('Volume ponsel kecil. Lawan bicara mungkin tidak mendengar suaramu.', null, false),
        AlertKind.volumeMuted => ('Volume ponsel 0. Suara tidak keluar, naikkan volume lalu bunyikan lagi.', null, true),
        AlertKind.speechWhilePaused => ('Ada yang bicara, tetapi Swarana sedang jeda.', 'Lanjutkan', false),
        AlertKind.offline => ('Tidak ada internet. Saran AI tidak tersedia, papan tetap bisa dipakai.', null, true),
        AlertKind.micDenied => ('Swarana belum boleh memakai mikrofon.', 'Buka pengaturan', true),
      };

  @override
  Widget build(BuildContext context) {
    final (text, action, severe) = content(kind);
    final fg = severe ? V5Colors.error : V5Colors.warningIcon;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(V5Space.lg, V5Space.md, V5Space.lg, 0),
        padding: const EdgeInsets.fromLTRB(V5Space.md, V5Space.sm, V5Space.xs, V5Space.sm),
        decoration: BoxDecoration(
          color: severe ? V5Colors.errorBg : V5Colors.warningBg,
          border: Border.all(color: severe ? V5Colors.error.withValues(alpha: 0.4) : V5Colors.warningBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(severe ? Icons.error : Icons.warning_amber_rounded, color: fg),
          const SizedBox(width: V5Space.sm),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.35, color: V5Colors.ink))),
          if (action != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(action)),
          IconButton(onPressed: onClose, tooltip: 'Tutup', icon: const Icon(Icons.close, color: V5Colors.muted)),
        ]),
      ),
    );
  }
}

/// Short red flash around the screen edge when an alert fires, so it is
/// noticed even when the user is looking at the partner.
class EdgeFlash extends StatefulWidget {
  const EdgeFlash({super.key, required this.trigger, required this.child});
  final Object? trigger;
  final Widget child;

  @override
  State<EdgeFlash> createState() => _EdgeFlashState();
}

class _EdgeFlashState extends State<EdgeFlash> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  @override
  void didUpdateWidget(EdgeFlash old) {
    super.didUpdateWidget(old);
    if (widget.trigger != null && widget.trigger != old.trigger && !MediaQuery.disableAnimationsOf(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) {
                final a = _c.isAnimating ? (1 - _c.value) : 0.0;
                return a == 0
                    ? const SizedBox.shrink()
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: V5Colors.warningBorder.withValues(alpha: a), width: 6),
                        ),
                      );
              },
            ),
          ),
        ),
      ]);
}
