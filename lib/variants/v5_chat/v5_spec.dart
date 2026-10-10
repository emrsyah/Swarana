import 'package:flutter/material.dart';

import '../../variant/variant.dart';

/// Iteration-5 chat app. Filled in by the v5 chunks.
class V5Spec implements VariantSpec {
  @override
  final ThemeData theme = ThemeData(useMaterial3: true);

  @override
  Widget home({required bool study}) => const Scaffold(body: Center(child: Text('v5')));

  @override
  Map<String, WidgetBuilder> get routes => const {};
}
