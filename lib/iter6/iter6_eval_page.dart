import 'package:flutter/material.dart';

import 'iter6_script.dart';
import 'iter6_session.dart';

/// Evaluator scoring after the role-play: per-interaction success
/// (sheet Uji4 Aplikasi) and confusion log (sheet Uji4 Kebingungan).
class Iter6EvalPage extends StatefulWidget {
  const Iter6EvalPage({super.key, required this.session});
  final Iter6Session session;

  @override
  State<Iter6EvalPage> createState() => _Iter6EvalPageState();
}

class _Iter6EvalPageState extends State<Iter6EvalPage> {
  Iter6Session get s => widget.session;

  String _mmss(int sec) => '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';

  void _addManual() {
    setState(() => s.confusions.add(I6Confusion(atSec: 0, type: 'Ragu', text: '', source: 'manual')..include = true));
  }

  Future<void> _save() async {
    final missing = s.confusions.where((c) => c.include && c.text.isEmpty).length;
    if (missing > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$missing kebingungan belum diisi teks penyebabnya.')));
      return;
    }
    s.scored = true;
    await s.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Data ${s.participantId} tersimpan')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final card = I6Card.byId(s.card);
    final success = s.interactions.where((e) => e).length;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: Text('Penilaian · ${s.participantId}'), automaticallyImplyLeading: false),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('Waktu: ${s.elapsedSec} detik · Kartu ${s.card} · ${s.simulated ? 'Simulasi' : 'Teller manusia'}',
              style: t.titleMedium),
          Text('${s.taps} ketukan · ${s.rage} rage click · pesan: '
              '${s.sendsBySource.entries.map((e) => '${e.key} ${e.value}').join(', ')}', style: t.bodySmall),
          const SizedBox(height: 8),
          // What was actually said and sent, to check the criteria against.
          ExpansionTile(
            initiallyExpanded: true,
            tilePadding: EdgeInsets.zero,
            title: Text('Transkrip obrolan (${s.transcript.length})', style: t.titleMedium),
            children: [
              if (s.transcript.isEmpty) const Text('Tidak ada pesan tercatat.'),
              for (final m in s.transcript)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 52, child: Text(_mmss(m.atSec), style: t.bodySmall)),
                    Expanded(
                      child: Text('${m.me ? 'Nasabah' : 'Lawan bicara'}: ${m.text}',
                          style: t.bodyMedium?.copyWith(fontWeight: m.me ? FontWeight.w600 : FontWeight.w400)),
                    ),
                  ]),
                ),
            ],
          ),
          const Divider(height: 32),
          Text('Interaksi berhasil: $success / 5', style: t.titleLarge),
          Text('Centang bila memenuhi "Berhasil bila". Macet > 60 detik = gagal.', style: t.bodySmall),
          for (var i = 0; i < 5; i++)
            CheckboxListTile(
              value: s.interactions[i],
              onChanged: (v) => setState(() => s.interactions[i] = v!),
              title: Text(card.criteria[i].$1),
              subtitle: Text(card.criteria[i].$2),
            ),
          const Divider(height: 32),
          Row(children: [
            Expanded(child: Text('Kebingungan', style: t.titleLarge)),
            TextButton.icon(onPressed: _addManual, icon: const Icon(Icons.add), label: const Text('Tambah')),
          ]),
          Text('Saran otomatis dari tracking: centang yang memang terjadi, lalu isi jenis dan teks penyebab.',
              style: t.bodySmall),
          const SizedBox(height: 8),
          if (s.confusions.isEmpty) const Text('Belum ada. Tekan "Tambah" untuk mencatat.'),
          for (final c in s.confusions)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Checkbox(value: c.include, onChanged: (v) => setState(() => c.include = v!)),
                    Text('${_mmss(c.atSec)} · ${c.source == 'auto' ? 'saran' : 'manual'}', style: t.labelLarge),
                  ]),
                  if (c.note.isNotEmpty) Text(c.note, style: t.bodySmall),
                  if (c.include) ...[
                    if (c.source == 'manual')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextFormField(
                          initialValue: c.atSec == 0 ? '' : _mmss(c.atSec),
                          keyboardType: TextInputType.datetime,
                          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                          decoration: const InputDecoration(labelText: 'Menit (mm:ss, dari stopwatch)', border: OutlineInputBorder()),
                          onChanged: (v) {
                            final p = v.split(':');
                            final m = int.tryParse(p.first) ?? 0;
                            final sec = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
                            c.atSec = p.length > 1 ? m * 60 + sec : m * 60;
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      for (final ty in confusionTypes)
                        ChoiceChip(label: Text(ty), selected: c.type == ty, onSelected: (_) => setState(() => c.type = ty)),
                    ]),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: interfaceTexts.contains(c.text) ? c.text : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Teks penyebab', border: OutlineInputBorder()),
                      items: [
                        for (final x in interfaceTexts) DropdownMenuItem(value: x, child: Text(x)),
                        const DropdownMenuItem(value: '__lain', child: Text('Lainnya (tulis)…')),
                      ],
                      onChanged: (v) async {
                        if (v == '__lain') {
                          final ctl = TextEditingController(text: c.text);
                          final r = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Teks penyebab'),
                              content: TextField(controller: ctl, autofocus: true),
                              actions: [TextButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('OK'))],
                            ),
                          );
                          if (r != null) setState(() => c.text = r);
                        } else {
                          setState(() => c.text = v ?? '');
                        }
                      },
                    ),
                    if (c.text.isNotEmpty && !interfaceTexts.contains(c.text))
                      Padding(padding: const EdgeInsets.only(top: 4), child: Text('Teks: ${c.text}', style: t.bodySmall)),
                  ],
                ]),
              ),
            ),
          const Divider(height: 32),
          TextField(
            maxLines: 3,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: const InputDecoration(labelText: 'Catatan evaluator', border: OutlineInputBorder()),
            onChanged: (v) => s.notes = v,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Simpan penilaian'),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
