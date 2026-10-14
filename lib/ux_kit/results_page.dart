import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/models/app_variant.dart';
import '../core/services/storage.dart';
import 'ux_models.dart';

/// Researcher dashboard: per participant results and the v3 vs v5 summary
/// in the same shape as the report table.
class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key, required this.storage});
  final Storage storage;

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  late Future<List<_Study>> _studies = _load();

  Future<List<_Study>> _load() async => (await widget.storage.studies())
      .where((j) => j['config'] != null)
      .map(_Study.fromJson)
      .toList()
    ..sort((a, b) => a.participant.compareTo(b.participant));

  Future<void> _export() async {
    final f = await widget.storage.exportAll();
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], title: 'Data uji Swarana'));
  }

  Future<void> _delete(String pid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus data $pid?'),
        content: const Text('Data sesi uji ini akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.storage.deleteStudy(pid);
    setState(() => _studies = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil uji'),
        actions: [IconButton(tooltip: 'Ekspor JSON', onPressed: _export, icon: const Icon(Icons.ios_share))],
      ),
      body: FutureBuilder<List<_Study>>(
        future: _studies,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final studies = snap.data!;
          if (studies.isEmpty) {
            return const Center(child: Text('Belum ada data uji.'));
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (studies.any((s) => s.simulated))
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E6),
                  border: Border.all(color: const Color(0xFFF5C451)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Data simulasi: sebagian atau semua data di halaman ini bukan hasil sesi uji yang direkam.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            _Summary(studies: studies),
            const SizedBox(height: 24),
            for (final s in studies) _ParticipantCard(study: s, onDelete: () => _delete(s.participant)),
          ]);
        },
      ),
    );
  }
}

class _Study {
  _Study(this.participant, this.order, this.finished, this.blocks, {this.simulated = false, this.status});

  final String participant;
  final List<AppVariant> order;
  final bool finished;
  final List<VariantBlock> blocks;
  final bool simulated;
  final String? status;

  factory _Study.fromJson(Map<String, Object?> j) {
    final cfg = StudyConfig.fromJson((j['config'] as Map).cast());
    return _Study(
      cfg.participantId,
      cfg.order,
      j['finished'] == true,
      (j['blocks'] as List).map((e) => VariantBlock.fromJson((e as Map).cast())).toList(),
      simulated: j['simulated'] == true,
      status: j['participant_status'] as String?,
    );
  }

  VariantBlock? block(AppVariant v) => blocks.where((b) => b.variant == v).firstOrNull;
}

// fold, not reduce: an Iterable<int> passed as Iterable<num> makes reduce's
// (num, num) => num callback fail its runtime type check (red screen on device).
double? _mean(Iterable<num> xs) => xs.isEmpty ? null : xs.fold<double>(0, (a, b) => a + b) / xs.length;
/// Per interaction when coded (ok / total interactions), else per task.
double? _successRate(Iterable<TaskResult> rs) {
  final coded = rs.where((r) => r.totalInteractions != null).toList();
  if (coded.isNotEmpty) {
    final ok = coded.fold<int>(0, (a, r) => a + r.okInteractions!);
    final total = coded.fold<int>(0, (a, r) => a + r.totalInteractions!);
    return total == 0 ? null : ok * 100 / total;
  }
  return _mean(rs.map((r) => r.outcome.isSuccess ? 100 : 0));
}

String _f(double? v, [int digits = 0]) => v == null ? '–' : v.toStringAsFixed(digits);
String _diff(double? a, double? b) {
  if (a == null || b == null || a == 0) return '–';
  final d = (b - a) / a * 100;
  return '${d >= 0 ? '+' : ''}${d.toStringAsFixed(0)}%';
}

class _Summary extends StatelessWidget {
  const _Summary({required this.studies});
  final List<_Study> studies;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Iterable<TaskResult> tasks(AppVariant v, [String? scenario]) => studies
        .expand((s) => s.block(v)?.tasks ?? const <TaskResult>[])
        .where((r) => scenario == null || r.scenarioId == scenario);

    final scenarioIds = {for (final s in studies) for (final b in s.blocks) for (final r in b.tasks) r.scenarioId}.toList();
    const v3 = AppVariant.v3Board, v5 = AppVariant.v5Chat;
    final ab = studies.where((s) => s.order.first == v3).length;

    List<String> row(String label, double? a, double? b, {int digits = 0, bool diff = true}) =>
        [label, _f(a, digits), _f(b, digits), diff ? _diff(a, b) : '–'];

