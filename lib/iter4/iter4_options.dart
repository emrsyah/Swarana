import 'package:flutter/material.dart';

import '../variants/v5_chat/design/tokens.dart';
import 'iter4_controller.dart';
import 'iter4_session_page.dart' show TapTracker;

/// The three Iteration-4 interface options, built after the "Hasil Rapid AI
/// Prototyping" frames. Partner speech is scripted (simulated captions).

const _chips = ['Terima kasih', 'Maaf', 'Bisa ulangi?', 'Saya tidak paham'];

Widget buildOption(Iter4Controller c) => switch (c.option) {
      I4Option.chat => _ChatOption(c: c),
      I4Option.dual => _DualOption(c: c),
      I4Option.audio => _AudioOption(c: c),
    };

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _ListeningStatus extends StatelessWidget {
  const _ListeningStatus();
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 14,
          height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: V5Colors.recording.withValues(alpha: 0.2)),
          child: Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: V5Colors.recording)),
        ),
        const SizedBox(width: 8),
        const Text('Sedang mendengarkan...', style: TextStyle(fontSize: 14, color: V5Colors.muted)),
      ]);
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: onTap,
        radius: 26,
        child: Container(
          width: 46,
          height: 46,
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: V5Colors.border)),
          child: Icon(icon, color: V5Colors.ink),
        ),
      );
}

/// Full transcript sheet behind the history icon (Opsi 1 and 3 have one).
void _showHistory(BuildContext context, Iter4Controller c) {
  c.track('history_opened');
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // The sheet is its own route, so it needs its own tap tracking.
    builder: (ctx) => TapTracker(
      onTap: (p) => c.onTap(p, MediaQuery.sizeOf(ctx)),
      child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (_, scroll) => ListView(controller: scroll, padding: const EdgeInsets.all(20), children: [
        const Text('Riwayat obrolan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        for (final m in c.messages)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('${m.me ? 'Saya' : 'Kasir'}: ${m.text}', style: const TextStyle(fontSize: 16, height: 1.4)),
          ),
      ]),
    ),
    ),
  );
}

class _Composer extends StatefulWidget {
  const _Composer({required this.onSend, this.autofocus = false});
  final ValueChanged<String> onSend;
  final bool autofocus;
  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _t = TextEditingController();

  void _send() {
    final v = _t.text.trim();
    if (v.isEmpty) return;
    _t.clear();
    widget.onSend(v);
    setState(() {});
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _t,
              autofocus: widget.autofocus,
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(hintText: 'Tulis pesan di sini'),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: _t.text.trim().isEmpty ? V5Colors.primary.withValues(alpha: 0.45) : V5Colors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _send,
              child: const SizedBox(width: 54, height: 54, child: Icon(Icons.send_rounded, color: Colors.white)),
            ),
          ),
        ]),
      );
}

class _Chips extends StatelessWidget {
  const _Chips({required this.c});
  final Iter4Controller c;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          children: [
            for (final s in _chips)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: OutlinedButton(
                  onPressed: () => c.send(s),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: V5Colors.ink,
                    side: const BorderSide(color: V5Colors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(s),
                ),
              ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Opsi 1 · Normal Chat Based
// ---------------------------------------------------------------------------

class _ChatOption extends StatelessWidget {
  const _ChatOption({required this.c});
  final Iter4Controller c;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: V5Colors.page,
        body: SafeArea(
          child: Column(children: [
            Container(
              color: V5Colors.surface,
              padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
              child: Row(children: [
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Obrolan Pribadi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
                    SizedBox(height: 6),
                    _ListeningStatus(),
                  ]),
                ),
                _RoundIcon(icon: Icons.history, onTap: () => _showHistory(context, c)),
                _RoundIcon(icon: Icons.menu, onTap: () => c.error('menu')),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                reverse: true,
                padding: const EdgeInsets.all(16),
                children: [
                  for (final m in c.messages.reversed)
                    Align(
                      alignment: m.me ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: m.me ? V5Colors.myBubble : V5Colors.surface,
                          border: Border.all(color: m.me ? V5Colors.myBubble : V5Colors.border),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (!m.me)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.mic_none, size: 14, color: V5Colors.muted),
                                SizedBox(width: 4),
                                Text('mendengar', style: TextStyle(fontSize: 12, color: V5Colors.muted)),
                              ]),
                            ),
                          Text(m.text,
                              style: TextStyle(
                                  fontSize: 17,
                                  height: 1.4,
                                  fontStyle: m.partial || m.garbled ? FontStyle.italic : null,
                                  color: m.partial ? V5Colors.muted : V5Colors.ink)),
                          if (m.me) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => c.replay(m),
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                              icon: Icon(m.spoken ? Icons.volume_up : Icons.graphic_eq, size: 18),
                              label: Text(m.spoken ? 'Putar ulang' : 'Dibunyikan…'),
                            ),
                          ],
                        ]),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            _Chips(c: c),
            _Composer(onSend: c.send),
          ]),
        ),
      );
}

