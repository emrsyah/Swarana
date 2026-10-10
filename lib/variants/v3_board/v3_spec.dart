import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

import '../../variant/variant.dart';
import 'core/services/v3_backend.dart';
import 'core/widgets/main_wrapper.dart';
import 'features/transkrip/presentation/pages/transkrip_page.dart';

/// Iteration-3 board app, the control condition. Theme copied exactly from
/// the iteration-3 main.dart so it looks as participants saw it then.
class V3Spec implements VariantSpec {
  @override
  final ThemeData theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: HexColor('#3C37AF')),
    scaffoldBackgroundColor: Colors.white,
    useMaterial3: true,
    fontFamily: 'PlusJakartaSans',
  );

  @override
  Widget home({required bool study}) => const V3Bindings(child: MainWrapper());

  @override
  Map<String, WidgetBuilder> get routes => {
        '/v3/transkrip': (_) => const V3Bindings(child: TranskripPage()),
      };
}
