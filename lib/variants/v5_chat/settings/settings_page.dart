import 'package:flutter/material.dart';

import '../../../core/services/local_gemma.dart';
import '../../../core/services/services.dart';
import '../copy.dart';
import '../design/tokens.dart';
import '../drawer.dart';
import '../v5_routes.dart';
import '../widgets/text_size_slider.dart';
import 'voice_lab_page.dart';

/// Pengaturan (no Figma yet; IA: "Identifikasi Pembicara Otomatis On/Off").
class SettingsPage extends StatelessWidget {
  SettingsPage({super.key});

  final _scaffold = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final st = Services.of(context).settings;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      key: _scaffold,
      endDrawer: const V5Drawer(current: V5Routes.settings),
      appBar: AppBar(
        title: const Text(Copy.pengaturan),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: V5Space.md),
            child: IconButton.outlined(
              tooltip: 'Menu',
              onPressed: () => _scaffold.currentState!.openEndDrawer(),
              icon: const Icon(Icons.menu),
            ),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.symmetric(vertical: V5Space.md), children: [
        _Header('Obrolan'),
        ValueListenableBuilder<bool>(
          valueListenable: st.separateSpeakers,
          builder: (_, v, _) => SwitchListTile(
            value: v,
            onChanged: (x) => st.separateSpeakers.value = x,
            title: const Text('Pisahkan pembicara'),
            subtitle: const Text(
              'Tiap orang ditampilkan dengan nama dan warna sendiri. Ketuk "Orang lain bicara" saat orang lain mulai bicara.',
            ),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: st.haptics,
          builder: (_, v, _) => SwitchListTile(
            value: v,
            onChanged: (x) {
              st.haptics.value = x;
              Services.of(context).haptics.enabled = x;
            },
            title: const Text('Getaran'),
            subtitle: const Text('Ponsel bergetar saat ada pesan baru, suara selesai dibunyikan, atau ada peringatan.'),
          ),
        ),
        _Header('Tampilan'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: V5Space.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ukuran teks obrolan dan transkrip', style: tt.bodyLarge),
            TextSizeSlider(value: st.textScale),
          ]),
        ),
        _Header('AI'),
        const _LocalModelTile(),
        ListTile(
          leading: const Icon(Icons.record_voice_over_outlined),
          title: const Text('Uji deteksi pembicara (eksperimen)'),
          subtitle: const Text('Kenali siapa yang bicara dan tulis ucapannya, semua di ponsel.'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VoiceLabPage())),
        ),
        _Header('Privasi'),
        const ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('Data tersimpan di ponsel ini'),
          subtitle: Text(
            'Audio tidak disimpan, hanya tulisan. Saat saran AI dipakai, potongan percakapan dikirim ke layanan AI untuk diproses.',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Lihat lagi pengenalan aplikasi'),
          onTap: () => Navigator.of(context).pushNamed(V5Routes.onboarding),
        ),
      ]),
    );
  }
}

/// Download / status of the on-device Gemma model. Takes effect for new
/// conversations (the AI backend is chosen when a session starts).
class _LocalModelTile extends StatelessWidget {
  const _LocalModelTile();

  @override
  Widget build(BuildContext context) {
    final g = LocalGemma.instance;
    return ValueListenableBuilder<LocalGemmaStatus>(
      valueListenable: g.status,
      builder: (context, s, _) => switch (s) {
        LocalGemmaStatus.unsupported => const ListTile(
            leading: Icon(Icons.memory),
            title: Text('AI di ponsel'),
            subtitle: Text('Hanya tersedia di Android.'),
          ),
        LocalGemmaStatus.absent || LocalGemmaStatus.error => ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Unduh AI di ponsel (Gemma)'),
            subtitle: Text(
              s == LocalGemmaStatus.error
                  ? 'Gagal: ${g.lastError ?? 'tidak diketahui'}. Ketuk untuk coba lagi.'
                  : 'Saran AI jalan tanpa internet dan percakapan tidak keluar dari ponsel. '
                      'Ukuran ${LocalGemma.sizeLabel}, sebaiknya pakai Wi-Fi.',
            ),
            onTap: g.download,
          ),
        LocalGemmaStatus.downloading => ValueListenableBuilder<int>(
            valueListenable: g.progress,
            builder: (_, p, _) => ListTile(
              leading: const Icon(Icons.downloading),
              title: Text('Mengunduh AI… $p%'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: V5Space.xs),
                child: LinearProgressIndicator(value: p / 100),
              ),
            ),
          ),
        LocalGemmaStatus.loading => const ListTile(
            leading: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            title: Text('Menyiapkan AI di ponsel…'),
          ),
        LocalGemmaStatus.ready => ListTile(
            leading: const Icon(Icons.check_circle_outline, color: V5Colors.success),
            title: const Text('AI di ponsel aktif'),
            subtitle: const Text('Dipakai untuk obrolan baru. Tahan untuk menghapus model.'),
            onLongPress: g.delete,
          ),
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(V5Space.lg, V5Space.lg, V5Space.lg, V5Space.xs),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 13, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: V5Colors.muted)),
      );
}
