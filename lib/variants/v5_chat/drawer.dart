import 'package:flutter/material.dart';

import '../../core/models/session.dart';
import '../../core/services/services.dart';
import 'copy.dart';
import 'design/tokens.dart';
import 'v5_routes.dart';

/// Side menu (design/v5/screens/5Sidebar.png).
///
/// REVIEW: added the app identity, highlight of the current screen, and a
/// "Lihat semua" link; "Akhiri obrolan" is a destructive outline button shown
/// only while a chat is open (Figma: always a primary button).
class V5Drawer extends StatelessWidget {
  const V5Drawer({super.key, required this.current, this.onEndChat});

  final String current;
  final VoidCallback? onEndChat;

  void _go(BuildContext context, String route) {
    Navigator.pop(context);
    if (route == current) return;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final storage = Services.of(context).storage;
    return Drawer(
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(V5Space.xl, V5Space.lg, V5Space.lg, V5Space.md),
            child: Row(children: [
              const Icon(Icons.record_voice_over_rounded, color: V5Colors.primary),
              const SizedBox(width: V5Space.sm),
              Text('Swarana', style: t.titleMedium),
            ]),
          ),
          _section('Pilihan'),
          for (final (route, icon, label) in [
            (V5Routes.obrolan, Icons.forum_outlined, Copy.obrolan),
            (V5Routes.transkrip, Icons.subtitles_outlined, Copy.transkrip),
            (V5Routes.riwayat, Icons.history, Copy.riwayat),
            (V5Routes.settings, Icons.settings_outlined, Copy.pengaturan),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: V5Space.md),
              child: ListTile(
                minTileHeight: 52,
                selected: route == current,
                selectedTileColor: const Color(0xFFF1F2F4),
                selectedColor: V5Colors.ink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(V5Radius.pill)),
                leading: Icon(icon),
                title: Text(label, style: TextStyle(fontWeight: route == current ? FontWeight.w600 : FontWeight.w400)),
                onTap: () => _go(context, route),
              ),
            ),
          const SizedBox(height: V5Space.lg),
          _section('Obrolan terkini'),
          Expanded(
            child: FutureBuilder<List<ChatSession>>(
              future: storage.chats(),
              builder: (context, snap) {
                final items = (snap.data ?? const []).take(3).toList();
                if (snap.hasData && items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: V5Space.xl),
                    child: Text('Belum ada obrolan tersimpan.', style: TextStyle(color: V5Colors.muted)),
                  );
                }
                return ListView(padding: EdgeInsets.zero, children: [
                  for (final c in items)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: V5Space.xl),
                      title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).pushNamed(V5Routes.chatDetail, arguments: c);
                      },
                    ),
                  if (items.isNotEmpty)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: V5Space.xl),
                      title: const Text('Lihat semua', style: TextStyle(color: V5Colors.primary, fontWeight: FontWeight.w500)),
                      onTap: () => _go(context, V5Routes.riwayat),
                    ),
                ]);
              },
            ),
          ),
          if (onEndChat != null)
            Padding(
              padding: const EdgeInsets.all(V5Space.xl),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onEndChat!();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: V5Colors.error,
                  side: const BorderSide(color: V5Colors.error),
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text(Copy.akhiriObrolan),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(V5Space.xl, V5Space.sm, V5Space.xl, V5Space.sm),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 13, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: V5Colors.muted)),
      );
}
