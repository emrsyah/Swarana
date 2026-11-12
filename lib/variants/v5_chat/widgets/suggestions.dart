import 'package:flutter/material.dart';

import '../copy.dart';
import '../design/tokens.dart';
import '../obrolan/obrolan_controller.dart';

/// AI reply suggestions above the composer.
///
/// Figma: "✦ Rekomendasi Balasan" header with a chevron that folds the panel.
/// REVIEW: Figma used one horizontally scrolling row whose second chip was cut
/// mid-word; chips wrap (max ~2 rows) so every option is visible.
class SuggestionsPanel extends StatefulWidget {
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
  State<SuggestionsPanel> createState() => _SuggestionsPanelState();
}

class _SuggestionsPanelState extends State<SuggestionsPanel> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final state = w.state, items = w.items, onSend = w.onSend, onEdit = w.onEdit, onRetry = w.onRetry;
    if (state == SuggestState.hidden) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(V5Space.lg, 0, V5Space.xs, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFF),
        border: const Border(top: BorderSide(color: V5Colors.border)),
        boxShadow: [BoxShadow(color: V5Colors.primary.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: minTouch),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: V5Colors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      Copy.rekomendasi,
                      style: TextStyle(fontSize: 14, color: V5Colors.primary, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Semantics(
                    label: _open ? 'Sembunyikan saran' : 'Tampilkan saran',
                    child: Padding(
                      padding: const EdgeInsets.all(V5Space.md),
                      child: Icon(_open ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded, color: V5Colors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const Divider(height: 1),
            const SizedBox(height: V5Space.sm),
            switch (state) {
              SuggestState.loading => Wrap(
                spacing: V5Space.sm,
                runSpacing: V5Space.sm,
                children: [
                  for (final w in [140.0, 180.0, 110.0]) _Skeleton(width: w),
                ],
              ),
              SuggestState.error => Row(
                children: [
                  const Expanded(
                    child: Text('Saran tidak tersedia saat ini.', style: TextStyle(color: V5Colors.muted)),
                  ),
                  TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
                ],
              ),
              // Capped height so long suggestions at large text never push the
              // composer off screen.
              _ => ConstrainedBox(
                // Tall enough for 3 short chips on 2 rows without a cut-off row.
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: V5Space.sm,
                    runSpacing: V5Space.sm,
                    children: [
                      for (final s in items)
                        Semantics(
                          hint: 'Ketuk untuk kirim, tekan lama untuk ubah dulu',
                          child: OutlinedButton(
                            onPressed: () => onSend(s),
                            onLongPress: () => onEdit(s),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: V5Colors.surface,
                              minimumSize: const Size(0, 44),
                              tapTargetSize: MaterialTapTargetSize.padded,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            child: Text(s, style: const TextStyle(fontSize: 15, height: 1.25)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            },
            const SizedBox(height: V5Space.md),
          ],
        ],
      ),
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
