import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../variant/variant.dart';

/// Hasil Uji 4 · Iterasi 6: time and successful interactions vs Iterasi 5,
/// confusion recap ("Tulis ulang" when ≥ 2 people), CSV export per sheet.
class Iter6ResultsPage extends StatefulWidget {
  const Iter6ResultsPage({super.key});
  @override
  State<Iter6ResultsPage> createState() => _Iter6ResultsPageState();
}

class _Iter6ResultsPageState extends State<Iter6ResultsPage> {
  Future<List<Map<String, Object?>>>? _data;
  late double _baseTime;
  late double _baseSuccess;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data != null) return;
    final app = AppHandle.read(context);
    _baseTime = app.settings.prefs.getDouble('i6_base_time') ?? 131;
    _baseSuccess = app.settings.prefs.getDouble('i6_base_success') ?? 5;
    _reload();
  }

  void _reload() {
    final st = AppHandle.read(context).storage;
    _data = st.studies().then((l) => l.where((s) => s['type'] == 'iter6').toList()
      ..sort((a, b) => '${a['participant']}'.compareTo('${b['participant']}')));
    setState(() {});
  }

  Future<void> _editBaseline() async {
    final time = TextEditingController(text: _baseTime.toStringAsFixed(0));
    final succ = TextEditingController(text: _baseSuccess.toStringAsFixed(1));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pembanding Iterasi 5'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: time, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Waktu skenario kompleks (detik)')),
          TextField(controller: succ, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Interaksi berhasil rata-rata (0–5)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final prefs = AppHandle.read(context).settings.prefs;
    setState(() {
      _baseTime = double.tryParse(time.text.replaceAll(',', '.')) ?? _baseTime;
      _baseSuccess = double.tryParse(succ.text.replaceAll(',', '.')) ?? _baseSuccess;
    });
    prefs.setDouble('i6_base_time', _baseTime);
    prefs.setDouble('i6_base_success', _baseSuccess);
  }

  String _csvCell(Object? v) {
    final s = '${v ?? ''}';
    return s.contains(RegExp(r'[",\n;]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  Future<void> _export(List<Map<String, Object?>> rows) async {
    final app = StringBuffer('Partisipan,Kartu,Mode,Waktu (detik),Interaksi berhasil (0-5),I1,I2,I3,I4,I5,Ketukan,Rage click,Catatan\n');
    final conf = StringBuffer('Partisipan,Menit,Teks penyebab,Yang terjadi,Sumber,Catatan\n');
    for (final r in rows) {
      final it = (r['interactions'] as List).cast<bool>();
      app.writeln([
        r['participant'], r['card'], r['mode'], r['time_s'], r['success_count'],
        ...it.map((b) => b ? 1 : 0), r['taps'], r['rage_clicks'], r['notes'],
      ].map(_csvCell).join(','));
      for (final c in (r['confusions'] as List).cast<Map>()) {
        final s = (c['at_s'] as num).toInt();
        conf.writeln([
          r['participant'], '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}', c['text'], c['type'], c['source'], c['note'],
        ].map(_csvCell).join(','));
      }
    }
    final dir = await getTemporaryDirectory();
    final f1 = await File('${dir.path}/Uji4_Aplikasi_Iterasi6.csv').writeAsString(app.toString());
    final f2 = await File('${dir.path}/Uji4_Kebingungan_Iterasi6.csv').writeAsString(conf.toString());
    await SharePlus.instance.share(ShareParams(files: [XFile(f1.path), XFile(f2.path)], title: 'Hasil Uji 4 Iterasi 6'));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Hasil Uji 4 · Iterasi 6'), actions: [
        IconButton(tooltip: 'Pembanding Iterasi 5', onPressed: _editBaseline, icon: const Icon(Icons.tune)),
      ]),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _data,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data!;
          if (rows.isEmpty) return const Center(child: Text('Belum ada data Uji 4.'));
          double mean(Iterable<num> xs) => xs.isEmpty ? 0 : xs.fold<double>(0, (a, b) => a + b) / xs.length;
          final time = mean(rows.map((r) => r['time_s'] as num));
          final succ = mean(rows.map((r) => r['success_count'] as num));

          // Confusion recap: text → distinct participants.
          final byText = <String, Set<String>>{};
          final count = <String, int>{};
          for (final r in rows) {
            for (final c in (r['confusions'] as List).cast<Map>()) {
              final k = '${c['text']}';
              byText.putIfAbsent(k, () => {}).add('${r['participant']}');
              count[k] = (count[k] ?? 0) + 1;
            }
          }
          final recap = byText.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));

          TableRow tr(List<String> cells, {bool bold = false}) => TableRow(children: [
                for (final c in cells)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Text(c, style: TextStyle(fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
                  ),
              ]);

          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('n = ${rows.length} · ${rows.where((r) => r['mode'] == 'simulasi').length} simulasi', style: t.bodySmall),
            const SizedBox(height: 8),
            Table(columnWidths: const {0: FlexColumnWidth(2)}, children: [
              tr(['Ukuran', 'Iterasi 5', 'Iterasi 6', 'Target'], bold: true),
              tr(['Waktu (detik)', _baseTime.toStringAsFixed(0), time.toStringAsFixed(0), '–']),
              tr(['Interaksi berhasil (0–5)', _baseSuccess.toStringAsFixed(1), succ.toStringAsFixed(1),
                  succ >= _baseSuccess ? 'Tercapai' : 'Belum']),
            ]),
            Text('SEQ dan SUS diisi di luar aplikasi.', style: t.bodySmall),
            const SizedBox(height: 20),
            Text('Rekap kebingungan', style: t.titleMedium),
            if (recap.isEmpty) const Text('Tidak ada kebingungan tercatat.'),
            if (recap.isNotEmpty)
              Table(columnWidths: const {0: FlexColumnWidth(2)}, children: [
                tr(['Teks', 'Orang', 'Kejadian', 'Status'], bold: true),
                for (final e in recap)
                  tr([e.key, '${e.value.length}', '${count[e.key]}', e.value.length >= 2 ? 'Tulis ulang' : 'OK']),
              ]),
            const SizedBox(height: 20),
            Text('Per partisipan', style: t.titleMedium),
            for (final r in rows)
              ListTile(
                title: Text('${r['participant']} · Kartu ${r['card']} · ${r['mode'] == 'simulasi' ? 'Simulasi' : 'Teller'}'),
                subtitle: Text('${r['time_s']} detik · ${r['success_count']}/5 berhasil · '
                    '${(r['confusions'] as List).length} kebingungan · ${r['taps']} ketukan'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Hapus',
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Hapus data ${r['participant']}?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
                        ],
                      ),
                    );
                    if (ok != true || !context.mounted) return;
                    await AppHandle.read(context).storage.deleteStudy('I6-${r['participant']}');
                    if (mounted) _reload();
                  },
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _export(rows),
              icon: const Icon(Icons.ios_share),
              label: const Text('Ekspor CSV (Uji4 Aplikasi + Kebingungan)'),
            ),
          ]);
        },
      ),
    );
  }
}
