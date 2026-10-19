import 'package:flutter/widgets.dart';

import '../../../../core/models/message.dart';
import '../../../../core/services/services.dart';
import '../../../../variant/variant.dart';
import '../../../../ux_kit/ux_controller.dart';

/// Bridge from the ported v3 code (which uses singletons) to the shared
/// services of the current app tree. Only one variant tree exists at a time.
class V3Backend {
  static late Services services;
  static late UxController ux;

  /// Call when the user "speaks" something in v3. Feeds the tracker and lets a
  /// scripted partner continue.
  static void sent(String text, MessageSource source) {
    final c = Composition();
    switch (source) {
      case MessageSource.board:
        c.board = text.length;
      case MessageSource.suggestion:
        c.suggestion = text.length;
      default:
        c.typed = text.length;
    }
    ux.messageSent(text, c);
    services.stt.userReplied();
  }
}

/// Placed at the root of the v3 tree to bind [V3Backend] to it.
class V3Bindings extends StatelessWidget {
  const V3Bindings({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    V3Backend.services = Services.of(context);
    V3Backend.ux = AppHandle.of(context).ux;
    return child;
  }
}
