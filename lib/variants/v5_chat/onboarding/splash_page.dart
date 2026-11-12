import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/services.dart';
import '../design/tokens.dart';
import '../v5_routes.dart';

/// Splash (Figma "Splash screen"): logo, "New Swarana", italic tagline on blue.
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
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: V5Colors.primary,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: V5Space.xl),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Image.asset('assets/v5/logo.png', height: 40, semanticLabel: 'Logo Swarana'),
                const SizedBox(width: V5Space.md),
                const Text('New Swarana', style: TextStyle(color: Colors.white, fontSize: 28)),
              ]),
              const SizedBox(height: V5Space.md),
              const Text(
                'Setiap Kata Bermakna, Setiap Suara Berharga',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ]),
          ),
        ),
      );
}
