import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/message.dart';
import '../copy.dart';
import '../design/tokens.dart';

/// Tracks how much of the draft came from typing, the board or a suggestion.
class ComposerController extends TextEditingController {
  int _board = 0;
  int _suggestion = 0;

  void insert(String text, MessageSource source) {
    final t = text.trim();
    final sep = this.text.isEmpty || this.text.endsWith(' ') ? '' : ' ';
    value = TextEditingValue(
      text: '${this.text}$sep$t',
      selection: TextSelection.collapsed(offset: this.text.length + sep.length + t.length),
    );
    if (source == MessageSource.board) _board += t.length;
    if (source == MessageSource.suggestion) _suggestion += t.length;
  }

  Composition takeComposition() {
    final len = text.trim().length;
    final b = _board.clamp(0, len);
    final s = _suggestion.clamp(0, len - b);
    _board = 0;
    _suggestion = 0;
    return Composition(board: b, suggestion: s, typed: len - b - s);
  }
}

/// REVIEW: Figma's composer had no board entry; the IA lists "template board
/// visual". A leading grid button opens it, like WhatsApp's attach button.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onOpenBoard,
    required this.onChanged,
    this.onTypingLong,
  });

  final ComposerController controller;
  final void Function(String text, Composition c) onSend;
  final VoidCallback onOpenBoard;
  final ValueChanged<String> onChanged;

  /// Called once when the user has been typing for a while (offers the
  /// "please wait, I'm typing" phrase). Null in study mode.
  final VoidCallback? onTypingLong;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  Timer? _typing;
  bool _offered = false;

  void _changed(String v) {
    widget.onChanged(v);
    if (v.isEmpty) {
      _typing?.cancel();
      _offered = false;
    } else if (_typing == null || !_typing!.isActive) {
      if (!_offered && widget.onTypingLong != null) {
        _typing = Timer(const Duration(seconds: 4), () {
          _offered = true;
          widget.onTypingLong!();
        });
      }
    }
    setState(() {});
  }

  void _send() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    final c = widget.controller.takeComposition();
    widget.controller.clear();
    _typing?.cancel();
    _offered = false;
    widget.onSend(text, c);
    setState(() {});
  }

  @override
  void dispose() {
    _typing?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = widget.controller.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(V5Space.sm, V5Space.sm, V5Space.md, V5Space.sm),
      decoration: const BoxDecoration(
        color: V5Colors.page,
        border: Border(top: BorderSide(color: V5Colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          IconButton(
            onPressed: widget.onOpenBoard,
            tooltip: 'Papan kata dan kalimat',
            iconSize: 26,
            style: IconButton.styleFrom(minimumSize: const Size(minTouch, minTouch)),
            icon: const Icon(Icons.grid_view_rounded, color: V5Colors.primary),
          ),
          Expanded(
            child: TextField(onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(), 
              controller: widget.controller,
              onChanged: _changed,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 17, height: 1.35),
              decoration: const InputDecoration(hintText: Copy.tulisPesan),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: V5Space.sm),
          Semantics(
            button: true,
            label: 'Kirim dan bunyikan',
            child: Material(
              color: canSend ? V5Colors.primary : V5Colors.primary.withValues(alpha: 0.4),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: canSend ? _send : null,
                child: const SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
