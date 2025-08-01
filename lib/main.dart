import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:hexcolor/hexcolor.dart';
import 'core/widgets/main_wrapper.dart';
import 'features/transkrip/presentation/pages/transkrip_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Portal(
      child: MaterialApp(
        title: 'Swarana',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: HexColor('#3C37AF')),
          scaffoldBackgroundColor: Colors.white, // Global background color
          useMaterial3: true,
          fontFamily: 'PlusJakartaSans',
        ),
        home: const MainWrapper(),
        routes: {
          '/transkrip': (context) => const TranskripPage(),
        },
      ),
    );
  }
}
