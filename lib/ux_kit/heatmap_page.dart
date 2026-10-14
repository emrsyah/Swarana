import 'package:flutter/material.dart';

import '../core/services/storage.dart';

/// Tap heatmap per variant and screen, from `ux_tap` / `ux_rage_click`
/// events (normalised x, y). Rage clicks are drawn as red rings.
class HeatmapPage extends StatefulWidget {
  const HeatmapPage({super.key, required this.storage});
  final Storage storage;

  @override
  State<HeatmapPage> createState() => _HeatmapPageState();
}

class _HeatmapPageState extends State<HeatmapPage> {
  late final Future<List<Map<String, Object?>>> _events = widget.storage.allEvents();
  String _variant = 'v3Board';
  String? _screen;

  /// Device screenshots used as the background for each tracked screen.
  static const _shots = {
    '/v3/board': 'assets/heatmap/v3_board.png',
    '/v3/dengar': 'assets/heatmap/v3_dengar.png',
    '/v5/obrolan': 'assets/heatmap/v5_obrolan.png',
  };

  static const _screenNames = {
    '/v3/board': 'v3 · Papan bicara',
    '/v3/dengar': 'v3 · Mode dengar',
    '/v5/obrolan': 'v5 · Obrolan',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Heatmap ketukan')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _events,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final all = snap.data!
              .where((e) => (e['event'] == 'ux_tap' || e['event'] == 'ux_rage_click') && e['x'] is num)
              .toList();
          final screens = all
              .where((e) => e['variant'] == _variant)
              .map((e) => e['screen'] as String? ?? '?')
              .toSet()
              .toList()
            ..sort();
          final screen = screens.contains(_screen) ? _screen : (screens.isEmpty ? null : screens.first);
          final shown = all.where((e) => e['variant'] == _variant && e['screen'] == screen).toList();
          final taps = shown.where((e) => e['event'] == 'ux_tap').toList();
          final rage = shown.where((e) => e['event'] == 'ux_rage_click').toList();
          final participants = shown.map((e) => e['participant']).toSet().length;
          final simulated = shown.any((e) => e['simulated'] == true);

          return ListView(padding: const EdgeInsets.all(16), children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'v3Board', label: Text('v3 Board')),
                ButtonSegment(value: 'v5Chat', label: Text('v5 Chat')),
              ],
              selected: {_variant},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                _variant = s.first;
                _screen = null;
              }),
            ),
            const SizedBox(height: 12),
            if (screens.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Belum ada data ketukan untuk versi ini.', textAlign: TextAlign.center),
              )
            else ...[
              Wrap(spacing: 8, children: [
                for (final s in screens)
                  ChoiceChip(
                    label: Text(_screenNames[s] ?? s),
                    selected: s == screen,
                    onSelected: (_) => setState(() => _screen = s),
                  ),
              ]),
              const SizedBox(height: 12),
              Text('${taps.length} ketukan · ${rage.length} rage click · $participants partisipan'
                  '${simulated ? ' · data simulasi' : ''}',
                  style: t.bodyMedium),
              const SizedBox(height: 12),
              // Sized so the whole phone screen fits without scrolling.
              Center(
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.58,
                  child: AspectRatio(
                  aspectRatio: 1080 / 2340,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(fit: StackFit.expand, children: [
                      // The real screen (screenshot from the device), slightly
                      // faded so the heat reads clearly on top.
                      if (_shots[screen] != null)
                        Opacity(opacity: 0.85, child: Image.asset(_shots[screen]!, fit: BoxFit.fill))
                      else
                        const ColoredBox(color: Color(0xFFF4F5F8)),
                      CustomPaint(painter: _HeatPainter(taps: taps, rage: rage)),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFD5D8E0), width: 2),
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ]),
                  ),
                ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 16, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 80, height: 10, decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0x330072B2), Color(0xFFE69F00), Color(0xFFD55E00)]),
                  )),
                  const SizedBox(width: 8),
                  const Text('sedikit → banyak ketukan'),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 14, height: 14, decoration: BoxDecoration(
                    shape: BoxShape.circle, border: Border.all(color: const Color(0xFFDC2626), width: 2))),
                  const SizedBox(width: 6),
                  const Text('rage click'),
                ]),
              ]),
            ],
          ]);
        },
      ),
    );
  }
}

class _HeatPainter extends CustomPainter {
  _HeatPainter({required this.taps, required this.rage});
  final List<Map<String, Object?>> taps;
  final List<Map<String, Object?>> rage;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width * 0.09;
    // Additive blobs: overlapping taps build up heat.
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final e in taps) {
      final o = Offset((e['x'] as num) * size.width, (e['y'] as num) * size.height);
      canvas.drawCircle(
        o,
        radius,
        Paint()
          ..shader = RadialGradient(colors: const [Color(0x70E5482B), Color(0x40F2A33A), Color(0x00F2A33A)])
              .createShader(Rect.fromCircle(center: o, radius: radius)),
      );
    }
    canvas.restore();
    for (final e in taps) {
      canvas.drawCircle(Offset((e['x'] as num) * size.width, (e['y'] as num) * size.height), 2,
          Paint()..color = const Color(0x99333333));
    }
    final ring = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final e in rage) {
      canvas.drawCircle(Offset((e['x'] as num) * size.width, (e['y'] as num) * size.height), size.width * 0.05, ring);
    }
  }

  @override
  bool shouldRepaint(_HeatPainter old) => old.taps != taps || old.rage != rage;
}
