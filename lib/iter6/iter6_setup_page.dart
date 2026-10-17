import 'package:flutter/material.dart';

import '../variant/variant.dart';
import 'iter6_results_page.dart';
import 'iter6_run_page.dart';
import 'iter6_script.dart';
import 'iter6_session.dart';

/// Uji 4 setup: participant, card A/B, mode, then the customer card screen.
class Iter6SetupPage extends StatefulWidget {
  const Iter6SetupPage({super.key});
  @override
  State<Iter6SetupPage> createState() => _Iter6SetupPageState();
}

class _Iter6SetupPageState extends State<Iter6SetupPage> {
  final _pid = TextEditingController();
  String _card = 'A';
  String _autoAssigned = 'A';
  bool _simulated = false;
  bool _showCard = false;

  String get _id => Iter6Session.cleanId(_pid.text);

  void _autoCard(String pid) {
    final n = int.tryParse(pid.replaceAll(RegExp(r'\D'), ''));
    if (n != null) setState(() => _card = _autoAssigned = n.isOdd ? 'A' : 'B');
  }

  /// Warn before a re-run overwrites an existing participant's data.
  Future<void> _toCard() async {
    final existing = await AppHandle.read(context).storage.studies();
    if (!mounted) return;
    final exists = existing.any((s) => s['type'] == 'iter6' && s['participant'] == _id);
    if (exists) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Data $_id sudah ada'),
          content: const Text('Melanjutkan akan menimpa data dan tracking sebelumnya untuk ID ini.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Timpa')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _showCard = true);
  }

  @override
  void dispose() {
    _pid.dispose();
    super.dispose();
  }

  void _start() {
    final app = AppHandle.read(context);
    final session = Iter6Session(
      participantId: _id,
      card: _card,
      simulated: _simulated,
      storage: app.storage,
      cardOverridden: _card != _autoAssigned,
    );
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      settings: const RouteSettings(name: '/iter6/run'),
      builder: (_) => Iter6RunPage(session: session),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (_showCard) return _cardScreen(t);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uji 4 · Iterasi 6'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Iter6ResultsPage())),
            child: const Text('Hasil'),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Role-play buka rekening bank (5 interaksi) memakai antarmuka Iterasi 5.', style: t.bodyMedium),
        const SizedBox(height: 16),
        TextField(
          controller: _pid,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: const InputDecoration(labelText: 'ID partisipan', hintText: 'TT01', border: OutlineInputBorder()),
          onChanged: (v) {
            _autoCard(v);
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        Text('Kartu', style: t.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'A', label: Text('Versi A')), ButtonSegment(value: 'B', label: Text('Versi B'))],
          selected: {_card},
          onSelectionChanged: (v) => setState(() => _card = v.first),
        ),
        Text('Otomatis: ID ganjil A, ID genap B.', style: t.bodySmall),
        const SizedBox(height: 16),
        Text('Mode', style: t.titleSmall),
        RadioGroup<bool>(
          groupValue: _simulated,
          onChanged: (v) => setState(() => _simulated = v!),
          child: const Column(children: [
            RadioListTile(value: false, title: Text('Teller manusia'), subtitle: Text('Anggota tim membaca naskah; aplikasi memakai speech-to-text sungguhan.')),
            RadioListTile(value: true, title: Text('Simulasi'), subtitle: Text('Rekaman berita dan ucapan teller muncul otomatis sebagai teks.')),
          ]),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _id.isEmpty ? null : _toCard,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Lanjut ke kartu nasabah'),
        ),
      ]),
    );
  }

  /// Shown to the participant before starting (protocol: "Data dirimu ada di kartu ini").
  Widget _cardScreen(TextTheme t) {
    final c = I6Card.byId(_card);
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Text(k, style: t.bodyLarge?.copyWith(color: Colors.black54))),
            Expanded(child: Text(v, style: t.titleMedium)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: Text('Kartu nasabah · Versi ${c.id}')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              row('Nama', c.name),
              row('NIK', c.nik),
              row('Alamat', c.address),
              row('KTP', 'Ada'),
              row('NPWP', c.npwp ? 'Ada' : 'Tidak ada'),
              row('Tujuan', 'Bebas, pilih sendiri'),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Text('Kamu nasabah yang mau buka rekening. Pakai Swarana saja untuk berkomunikasi.', style: t.bodyLarge),
        const SizedBox(height: 8),
        Text('Untuk evaluator: berikan juga kartu cetak (kartu ini hilang setelah Mulai). '
            'Setiap bagian diawali instruksi; teller manusia: putar rekaman berita saat partisipan menekan "Siap, mulai".Saat formulir selesai, tekan lama titik merah kecil di bilah status (atas layar). '
            'Catat kebingungan di kertas selama role-play, lalu masukkan di halaman penilaian.', style: t.bodySmall),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _start,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          child: const Text('Mulai (stopwatch berjalan)'),
        ),
        TextButton(onPressed: () => setState(() => _showCard = false), child: const Text('Kembali')),
      ]),
    );
  }
}
