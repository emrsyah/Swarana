import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/session.dart';
import '../../../core/services/services.dart';
import '../../../variant/variant.dart';
import '../copy.dart';
import '../design/tokens.dart';
import '../drawer.dart';
import '../v5_routes.dart';
import '../widgets/dialogs.dart';

/// Saved chats and transcripts. REVIEW: added search, plain wording
/// ("3 orang bicara"), transcript duration, 48 px "⋯" targets, empty states.
class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  final _scaffold = GlobalKey<ScaffoldState>();
  bool _transcripts = false;
  String _q = '';
  late Future<(List<ChatSession>, List<TranscriptSession>)> _data;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _reload();
    }
  }

  void _reload() {
    final st = Services.read(context).storage;
    final study = AppHandle.of(context).ux.inStudy;
    _data = Future.wait([st.chats(includeDemo: !study), st.transcripts()])
        .then((r) => (r[0] as List<ChatSession>, r[1] as List<TranscriptSession>));
    setState(() {});
  }

  String _when(DateTime d) {
    final now = DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    final time = DateFormat('HH.mm').format(d);
    if (day == today) return 'Hari ini, $time';
    if (day == today.subtract(const Duration(days: 1))) return 'Kemarin, $time';
    return '${DateFormat('d MMM', 'id_ID').format(d)}, $time';
  }

  bool _match(String title, String body) {
    if (_q.isEmpty) return true;
    final q = _q.toLowerCase();
    return title.toLowerCase().contains(q) || body.toLowerCase().contains(q);
  }

  Future<void> _more({ChatSession? chat, TranscriptSession? tr}) async {
    final st = Services.read(context).storage;
    final title = chat?.title ?? tr!.title;
    final a = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Ubah judul'), onTap: () => Navigator.pop(ctx, 'rename')),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: V5Colors.error),
            title: const Text(Copy.hapus, style: TextStyle(color: V5Colors.error)),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ]),
      ),
    );
    if (!mounted || a == null) return;
    if (a == 'rename') {
      final n = await showTextDialog(context, title: 'Ubah judul', initial: title, label: 'Judul');
      if (n == null || n.trim().isEmpty) return;
      if (chat != null) {
        chat.title = n.trim();
        await st.saveChat(chat);
      } else {
        tr!.title = n.trim();
        await st.saveTranscript(tr);
      }
    } else if (await confirmDelete(context, '"$title"')) {
      chat != null ? await st.deleteChat(chat.id) : await st.deleteTranscript(tr!.id);
    }
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      key: _scaffold,
      endDrawer: const V5Drawer(current: V5Routes.riwayat),
      appBar: AppBar(
        title: const Text(Copy.riwayat),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: V5Space.md),
            child: IconButton.outlined(
              tooltip: 'Menu',
              onPressed: () => _scaffold.currentState!.openEndDrawer(),
              icon: const Icon(Icons.menu),
            ),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(V5Space.lg, V5Space.sm, V5Space.lg, V5Space.sm),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text(Copy.obrolan)),
              ButtonSegment(value: true, label: Text(Copy.transkrip)),
            ],
            selected: {_transcripts},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _transcripts = v.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: V5Space.lg),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.trim()),
            decoration: const InputDecoration(hintText: 'Cari judul atau isi', prefixIcon: Icon(Icons.search)),
          ),
        ),
        const SizedBox(height: V5Space.sm),
        const Divider(),
        Expanded(
          child: FutureBuilder<(List<ChatSession>, List<TranscriptSession>)>(
            future: _data,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final (chats, trs) = snap.data!;
              final rows = _transcripts
                  ? [
                      for (final t in trs.where((t) => _match(t.title, t.text)))
                        _Row(
                          title: t.title,
                          meta: '${_when(t.createdAt)} · ${(t.duration.inSeconds / 60).ceil()} menit',
                          onTap: () => Navigator.of(context).pushNamed(V5Routes.transkripDetail, arguments: t).then((_) => _reload()),
                          onMore: () => _more(tr: t),
                        ),
                    ]
                  : [
                      for (final c in chats.where((c) => _match(c.title, c.messages.map((m) => m.text).join(' '))))
                        _Row(
                          title: c.title,
                          meta: '${_when(c.createdAt)} · ${c.partnerCount} orang bicara',
                          onTap: () => Navigator.of(context).pushNamed(V5Routes.chatDetail, arguments: c).then((_) => _reload()),
                          onMore: () => _more(chat: c),
                        ),
                    ];
              if (rows.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(V5Space.xl),
                    child: Text(
                      _q.isNotEmpty
                          ? 'Tidak ada hasil untuk "$_q".'
                          : _transcripts
                              ? 'Belum ada transkrip. Transkrip yang kamu simpan akan muncul di sini.'
                              : 'Belum ada obrolan. Obrolan yang kamu simpan akan muncul di sini.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: V5Colors.muted),
                    ),
                  ),
                );
              }
              return ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(indent: V5Space.lg, endIndent: V5Space.lg),
                itemBuilder: (_, i) => rows[i],
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.meta, required this.onTap, required this.onMore});
  final String title;
  final String meta;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.only(left: V5Space.lg, right: V5Space.xs),
        minTileHeight: 72,
        title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        subtitle: Text(meta, style: const TextStyle(color: V5Colors.muted)),
        onTap: onTap,
        trailing: IconButton(tooltip: 'Pilihan lain', onPressed: onMore, icon: const Icon(Icons.more_horiz)),
      );
}
