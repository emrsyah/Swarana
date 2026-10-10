import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/message.dart';
import '../copy.dart';
import '../design/tokens.dart';

enum MessageAction { speak, simplify, explain, copy, askRepeat, correct }

/// Long-press menu, identical in live chat and history (review: simplify and
/// ask-AI were only reachable in Riwayat/Transkrip).
Future<void> showMessageMenu(
  BuildContext context, {
  required ChatMessage message,
  required void Function(MessageAction) onAction,
}) {
  final actions = <(MessageAction, IconData, String)>[
    if (message.isMe) (MessageAction.speak, Icons.volume_up, Copy.bunyikanLagi),
    (MessageAction.simplify, Icons.auto_awesome, Copy.sederhanakan),
    (MessageAction.explain, Icons.help_outline, '${Copy.tanyaArti} kata'),
    if (!message.isMe) (MessageAction.correct, Icons.edit_outlined, 'Perbaiki tulisan'),
    if (!message.isMe) (MessageAction.askRepeat, Icons.replay, Copy.mintaUlangi),
    (MessageAction.copy, Icons.copy, Copy.salin),
  ];
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(V5Space.xl, 0, V5Space.xl, V5Space.md),
          child: Text(message.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(ctx).textTheme.bodyMedium),
        ),
        const Divider(),
        for (final (a, icon, label) in actions)
          ListTile(
            minTileHeight: 56,
            leading: Icon(icon, color: V5Colors.primary),
            title: Text(label),
            onTap: () {
              Navigator.pop(ctx);
              if (a == MessageAction.copy) {
                Clipboard.setData(ClipboardData(text: message.text));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teks disalin')));
              }
              onAction(a);
            },
          ),
      ]),
    ),
  );
}

/// Pick a word from the message, then show the AI explanation.
Future<void> showExplainSheet(
  BuildContext context, {
  required String text,
  required Future<String?> Function(String word) explain,
}) {
  final words = text
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceAll(RegExp(r'^[^\wÀ-ÿ-]+|[^\wÀ-ÿ-]+$'), ''))
      .where((w) => w.length > 2)
      .toSet()
      .toList();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _ExplainSheet(words: words, explain: explain),
  );
}

class _ExplainSheet extends StatefulWidget {
  const _ExplainSheet({required this.words, required this.explain});
  final List<String> words;
  final Future<String?> Function(String word) explain;

  @override
  State<_ExplainSheet> createState() => _ExplainSheetState();
}

class _ExplainSheetState extends State<_ExplainSheet> {
  String? _word;
  String? _answer;
  bool _loading = false;
  bool _failed = false;

  Future<void> _ask(String w) async {
    setState(() {
      _word = w;
      _loading = true;
      _failed = false;
      _answer = null;
    });
    final r = await widget.explain(w);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _answer = r;
      _failed = r == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(V5Space.xl, 0, V5Space.xl, V5Space.xl),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pilih kata yang ingin ditanyakan', style: t.titleMedium),
          const SizedBox(height: V5Space.md),
          Wrap(spacing: V5Space.sm, runSpacing: V5Space.sm, children: [
            for (final w in widget.words)
              ChoiceChip(
                label: Text(w),
                selected: w == _word,
                selectedColor: V5Colors.highlight,
                onSelected: (_) => _ask(w),
              ),
          ]),
          if (_word != null) ...[
            const SizedBox(height: V5Space.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(V5Space.lg),
              decoration: BoxDecoration(color: V5Colors.aiTint, borderRadius: BorderRadius.circular(V5Radius.card)),
              child: _loading
                  ? const Row(children: [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: V5Space.md),
                      Text('Menanyakan ke AI…'),
                    ])
                  : _failed
                      ? Row(children: [
                          const Expanded(child: Text('Penjelasan tidak tersedia. Periksa internet.')),
                          TextButton(onPressed: () => _ask(_word!), child: const Text('Coba lagi')),
                        ])
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_word!, style: t.titleSmall?.copyWith(color: V5Colors.primary)),
                          const SizedBox(height: 4),
                          Text(_answer!, style: t.bodyLarge),
                        ]),
            ),
          ],
        ]),
      ),
    );
  }
}