// ---------------------------------------------------------------------------
// Opsi 2 · Dual View (top half faces the partner, upside down)
// ---------------------------------------------------------------------------

class _DualOption extends StatelessWidget {
  const _DualOption({required this.c});
  final Iter4Controller c;

  @override
  Widget build(BuildContext context) {
    final mine = c.lastMine;
    final theirs = c.lastPartner;
    return Scaffold(
      backgroundColor: V5Colors.surface,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: RotatedBox(
              quarterTurns: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Expanded(
                    child: SingleChildScrollView(
                      reverse: true,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(mine?.text ?? '',
                            textAlign: TextAlign.right, style: const TextStyle(fontSize: 26, height: 1.3)),
                      ),
                    ),
                  ),
                  // The partner's hold-to-talk button (participant tapping it = error).
                  GestureDetector(
                    onTap: () => c.error('tombol_lawan_bicara'),
                    child: Container(
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: V5Colors.primary, borderRadius: BorderRadius.circular(32)),
                      child: const Text('Tahan untuk berbicara',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: V5Colors.border),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              // Scrolls instead of overflowing when the keyboard shrinks this half.
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Kasir berkata', style: TextStyle(fontSize: 13, color: V5Colors.muted)),
                const SizedBox(height: 6),
                Text(theirs?.text ?? '',
                    style: TextStyle(
                        fontSize: 26,
                        height: 1.3,
                        fontStyle: theirs?.garbled == true ? FontStyle.italic : null)),
                if (mine != null)
                  TextButton.icon(
                    onPressed: () => c.replay(mine),
                    icon: Icon(mine.spoken ? Icons.volume_up : Icons.graphic_eq),
                    label: Text(mine.spoken ? 'Bunyikan lagi' : 'Dibunyikan…'),
                  ),
                ]),
              ),
            ),
          ),
          _Chips(c: c),
          _Composer(onSend: c.send),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Opsi 3 · Audio First (live caption, reply on demand, no quick replies)
// ---------------------------------------------------------------------------

class _AudioOption extends StatefulWidget {
  const _AudioOption({required this.c});
  final Iter4Controller c;
  @override
  State<_AudioOption> createState() => _AudioOptionState();
}

class _AudioOptionState extends State<_AudioOption> {
  bool _replying = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final recent = c.messages.length > 4 ? c.messages.sublist(c.messages.length - 4) : c.messages;
    return Scaffold(
      backgroundColor: V5Colors.page,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
            child: Row(children: [
              const Expanded(child: _ListeningStatus()),
              _RoundIcon(icon: Icons.history, onTap: () => _showHistory(context, c)),
              _RoundIcon(icon: Icons.menu, onTap: () => c.error('menu')),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < recent.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      recent[i].me ? recent[i].text : '“${recent[i].text}”',
                      style: TextStyle(
                        fontSize: i == recent.length - 1 ? 26 : 16,
                        height: 1.35,
                        fontWeight: recent[i].me ? FontWeight.w600 : FontWeight.w400,
                        color: i == recent.length - 1 ? V5Colors.ink : V5Colors.muted,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                const Text('• • • • • • • • • • • • •',
                    style: TextStyle(color: V5Colors.primary, fontSize: 18, letterSpacing: 2)),
              ]),
            ),
          ),
          const Divider(height: 1),
          if (_replying)
            _Composer(
              autofocus: true,
              onSend: (t) {
                c.send(t);
                setState(() => _replying = false);
              },
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(children: [
                InkResponse(
                  onTap: () => c.error('hentikan'),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: V5Colors.error),
                    child: const Icon(Icons.stop_rounded, color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Hentikan', style: TextStyle(color: V5Colors.muted, fontSize: 16)),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {
                    c.track('reply_opened');
                    setState(() => _replying = true);
                  },
                  icon: const Icon(Icons.keyboard_alt_outlined),
                  label: const Text('Balas Pesan'),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}
