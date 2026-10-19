import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/services.dart';
import '../design/tokens.dart';
import '../v5_routes.dart';

/// Splash (design/v5/screens/5Splash screen.png). Tagline is upright and
/// medium weight for contrast on blue (Figma: thin italic).
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _t;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t ??= Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final onboarded = Services.of(context).settings.onboarded.value;
      Navigator.of(context).pushReplacementNamed(onboarded ? V5Routes.obrolan : V5Routes.onboarding);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: V5Colors.primary,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.record_voice_over_rounded, color: Colors.white, size: 40),
              SizedBox(width: V5Space.md),
              Text('Swarana', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w500)),
            ]),
            SizedBox(height: V5Space.md),
            Text('Setiap kata bermakna, setiap suara berharga',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
          ]),
        ),
      );
}
