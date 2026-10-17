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
  // Iterasi 5 reference values: entered by the team (no defaults, source them).
  double? _baseTime;
  double? _baseSuccess;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data != null) return;
    final app = AppHandle.read(context);
    _baseTime = app.settings.prefs.getDouble('i6_base_time');
    _baseSuccess = app.settings.prefs.getDouble('i6_base_success');
    _reload();
  }

  void _reload() {
    final st = AppHandle.read(context).storage;
    _data = st.studies().then((l) => l.where((s) => s['type'] == 'iter6').toList()
      ..sort((a, b) => '${a['participant']}'.compareTo('${b['participant']}')));
    setState(() {});
  }

  Future<void> _editBaseline() async {
    final time = TextEditingController(text: _baseTime?.toStringAsFixed(0) ?? '');
    final succ = TextEditingController(text: _baseSuccess?.toStringAsFixed(1) ?? '');
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
      _baseTime = double.tryParse(time.text.replaceAll(',', '.'));
      _baseSuccess = double.tryParse(succ.text.replaceAll(',', '.'));
    });
    _baseTime == null ? prefs.remove('i6_base_time') : prefs.setDouble('i6_base_time', _baseTime!);
    _baseSuccess == null ? prefs.remove('i6_base_success') : prefs.setDouble('i6_base_success', _baseSuccess!);
  }

  String _csvCell(Object? v) {
    final s = '${v ?? ''}';
    return s.contains(RegExp(r'[",\n;]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  Future<void> _export(List<Map<String, Object?>> rows) async {
    // Worksheet column order first (paste-ready), extras after.
    // SEQ and SUS stay empty: they are filled from the paper forms.
    final app = StringBuffer('Partisipan,Kartu,Waktu (detik),Interaksi berhasil (0-5),SEQ (1-7),'
        'SUS1,SUS2,SUS3,SUS4,SUS5,SUS6,SUS7,SUS8,SUS9,SUS10,'
        'Mode,Dinilai,I1,I2,I3,I4,I5,Ketukan,Rage click,Catatan\n');
    final conf = StringBuffer('Partisipan,Teks penyebab,Yang terjadi,Detik ke-,Sumber,Catatan\n');
    for (final r in rows) {
      final it = (r['interactions'] as List).cast<bool>();
      app.writeln([
        r['participant'], r['card'], r['time_s'], r['success_count'], '',
        for (var i = 0; i < 10; i++) '',
        r['mode'], r['scored'] == true ? 'ya' : 'tidak',
        ...it.map((b) => b ? 1 : 0), r['taps'], r['rage_clicks'], r['notes'],
      ].map(_csvCell).join(','));
      for (final c in (r['confusions'] as List).cast<Map>()) {
        conf.writeln([
          r['participant'], c['text'], c['type'], (c['at_s'] as num).toInt(), c['source'], c['note'],
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
          // Only scored, human-teller sessions are comparable with Iterasi 5;
          // simulation runs are a pilot and reported separately.
          final comparable = rows.where((r) => r['scored'] == true && r['mode'] == 'teller_manusia').toList();
          final sims = rows.where((r) => r['mode'] == 'simulasi').length;
          final unscored = rows.where((r) => r['scored'] != true).length;
          final time = mean(comparable.map((r) => r['time_s'] as num));
          final succ = mean(comparable.map((r) => r['success_count'] as num));
          String base(double? v, int d) => v == null ? '– (isi ⚙)' : v.toStringAsFixed(d);

          // Confusion recap: text → distinct participants (comparable sessions).
          final byText = <String, Set<String>>{};
          final count = <String, int>{};
          for (final r in comparable) {
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
            Text('Dihitung: n = ${comparable.length} (teller manusia, sudah dinilai). '
                'Tidak dihitung: $sims simulasi, $unscored belum dinilai.', style: t.bodySmall),
            const SizedBox(height: 8),
            if (comparable.isEmpty)
              const Text('Belum ada sesi teller manusia yang sudah dinilai.')
            else
              Table(columnWidths: const {0: FlexColumnWidth(2)}, children: [
                tr(['Ukuran', 'Iterasi 5', 'Iterasi 6', 'Target'], bold: true),
                tr(['Waktu (detik)', base(_baseTime, 0), time.toStringAsFixed(0), '–']),
                tr(['Interaksi berhasil (0–5)', base(_baseSuccess, 1), succ.toStringAsFixed(1),
                    _baseSuccess == null ? '–' : (succ >= _baseSuccess! ? 'Tercapai' : 'Belum')]),
              ]),
            Text('Isi angka Iterasi 5 (khusus Teman Tuli, skenario buka rekening) lewat ⚙.', style: t.bodySmall),
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
