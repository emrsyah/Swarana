import 'package:flutter/widgets.dart';

import 'ux_controller.dart';

/// Builds the screen path. Requires named routes (RouteSettings.name).
class UxNavigatorObserver extends NavigatorObserver {
  UxNavigatorObserver(this.ux);
  final UxController ux;

  void _report(Route<dynamic>? route, {bool pop = false}) {
    final name = route?.settings.name;
    if (name != null) ux.onRoute(name, pop: pop);
  }

  @override
  void didPush(Route route, Route? previousRoute) => _report(route);
  @override
  void didPop(Route route, Route? previousRoute) => _report(previousRoute, pop: true);
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) => _report(newRoute);
}
