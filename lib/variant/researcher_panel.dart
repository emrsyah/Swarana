import 'package:flutter/material.dart';

import '../core/services/alerts.dart';
import '../core/services/services.dart';
import '../ux_kit/ux_models.dart';
import 'variant.dart';

/// Hidden setup page for moderated tests. Plain Material on purpose.
class ResearcherPanel extends StatefulWidget {
  const ResearcherPanel({super.key});

  @override
  State<ResearcherPanel> createState() => _ResearcherPanelState();
}

class _ResearcherPanelState extends State<ResearcherPanel> {
  final _pid = TextEditingController();
  String _order = 'AB';
  final _selected = <String>{};
  bool _scripted = false;
  int _breakMin = 15;
  Map<String, Object?>? _unfinished;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selected.isEmpty) _selected.addAll(AppHandle.of(context).scenarios.keys);
    _loadUnfinished();
  }

  Future<void> _loadUnfinished() async {
    final all = await AppHandle.of(context).storage.studies();
    final open = all
        .where((s) => s['finished'] != true && s['aborted'] != true && s['config'] != null)
        .toList();
    if (mounted) setState(() => _unfinished = open.isEmpty ? null : open.last);
  }

  void _suggestOrder(String pid) {
    final n = int.tryParse(pid.replaceAll(RegExp(r'\D'), ''));
    if (n != null) setState(() => _order = n.isEven ? 'AB' : 'BA');
  }

  void _start() {
    final app = AppHandle.of(context);
    final pid = _pid.text.trim();
    if (pid.isEmpty || _selected.isEmpty) return;
    final ordered = app.scenarios.keys.where(_selected.contains).toList();
    app.ux.startStudy(StudyConfig(
      participantId: pid,
      order: _order == 'AB'
          ? [AppVariant.v3Board, AppVariant.v5Chat]
          : [AppVariant.v5Chat, AppVariant.v3Board],
      scenarioIds: ordered,
      scripted: _scripted,
      breakDuration: Duration(minutes: _breakMin),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppHandle.of(context);
    final t = Theme.of(context).textTheme;
    final pidOk = _pid.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Panel peneliti')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_unfinished != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.restore),
              title: Text('Lanjutkan sesi ${(_unfinished!['config'] as Map)['participant']}'),
              subtitle: const Text('Sesi sebelumnya belum selesai. Tugas terakhir diulang dari awal.'),
              onTap: () => app.ux.resume(_unfinished!),
            ),
          ),
        Text('Sesi uji A/B', style: t.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _pid,
          decoration: const InputDecoration(labelText: 'ID partisipan', hintText: 'contoh: P03', border: OutlineInputBorder()),
          onChanged: (v) {
            _suggestOrder(v);
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        Text('Urutan versi', style: t.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'AB', label: Text('v3 → v5')),
            ButtonSegment(value: 'BA', label: Text('v5 → v3')),
          ],
          selected: {_order},
          onSelectionChanged: (s) => setState(() => _order = s.first),
        ),
        Text('Disarankan: ID genap v3 dulu, ID ganjil v5 dulu.', style: t.bodySmall),
        const SizedBox(height: 16),
        Text('Skenario (urutan dirotasi per partisipan)', style: t.titleSmall),
        for (final s in app.scenarios.values)
          CheckboxListTile(
            value: _selected.contains(s.id),
            title: Text(s.title),
            subtitle: Text('${s.complexity} · ${s.forms['A']!.interactionCount} interaksi'),
            onChanged: (v) => setState(() => v! ? _selected.add(s.id) : _selected.remove(s.id)),
          ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _scripted,
          title: const Text('Lawan bicara otomatis (skrip)'),
          subtitle: const Text('Untuk uji coba atau tanpa internet. Studi utama: lawan bicara manusia membaca kartu skrip.'),
          onChanged: (v) => setState(() => _scripted = v),
        ),
        ListTile(
          title: const Text('Istirahat antar versi'),
          trailing: DropdownButton<int>(
            value: _breakMin,
            items: const [0, 1, 5, 10, 15]
                .map((m) => DropdownMenuItem(value: m, child: Text('$m menit')))
                .toList(),
            onChanged: (v) => setState(() => _breakMin = v!),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: pidOk && _selected.isNotEmpty ? _start : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Mulai sesi uji'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        const Divider(height: 40),
        Text('Mode bebas', style: t.titleLarge),
        const SizedBox(height: 8),
        Row(children: [
          for (final v in AppVariant.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: v == app.variant
                    ? FilledButton.tonal(onPressed: null, child: Text(v.label, textAlign: TextAlign.center))
                    : OutlinedButton(onPressed: () => app.switchVariant(v), child: Text(v.label, textAlign: TextAlign.center)),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        Text('Picu peringatan (demo)', style: t.titleSmall),
        Wrap(spacing: 8, children: [
          for (final k in AlertKind.values)
            ActionChip(label: Text(k.name), onPressed: () => Services.of(context).alerts.raise(k)),
        ]),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pushNamed('/results'),
          icon: const Icon(Icons.table_chart_outlined),
          label: const Text('Lihat hasil uji'),
        ),
      ]),
    );
  }
}
