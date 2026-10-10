import 'package:flutter/material.dart';

import '../copy.dart';
import '../design/tokens.dart';
import '../obrolan/obrolan_controller.dart';

/// AI reply suggestions above the composer.
///
/// REVIEW: Figma used one horizontally scrolling row whose second chip was cut
/// mid-word; chips now wrap (max ~2 rows) so every option is visible. The close
/// button is neutral grey instead of error-red.
class SuggestionsPanel extends StatelessWidget {
  const SuggestionsPanel({
    super.key,
    required this.state,
    required this.items,
    required this.onSend,
    required this.onEdit,
    required this.onClose,
    required this.onRetry,
  });

  final SuggestState state;
  final List<String> items;
  final ValueChanged<String> onSend;
  final ValueChanged<String> onEdit;
  final VoidCallback onClose;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state == SuggestState.hidden) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(V5Space.lg, V5Space.sm, V5Space.xs, V5Space.md),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FF),
        border: Border(top: BorderSide(color: V5Colors.border)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: V5Colors.aiTint, borderRadius: BorderRadius.circular(V5Radius.pill)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome, size: 14, color: V5Colors.primary),
              SizedBox(width: 4),
              Text(Copy.rekomendasi, style: TextStyle(fontSize: 13, color: V5Colors.primary, fontWeight: FontWeight.w500)),
            ]),
          ),
          const Spacer(),
          IconButton(onPressed: onClose, tooltip: 'Tutup saran', icon: const Icon(Icons.close, color: V5Colors.muted)),
        ]),
        const SizedBox(height: V5Space.xs),
        switch (state) {
          SuggestState.loading => Wrap(spacing: V5Space.sm, runSpacing: V5Space.sm, children: [
              for (final w in [140.0, 180.0, 110.0]) _Skeleton(width: w),
            ]),
          SuggestState.error => Row(children: [
              const Expanded(child: Text('Saran tidak tersedia saat ini.', style: TextStyle(color: V5Colors.muted))),
              TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
            ]),
          // Capped height so long suggestions at large text never push the
          // composer off screen.
          _ => ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Wrap(spacing: V5Space.sm, runSpacing: V5Space.sm, children: [
                  for (final s in items)
                    Semantics(
                      hint: 'Ketuk untuk kirim, tekan lama untuk ubah dulu',
                      child: OutlinedButton(
                        onPressed: () => onSend(s),
                        onLongPress: () => onEdit(s),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: V5Colors.surface,
                          padding: const EdgeInsets.symmetric(horizontal: V5Space.lg, vertical: 10),
                        ),
                        child: Text(s, style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                ]),
              ),
            ),
        },
      ]),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: minTouch,
        decoration: BoxDecoration(color: const Color(0xFFE6E9F2), borderRadius: BorderRadius.circular(V5Radius.pill)),
      );
}
