import 'package:flutter/material.dart';

/// SUS items, Indonesian adaptation (Sharfina & Santoso, 2016).
const susItems = [
  'Saya berpikir akan menggunakan sistem ini lagi.',
  'Saya merasa sistem ini rumit untuk digunakan.',
  'Saya merasa sistem ini mudah digunakan.',
  'Saya membutuhkan bantuan dari orang lain atau teknisi dalam menggunakan sistem ini.',
  'Saya merasa fitur-fitur sistem ini berjalan dengan semestinya.',
  'Saya merasa ada banyak hal yang tidak konsisten (tidak serasi) pada sistem ini.',
  'Saya merasa orang lain akan memahami cara menggunakan sistem ini dengan cepat.',
  'Saya merasa sistem ini membingungkan.',
  'Saya merasa tidak ada hambatan dalam menggunakan sistem ini.',
  'Saya perlu membiasakan diri terlebih dahulu sebelum menggunakan sistem ini.',
];

/// Standard SUS: odd items (a-1), even items (5-a), sum × 2.5.
int susScore(List<int> answers) {
  assert(answers.length == 10);
  var sum = 0;
  for (var i = 0; i < 10; i++) {
    sum += i.isEven ? answers[i] - 1 : 5 - answers[i];
  }
  return (sum * 2.5).round();
}

/// NASA-TLX raw (unweighted). Performance: 0 = sempurna, 100 = gagal.
const tlxItems = [
  ('mental', 'Kebutuhan mental', 'Seberapa banyak berpikir dan mengingat yang dibutuhkan?'),
  ('physical', 'Kebutuhan fisik', 'Seberapa banyak aktivitas fisik yang dibutuhkan?'),
  ('temporal', 'Tekanan waktu', 'Seberapa terburu-buru kamu merasa?'),
  ('performance', 'Performa', 'Seberapa gagal kamu menyelesaikan tugas? (0 = sangat berhasil)'),
  ('effort', 'Usaha', 'Seberapa keras kamu harus berusaha?'),
  ('frustration', 'Frustrasi', 'Seberapa kesal, stres, atau terganggu kamu?'),
];

double tlxRaw(Map<String, int> values) =>
    values.values.fold<int>(0, (a, b) => a + b) / values.length;

// ---------------------------------------------------------------------------
// Widgets: one question per screen, large targets, progress.
// ---------------------------------------------------------------------------

class SusForm extends StatefulWidget {
  const SusForm({super.key, required this.variantLabel, required this.onDone});
  final String variantLabel;
  final void Function(List<int> answers, int score) onDone;

  @override
  State<SusForm> createState() => _SusFormState();
}

class _SusFormState extends State<SusForm> {
  final _answers = List<int?>.filled(10, null);
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final picked = _answers[_i];
    return _QuestionShell(
      header: 'Kuesioner SUS · ${widget.variantLabel}',
      progress: '${_i + 1}/10',
      question: susItems[_i],
      body: Column(children: [
        Row(children: [
          for (var v = 1; v <= 5; v++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _ScaleButton(
                  label: '$v',
                  selected: picked == v,
                  onTap: () => setState(() => _answers[_i] = v),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Sangat tidak setuju', style: t.bodySmall),
          Text('Sangat setuju', style: t.bodySmall),
        ]),
      ]),
      onBack: _i == 0 ? null : () => setState(() => _i--),
      onNext: picked == null
          ? null
          : () {
              if (_i < 9) return setState(() => _i++);
              final a = _answers.cast<int>();
              widget.onDone(a, susScore(a));
            },
      nextLabel: _i < 9 ? 'Lanjut' : 'Selesai',
    );
  }
}

class TlxForm extends StatefulWidget {
  const TlxForm({super.key, required this.variantLabel, required this.onDone});
  final String variantLabel;
  final void Function(Map<String, int> values, double raw) onDone;

  @override
  State<TlxForm> createState() => _TlxFormState();
}

class _TlxFormState extends State<TlxForm> {
  final _values = <String, int>{};
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final (key, title, question) = tlxItems[_i];
    final v = _values[key];
    final t = Theme.of(context).textTheme;
    return _QuestionShell(
      header: 'NASA-TLX · ${widget.variantLabel}',
      progress: '${_i + 1}/6',
      question: '$title\n$question',
      body: Column(children: [
        Text(v == null ? 'Geser untuk menjawab' : '$v', style: t.headlineMedium),
        // No value label: the harness sits above the Navigator's overlay.
        Slider(
          value: (v ?? 50).toDouble(),
          max: 100,
          divisions: 20,
          onChanged: (x) => setState(() => _values[key] = x.round()),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(key == 'performance' ? 'Sangat berhasil' : 'Sangat rendah', style: t.bodySmall),
          Text(key == 'performance' ? 'Gagal' : 'Sangat tinggi', style: t.bodySmall),
        ]),
      ]),
      onBack: _i == 0 ? null : () => setState(() => _i--),
      onNext: v == null
          ? null
          : () {
              if (_i < tlxItems.length - 1) return setState(() => _i++);
              widget.onDone(Map.of(_values), tlxRaw(_values));
            },
      nextLabel: _i < tlxItems.length - 1 ? 'Lanjut' : 'Selesai',
    );
  }
}

/// Single Ease Question, 1–7.
class SeqForm extends StatelessWidget {
  const SeqForm({super.key, required this.onDone});
  final void Function(int) onDone;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Seberapa mudah tugas tadi?', style: t.titleLarge, textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text('1 = sangat sulit, 7 = sangat mudah', style: t.bodyMedium),
      const SizedBox(height: 20),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
        for (var i = 1; i <= 7; i++)
          SizedBox(
            width: 56,
            height: 56,
            child: _ScaleButton(label: '$i', selected: false, onTap: () => onDone(i)),
          ),
      ]),
    ]);
  }
}

class _ScaleButton extends StatelessWidget {
  const _ScaleButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 56,
      child: selected
          ? FilledButton(onPressed: onTap, child: Text(label, style: const TextStyle(fontSize: 20)))
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: cs.onSurface),
              child: Text(label, style: const TextStyle(fontSize: 20)),
            ),
    );
  }
}

class _QuestionShell extends StatelessWidget {
  const _QuestionShell({
    required this.header,
    required this.progress,
    required this.question,
    required this.body,
    required this.onNext,
    required this.nextLabel,
    this.onBack,
  });

  final String header;
  final String progress;
  final String question;
  final Widget body;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: Text(header, style: t.labelLarge)),
          Text(progress, style: t.labelLarge),
        ]),
        const SizedBox(height: 16),
        Text(question, style: t.titleMedium?.copyWith(height: 1.4)),
        const SizedBox(height: 24),
        body,
        const SizedBox(height: 24),
        Row(children: [
          if (onBack != null)
            TextButton(onPressed: onBack, child: const Text('Kembali')),
          const Spacer(),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
            child: Text(nextLabel),
          ),
        ]),
      ],
    );
  }
}
