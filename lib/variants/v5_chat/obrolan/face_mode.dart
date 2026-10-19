import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// Face-to-face mode: the top half is rotated 180° so the person across the
/// table can read the user's last message (or the intro card) in large text.
class FaceModePage extends StatelessWidget {
  const FaceModePage({super.key, required this.forPartner, this.partnerLast});

  /// What the partner should read (the user's last message or intro card).
  final String forPartner;

  /// Last thing the partner said, shown to the user on the bottom half.
  final String? partnerLast;

  static const introCard =
      'Halo, saya tuli.\nSaya memakai aplikasi ini untuk mengobrol. '
      'Silakan bicara pelan ke arah ponsel, ucapan Anda akan muncul sebagai tulisan.';

  @override
  Widget build(BuildContext context) {
    const big = TextStyle(fontSize: 34, height: 1.3, fontWeight: FontWeight.w600, color: Colors.white);
    return Scaffold(
      backgroundColor: V5Colors.primary,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: SafeArea(
          child: Column(children: [
            Expanded(
              child: RotatedBox(
                quarterTurns: 2,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(V5Space.xl),
                    child: Text(forPartner, style: big, textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
            Container(height: 2, color: Colors.white24),
            Expanded(
              child: Container(
                color: V5Colors.surface,
                width: double.infinity,
                padding: const EdgeInsets.all(V5Space.xl),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (partnerLast != null) ...[
                    const Text('Lawan bicara terakhir berkata:', style: TextStyle(color: V5Colors.muted)),
                    const SizedBox(height: V5Space.sm),
                    Text(partnerLast!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, height: 1.4)),
                    const SizedBox(height: V5Space.xl),
                  ],
                  const Text('Ketuk di mana saja untuk kembali', style: TextStyle(color: V5Colors.muted)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
