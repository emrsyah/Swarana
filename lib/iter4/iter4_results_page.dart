import 'package:flutter/material.dart';

import '../core/services/storage.dart';
import 'iter4_controller.dart';

/// Iteration-4 results: completion, time and errors per option × task.
class Iter4ResultsPage extends StatelessWidget {
  const Iter4ResultsPage({super.key, required this.storage});
  final Storage storage;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Hasil Iterasi 4')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: storage.studies(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final studies = snap.data!.where((s) => s['type'] == 'iter4').toList();
          if (studies.isEmpty) return const Center(child: Text('Belum ada data Iterasi 4.'));
          final rows = [
            for (final s in studies)
              for (final r in (s['tasks'] as List)) (r as Map).cast<String, Object?>(),
          ];
          Iterable<Map<String, Object?>> of(I4Option o, [I4Task? k]) =>
              rows.where((r) => r['option'] == o.id && (k == null || r['task'] == k.id));
          String pct(Iterable<Map<String, Object?>> rs) =>
              rs.isEmpty ? '–' : '${(rs.where((r) => r['completed'] == true).length * 100 / rs.length).round()}%';
          String secs(Iterable<Map<String, Object?>> rs) {
            final ok = rs.where((r) => r['completed'] == true).map((r) => (r['time_ms'] as num) / 1000).toList();
            return ok.isEmpty ? '–' : (ok.reduce((a, b) => a + b) / ok.length).toStringAsFixed(1);
          }

          String errs(Iterable<Map<String, Object?>> rs) => rs.isEmpty
              ? '–'
              : (rs.map((r) => r['errors'] as num).fold<num>(0, (a, b) => a + b) / rs.length).toStringAsFixed(1);

          TableRow tr(List<String> cells, {bool bold = false}) => TableRow(children: [
                for (final c in cells)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Text(c, style: TextStyle(fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
                  ),
              ]);

          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('n = ${studies.length} partisipan', style: t.bodySmall),
            const SizedBox(height: 12),
            for (final metric in [
              ('Completion rate', pct),
              ('Waktu rata-rata tugas berhasil (detik)', secs),
              ('Error per tugas (rata-rata)', errs),
            ]) ...[
              Text(metric.$1, style: t.titleMedium),
              Table(
                columnWidths: const {0: FlexColumnWidth(1.6)},
                children: [
                  tr(['Opsi', ...I4Task.values.map((k) => '${k.id} ${k.title}'), 'Semua'], bold: true),
                  for (final o in I4Option.values)
                    tr([o.label.split(' · ').last, ...I4Task.values.map((k) => metric.$2(of(o, k))), metric.$2(of(o))]),
                ],
              ),
              const SizedBox(height: 20),
            ],
            Text('Per partisipan', style: t.titleMedium),
            for (final s in studies)
              ExpansionTile(
                title: Text('${s['participant']}${s['finished'] == true ? '' : ' · belum selesai'}'),
                subtitle: Text((s['order'] as List).join(' → ')),
                children: [
                  for (final r in (s['tasks'] as List).cast<Map>())
                    ListTile(
                      dense: true,
                      title: Text('${r['option']} · ${r['task']} · ${r['outcome']}'),
                      subtitle: Text('${((r['time_ms'] as num) / 1000).toStringAsFixed(1)} s · '
                          '${r['errors']} error ${(r['error_kinds'] as List).isEmpty ? '' : '(${(r['error_kinds'] as List).join(', ')})'} · '
                          '${r['taps']} ketukan'),
                    ),
                ],
              ),
          ]);
        },
      ),
    );
  }
}
