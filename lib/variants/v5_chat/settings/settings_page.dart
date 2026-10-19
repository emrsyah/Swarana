import 'package:flutter/material.dart';

import '../../../core/services/services.dart';
import '../copy.dart';
import '../design/tokens.dart';
import '../drawer.dart';
import '../v5_routes.dart';
import '../widgets/text_size_slider.dart';

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
