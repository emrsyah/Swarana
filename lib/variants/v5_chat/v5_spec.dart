import 'package:flutter/material.dart';

import '../../core/models/session.dart';
import '../../variant/variant.dart';
import 'design/theme.dart';
import 'obrolan/obrolan_page.dart';
import 'v5_routes.dart';

/// Iteration-5 chat app.
class V5Spec implements VariantSpec {
  @override
  final ThemeData theme = buildV5Theme();

  @override
  Widget home({required bool study}) => const ObrolanPage();

  @override
  Map<String, WidgetBuilder> get routes => {
        V5Routes.obrolan: (ctx) => ObrolanPage(resume: ModalRoute.of(ctx)?.settings.arguments as ChatSession?),
      };
}
