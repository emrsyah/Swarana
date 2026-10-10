import 'package:flutter/material.dart';

import '../../variant/variant.dart';

/// Iteration-3 board app (control condition). Filled in by the v3 port.
class V3Spec implements VariantSpec {
  @override
  final ThemeData theme = ThemeData(useMaterial3: true);

  @override
  Widget home({required bool study}) => const Scaffold(body: Center(child: Text('v3')));

  @override
  Map<String, WidgetBuilder> get routes => const {};
}
