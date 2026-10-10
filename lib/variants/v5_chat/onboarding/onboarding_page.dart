import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/services.dart';
import '../design/tokens.dart';
import '../v5_routes.dart';

/// First launch: microphone rationale, then a consent notice.
/// (No Figma yet; review: the app went straight to always-listening.)
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;
  bool _denied = false;

  Future<void> _askMic() async {
    final st = await Permission.microphone.request();
    if (!mounted) return;
    if (st.isGranted) {
      await Permission.speech.request();
      setState(() => _step = 1);
    } else {
      setState(() => _denied = true);
    }
  }

  void _finish() {
    Services.of(context).settings.onboarded.value = true;
    Navigator.of(context).pushNamedAndRemoveUntil(V5Routes.obrolan, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final (IconData icon, String title, String body, String cta, VoidCallback onTap) = switch ((_step, _denied)) {
      (0, false) => (
          Icons.mic_none_rounded,
          'Swarana perlu mikrofon',
          'Mikrofon dipakai untuk menuliskan ucapan orang di sekitarmu, supaya kamu bisa membacanya. '
              'Swarana hanya mendengar saat status "Mendengarkan" tampil di atas layar.',
          'Izinkan mikrofon',
          _askMic,
        ),
      (0, true) => (
          Icons.mic_off_rounded,
          'Mikrofon belum diizinkan',
          'Tanpa mikrofon, Swarana tidak bisa menuliskan ucapan lawan bicara. '
              'Kamu tetap bisa mengetik dan memakai papan. Buka pengaturan ponsel untuk mengizinkan.',
          'Buka pengaturan ponsel',
          () => openAppSettings(),
        ),
      _ => (
          Icons.handshake_outlined,
          'Beri tahu lawan bicara',
          'Sampaikan bahwa ucapannya akan ditulis oleh aplikasi. '
              'Audio tidak disimpan, hanya tulisan. Kamu bisa menekan "Jeda" kapan saja.',
          'Mulai',
          _finish,
        ),
    };
    return Scaffold(
      backgroundColor: V5Colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(V5Space.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              for (var i = 0; i < 2; i++)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: i == _step ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _step ? V5Colors.primary : V5Colors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ]),
            const Spacer(),
            Icon(icon, size: 72, color: V5Colors.primary),
            const SizedBox(height: V5Space.xl),
            Text(title, style: tt.headlineSmall),
            const SizedBox(height: V5Space.md),
            Text(body, style: tt.bodyLarge),
            const Spacer(flex: 2),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              child: Text(cta),
            ),
            if (_step == 0)
              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _step = 1;
                    _denied = false;
                  }),
                  child: const Text('Nanti saja'),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
