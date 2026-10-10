import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'board_data.dart';

/// Quick phrases for face-to-face talk. Hidden in study mode (v3 has none).
const quickPhrases = [
  'Halo, saya tuli. Mohon bicara pelan ke ponsel ini.',
  'Mohon tunggu, saya sedang mengetik.',
  'Bisa diulangi?',
  'Terima kasih.',
];

/// "Template board visual" from the IA: words append to the draft so they can
/// build a sentence; sentences are sent directly. Works offline.
class BoardSheet extends StatefulWidget {
  const BoardSheet({super.key, required this.onWord, required this.onSentence, this.onQuickPhrase, this.scroll});

  final ScrollController? scroll;
  final ValueChanged<String> onWord;
  final ValueChanged<String> onSentence;

  /// Null in study mode.
  final ValueChanged<String>? onQuickPhrase;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<String> onWord,
    required ValueChanged<String> onSentence,
    ValueChanged<String>? onQuickPhrase,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.92,
          builder: (_, scroll) =>
              BoardSheet(onWord: onWord, onSentence: onSentence, onQuickPhrase: onQuickPhrase, scroll: scroll),
        ),
      );

  @override
  State<BoardSheet> createState() => _BoardSheetState();
}

class _BoardSheetState extends State<BoardSheet> {
  int _cat = 0;
  bool _sentences = false;

  @override
  Widget build(BuildContext context) {
    final cat = boardCategories[_cat];
    final t = Theme.of(context).textTheme;
    return CustomScrollView(controller: widget.scroll, slivers: [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: V5Space.lg),
        sliver: SliverList.list(children: [
          if (widget.onQuickPhrase != null) ...[
            Text('Frasa cepat', style: t.titleSmall),
            const SizedBox(height: V5Space.sm),
            Wrap(spacing: V5Space.sm, runSpacing: V5Space.sm, children: [
              for (final p in quickPhrases)
                ActionChip(
                  avatar: const Icon(Icons.volume_up, size: 18, color: V5Colors.primary),
                  label: Text(p),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onQuickPhrase!(p);
                  },
                ),
            ]),
            const SizedBox(height: V5Space.lg),
          ],
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Kata')),
              ButtonSegment(value: true, label: Text('Kalimat')),
            ],
            selected: {_sentences},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _sentences = s.first),
          ),
          const SizedBox(height: V5Space.md),
          SizedBox(
            height: minTouch,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: boardCategories.length,
              separatorBuilder: (_, _) => const SizedBox(width: V5Space.sm),
              itemBuilder: (_, i) => ChoiceChip(
                label: Text(boardCategories[i].name),
                selected: i == _cat,
                onSelected: (_) => setState(() => _cat = i),
              ),
            ),
          ),
          const SizedBox(height: V5Space.md),
          Text(_sentences ? 'Ketuk kalimat untuk langsung mengirim.' : 'Ketuk kata untuk menambah ke pesan.',
              style: t.bodySmall),
          const SizedBox(height: V5Space.sm),
        ]),
      ),
      if (_sentences)
        SliverList.builder(
          itemCount: cat.sentences.length,
          itemBuilder: (_, i) => ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.chat_bubble_outline, color: V5Colors.primary),
            title: Text(cat.sentences[i]),
            onTap: () {
              Navigator.pop(context);
              widget.onSentence(cat.sentences[i]);
            },
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(V5Space.lg, 0, V5Space.lg, V5Space.xl),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 120,
              mainAxisSpacing: V5Space.sm,
              crossAxisSpacing: V5Space.sm,
              childAspectRatio: 0.85,
            ),
            itemCount: cat.words.length,
            itemBuilder: (_, i) {
              final w = cat.words[i];
              return Material(
                color: V5Colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: V5Colors.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => widget.onWord(w.text),
                  child: Padding(
                    padding: const EdgeInsets.all(V5Space.sm),
                    child: Column(children: [
                      Expanded(child: Image.asset(w.image, fit: BoxFit.contain, semanticLabel: w.text)),
                      const SizedBox(height: 4),
                      Text(w.text, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 13)),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
    ]);
  }
}
