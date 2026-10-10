import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/message.dart';
import '../../../core/models/session.dart';
import '../../../core/services/llm_service.dart';
import '../../../core/services/services.dart';
import '../design/tokens.dart';
import '../v5_routes.dart';
import '../widgets/bubble.dart';
import '../widgets/dialogs.dart';
import '../widgets/message_menu.dart';

/// Read-only saved chat (design: "Riwayat - Detail riwayat obrolan grup").
/// Same bubbles and long-press menu as the live chat.
class ObrolanDetailPage extends StatefulWidget {
  const ObrolanDetailPage({super.key, required this.session});
  final ChatSession session;

  @override
  State<ObrolanDetailPage> createState() => _ObrolanDetailPageState();
}

class _ObrolanDetailPageState extends State<ObrolanDetailPage> {
  ChatSession get c => widget.session;

  Speaker _speaker(String id) => c.speakers.firstWhere(
        (s) => s.id == id,
        orElse: () => Speaker(id: id, name: 'Pembicara', colorIndex: 0),
      );

  Future<void> _simplify(ChatMessage m) async {
    final s = Services.of(context);
    try {
      m.simplified = await s.llm.simplify(m.text);
      await s.storage.saveChat(c);
      if (mounted) setState(() {});
    } on LlmException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyederhanakan. Periksa internet.')));
      }
    }
  }

  Future<void> _rename(Speaker sp) async {
    final n = await showTextDialog(context, title: 'Ganti nama pembicara', initial: sp.name);
    if (n == null || n.trim().isEmpty || !mounted) return;
    sp.name = n.trim();
    await Services.of(context).storage.saveChat(c);
    if (mounted) setState(() {});
  }

  void _menu(ChatMessage m) {
    final s = Services.of(context);
    showMessageMenu(context, message: m, onAction: (a) {
      switch (a) {
        case MessageAction.speak:
          s.tts.speak(m.id, m.text);
        case MessageAction.simplify:
          _simplify(m);
        case MessageAction.explain:
          showExplainSheet(context, text: m.text, explain: (w) async {
            try {
              return await s.llm.explainWord(w, m.text);
            } on LlmException {
              return null;
            }
          });
        default:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scale = Services.of(context).settings.textScale.value;
    final group = c.partnerCount > 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Detail obrolan')),
      body: ListView(padding: const EdgeInsets.only(bottom: V5Space.xl), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(V5Space.xl, V5Space.lg, V5Space.xl, V5Space.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.title, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${DateFormat('d MMM yyyy, HH.mm', 'id_ID').format(c.createdAt)} · ${c.partnerCount} orang bicara',
                style: tt.bodySmall),
          ]),
        ),
        for (final m in c.messages)
          MessageBubble(
            message: m,
            speaker: _speaker(m.speakerId),
            showName: group && !m.isMe,
            textScale: scale,
            onMenu: () => _menu(m),
            onSpeak: () => Services.of(context).tts.speak(m.id, m.text),
            onRename: () => _rename(_speaker(m.speakerId)),
            onSimplify: () => _simplify(m),
          ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(V5Space.lg),
          // REVIEW: primary button (Figma: weak outline) — it is the main action.
          child: FilledButton(
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(V5Routes.obrolan, (_) => false, arguments: c),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Lanjutkan obrolan'),
          ),
        ),
      ),
    );
  }
}
