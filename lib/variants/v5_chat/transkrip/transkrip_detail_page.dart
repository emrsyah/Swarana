import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/session.dart';
import '../../../core/services/llm_service.dart';
import '../../../core/services/services.dart';
import '../../../variant/variant.dart';
import '../copy.dart';
import '../design/tokens.dart';
import '../widgets/text_size_slider.dart';

/// Saved transcript (design: "Homepage - Umum - Kata*" frames).
///
/// REVIEW: one Asli | Sederhana toggle replaces the "Versi Asli" pill plus the
/// "Ringkasan transkrip" button; text is left-aligned; "Tanya kata" is a
/// persistent mode instead of a hidden long-press.
class TranskripDetailPage extends StatefulWidget {
  const TranskripDetailPage({super.key, required this.transcript});
  final TranscriptSession transcript;

  @override
  State<TranskripDetailPage> createState() => _TranskripDetailPageState();
}

class _TranskripDetailPageState extends State<TranskripDetailPage> {
  bool _simple = false;
  bool _loadingSimple = false;
  bool _simpleFailed = false;
  bool _askMode = false;
  bool _tipShown = false;
  String? _word;
  String? _answer;
  bool _explaining = false;
  final List<TapGestureRecognizer> _recognizers = [];

  TranscriptSession get t => widget.transcript;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prefs = Services.of(context).settings.prefs;
    if (!_tipShown && prefs.getBool('tipAskWord') != true) {
      _tipShown = true;
      prefs.setBool('tipAskWord', true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          duration: Duration(seconds: 6),
          content: Text('Ingin tahu arti suatu kata? Nyalakan "Tanya kata", lalu ketuk katanya.'),
        ));
      });
    }
  }

  Future<void> _toggleSimple(bool simple) async {
    setState(() => _simple = simple);
    if (!simple || t.simplified != null) return;
    final s = Services.of(context);
    AppHandle.of(context).ux.track('simplify_used', {'context': 'transkrip'});
    setState(() {
      _loadingSimple = true;
      _simpleFailed = false;
    });
    try {
      t.simplified = await s.llm.simplify(t.text);
      await s.storage.saveTranscript(t);
    } on LlmException {
      _simpleFailed = true;
    }
    if (mounted) setState(() => _loadingSimple = false);
  }

  Future<void> _explain(String word) async {
    final s = Services.of(context);
    AppHandle.of(context).ux.track('explain_used', {'word': word});
    setState(() {
      _word = word;
      _answer = null;
      _explaining = true;
    });
    String? r;
    try {
      r = await s.llm.explainWord(word, t.text);
    } on LlmException {
      r = null;
    }
    if (!mounted || _word != word) return;
    setState(() {
      _answer = r ?? 'Penjelasan tidak tersedia. Periksa internet.';
      _explaining = false;
    });
  }

  /// Builds the text with every word tappable while "Tanya kata" is on.
  TextSpan _spans(String text, TextStyle style) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    if (!_askMode) return TextSpan(text: text, style: style);
    final parts = RegExp(r'(\s+)|([^\s]+)').allMatches(text);
    return TextSpan(style: style, children: [
      for (final m in parts)
        if (m.group(1) != null)
          TextSpan(text: m.group(1))
        else
          () {
            final raw = m.group(2)!;
            final clean = raw.replaceAll(RegExp(r'^[^\wÀ-ÿ@-]+|[^\wÀ-ÿ-]+$'), '');
            final r = TapGestureRecognizer()..onTap = () => _explain(clean);
            _recognizers.add(r);
            return TextSpan(
              text: raw,
              recognizer: r,
              style: clean == _word ? const TextStyle(backgroundColor: V5Colors.highlight) : null,
            );
          }(),
    ]);
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    final tt = Theme.of(context).textTheme;
    final date = DateFormat("d MMM yyyy, HH.mm", 'id_ID').format(t.createdAt);
    final minutes = (t.duration.inSeconds / 60).ceil();
    return Scaffold(
      appBar: AppBar(title: const Text('Detail transkrip')),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(V5Space.xl), children: [
            Text(t.title, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('$date · $minutes menit · Tersimpan', style: tt.bodySmall),
            const SizedBox(height: V5Space.lg),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text(Copy.asli)),
                ButtonSegment(value: true, icon: Icon(Icons.auto_awesome, size: 16), label: Text(Copy.sederhana)),
              ],
              selected: {_simple},
              showSelectedIcon: false,
              onSelectionChanged: (v) => _toggleSimple(v.first),
            ),
            const SizedBox(height: V5Space.lg),
            ValueListenableBuilder<double>(
              valueListenable: s.settings.textScale,
              builder: (_, scale, _) {
                final style = TextStyle(fontSize: 18 * scale, height: 1.6, color: V5Colors.ink, fontFamily: 'Inter');
                if (_simple && _loadingSimple) {
                  return const Row(children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: V5Space.md),
                    Text('Menyederhanakan…'),
                  ]);
                }
                if (_simple && _simpleFailed) {
                  return Row(children: [
                    const Expanded(child: Text('Versi sederhana tidak tersedia. Periksa internet.')),
                    TextButton(onPressed: () => _toggleSimple(true), child: const Text('Coba lagi')),
                  ]);
                }
                final text = _simple ? (t.simplified ?? '') : t.text;
                return Text.rich(_spans(text, style), textAlign: TextAlign.start);
              },
            ),
          ]),
        ),
        if (_word != null)
          Container(
            margin: const EdgeInsets.fromLTRB(V5Space.lg, 0, V5Space.lg, V5Space.sm),
            padding: const EdgeInsets.fromLTRB(V5Space.lg, V5Space.md, V5Space.xs, V5Space.md),
            decoration: BoxDecoration(
              color: V5Colors.aiTint,
              borderRadius: BorderRadius.circular(V5Radius.card),
              boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_word!, style: tt.titleSmall?.copyWith(color: V5Colors.primary)),
                  const SizedBox(height: 4),
                  _explaining ? const LinearProgressIndicator() : Text(_answer ?? '', style: tt.bodyLarge),
                ]),
              ),
              IconButton(onPressed: () => setState(() => _word = null), tooltip: 'Tutup', icon: const Icon(Icons.close)),
            ]),
          ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(V5Space.lg, V5Space.sm, V5Space.lg, V5Space.sm),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: V5Colors.border))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _askMode,
                secondary: const Icon(Icons.touch_app_outlined, color: V5Colors.primary),
                title: const Text('Tanya kata'),
                subtitle: const Text('Ketuk kata untuk melihat artinya'),
                onChanged: (v) => setState(() {
                  _askMode = v;
                  if (!v) _word = null;
                }),
              ),
              TextSizeSlider(value: s.settings.textScale),
            ]),
          ),
        ),
      ]),
    );
  }
}
