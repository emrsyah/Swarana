import 'package:flutter/material.dart';

import '../copy.dart';
import '../design/tokens.dart';

enum SaveChoice { save, discard }

/// REVIEW: Figma's save dialog had "Buang" next to "Simpan" with equal weight,
/// no cancel and no confirmation. Here: Batal, a primary Simpan, and Buang as
/// a red text button that asks again.
Future<(SaveChoice, String)?> showSaveDialog(
  BuildContext context, {
  required String heading,
  required Future<String> suggestedTitle,
}) =>
    showDialog<(SaveChoice, String)>(
      context: context,
      builder: (_) => _SaveDialog(heading: heading, suggestedTitle: suggestedTitle),
    );

class _SaveDialog extends StatefulWidget {
  const _SaveDialog({required this.heading, required this.suggestedTitle});
  final String heading;
  final Future<String> suggestedTitle;

  @override
  State<_SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<_SaveDialog> {
  final _title = TextEditingController();
  bool _loading = true;
  bool _confirmDiscard = false;

  @override
  void initState() {
    super.initState();
    widget.suggestedTitle.then((t) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_title.text.isEmpty) _title.text = t;
      });
    });
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmDiscard) {
      return AlertDialog(
        title: const Text('Buang tanpa menyimpan?'),
        content: const Text('Isi obrolan akan hilang dan tidak bisa dibuka lagi.'),
        actions: [
          TextButton(onPressed: () => setState(() => _confirmDiscard = false), child: const Text(Copy.batal)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: V5Colors.error),
            onPressed: () => Navigator.pop(context, (SaveChoice.discard, '')),
            child: const Text(Copy.buang),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(widget.heading),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _title,
          autofocus: false,
          decoration: InputDecoration(
            labelText: 'Judul',
            suffixIcon: _loading
                ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                : null,
          ),
        ),
        const SizedBox(height: V5Space.sm),
        const Row(children: [
          Icon(Icons.auto_awesome, size: 14, color: V5Colors.primary),
          SizedBox(width: 4),
          Expanded(child: Text('Judul dibuat AI, bisa kamu ubah.', style: TextStyle(fontSize: 13, color: V5Colors.muted))),
        ]),
      ]),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: V5Colors.error),
          onPressed: () => setState(() => _confirmDiscard = true),
          child: const Text(Copy.buang),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(Copy.batal)),
          FilledButton(
            onPressed: () => Navigator.pop(context, (SaveChoice.save, _title.text)),
            child: const Text(Copy.simpan),
          ),
        ]),
      ],
    );
  }
}

/// Single text field dialog (rename speaker, rename item, correct text).
Future<String?> showTextDialog(
  BuildContext context, {
  required String title,
  required String initial,
  String label = 'Nama',
  int maxLines = 1,
}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(Copy.batal)),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text(Copy.simpan)),
      ],
    ),
  ).whenComplete(c.dispose);
}

Future<bool> confirmDelete(BuildContext context, String what) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus $what?'),
        content: const Text('Data ini akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(Copy.batal)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: V5Colors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(Copy.hapus),
          ),
        ],
      ),
    ) ==
    true;