    final rows = <List<String>>[
      for (final sc in scenarioIds)
        row('Waktu: $sc (detik)', _mean(tasks(v3, sc).map((r) => r.duration.inMilliseconds / 1000)),
            _mean(tasks(v5, sc).map((r) => r.duration.inMilliseconds / 1000))),
      for (final sc in scenarioIds)
        () {
          final a = _successRate(tasks(v3, sc)), b = _successRate(tasks(v5, sc));
          // Success difference in percentage points, as in the report.
          final pp = a == null || b == null ? '–' : '${b - a >= 0 ? '+' : ''}${(b - a).toStringAsFixed(0)} pp';
          return ['Success rate: $sc (%)', _f(a), _f(b), pp];
        }(),
      row('SEQ (1–7)', _mean(tasks(v3).map((r) => r.seq ?? 0).where((e) => e > 0)),
          _mean(tasks(v5).map((r) => r.seq ?? 0).where((e) => e > 0)), digits: 1),
      row('SUS', _mean(studies.map((s) => s.block(v3)?.sus).whereType<double>()),
          _mean(studies.map((s) => s.block(v5)?.sus).whereType<double>()), digits: 1),
      row('NASA-TLX raw', _mean(studies.map((s) => s.block(v3)?.tlxRaw).whereType<double>()),
          _mean(studies.map((s) => s.block(v5)?.tlxRaw).whereType<double>()), digits: 1),
    ];

    Map<String, double> mix(AppVariant v) {
      final total = <String, int>{};
      for (final r in tasks(v)) {
        r.inputMix.forEach((k, n) => total[k] = (total[k] ?? 0) + n);
      }
      final sum = total.values.fold<int>(0, (a, b) => a + b);
      return sum == 0 ? {} : total.map((k, n) => MapEntry(k, n * 100 / sum));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ringkasan v3 vs v5', style: t.titleLarge),
          Text('n = ${studies.length} · urutan AB: $ab, BA: ${studies.length - ab}', style: t.bodySmall),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {0: FlexColumnWidth(2.4)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              _tr(['Metrik', 'v3', 'v5', 'Beda'], bold: true),
              for (final r in rows) _tr(r),
            ],
          ),
          const SizedBox(height: 16),
          Text('Sumber pesan', style: t.titleMedium),
          for (final v in [v3, v5]) _MixBar(label: v == v3 ? 'v3' : 'v5', mix: mix(v)),
        ]),
      ),
    );
  }
}

TableRow _tr(List<String> cells, {bool bold = false}) => TableRow(children: [
      for (final c in cells)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text(c, style: TextStyle(fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
        ),
    ]);

class _MixBar extends StatelessWidget {
  const _MixBar({required this.label, required this.mix});
  final String label;
  final Map<String, double> mix;

  static const _colors = {
    'keyboard': Color(0xFF0072B2),
    'suggestion': Color(0xFF009E73),
    'board': Color(0xFFE69F00),
    'quick_phrase': Color(0xFFCC79A7),
  };
  static const _names = {'keyboard': 'Ketik', 'suggestion': 'Saran AI', 'board': 'Papan', 'quick_phrase': 'Frasa cepat'};

  @override
  Widget build(BuildContext context) {
    if (mix.isEmpty) return Padding(padding: const EdgeInsets.only(top: 8), child: Text('$label: belum ada pesan'));
    final entries = mix.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(children: [
            for (final e in entries)
              Expanded(
                flex: (e.value * 10).round().clamp(1, 1000),
                child: Container(height: 14, color: _colors[e.key] ?? Colors.grey),
              ),
          ]),
        ),
        const SizedBox(height: 4),
        Wrap(spacing: 12, children: [
          for (final e in entries) Text('${_names[e.key] ?? e.key} ${e.value.toStringAsFixed(0)}%'),
        ]),
      ]),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({required this.study, required this.onDelete});
  final _Study study;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: ExpansionTile(
        title: Text([
          study.participant,
          if (study.status != null) study.status!,
          if (study.simulated) 'simulasi',
        ].join(' · ')),
        subtitle: Text('${study.order.map((v) => v == AppVariant.v3Board ? 'v3' : 'v5').join(' → ')}'
            '${study.finished ? '' : ' · belum selesai'}'),
        trailing: IconButton(tooltip: 'Hapus', onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final b in study.blocks) ...[
            Text('${b.variant.label} · SUS ${b.sus ?? '–'} · TLX ${_f(b.tlxRaw, 1)}', style: t.titleSmall),
            Table(
              columnWidths: const {0: FlexColumnWidth(1.6)},
              children: [
                _tr(['Skenario', 'Detik', 'Hasil', 'SEQ', 'Ketik/Saran/Papan'], bold: true),
                for (final r in b.tasks)
                  _tr([
                    '${r.scenarioId} (${r.form})',
                    (r.duration.inMilliseconds / 1000).toStringAsFixed(0),
                    r.outcome.label,
                    '${r.seq ?? '–'}',
                    '${r.inputMix['keyboard'] ?? 0}/${r.inputMix['suggestion'] ?? 0}/${r.inputMix['board'] ?? 0}',
                  ]),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
