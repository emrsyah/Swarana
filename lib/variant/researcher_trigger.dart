import 'dart:async';

import 'package:flutter/material.dart';

import 'variant.dart';

/// Hidden researcher entry: hold [child] for 2 seconds. Disabled while a
/// study task is running so participants can't open it by accident.
class ResearcherTrigger extends StatefulWidget {
  const ResearcherTrigger({super.key, required this.child});
  final Widget child;

  @override
  State<ResearcherTrigger> createState() => _ResearcherTriggerState();
}

class _ResearcherTriggerState extends State<ResearcherTrigger> {
  Timer? _hold;

  void _down(PointerDownEvent _) {
    if (AppHandle.read(context).ux.inStudy) return;
    _hold = Timer(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pushNamed('/researcher');
    });
  }

  void _cancel([PointerEvent? _]) => _hold?.cancel();

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: _down,
        onPointerUp: _cancel,
        onPointerCancel: _cancel,
        onPointerMove: (e) {
          if (e.delta.distance > 8) _cancel();
        },
        child: widget.child,
      );
}
