import 'package:flutter/material.dart';

import '../../../core/settings.dart';
import '../design/tokens.dart';

/// One reading-size setting shared by Obrolan, Transkrip and Pengaturan.
/// REVIEW: snaps to 4 steps and shows the current value (Figma had neither).
class TextSizeSlider extends StatelessWidget {
  const TextSizeSlider({super.key, required this.value});
  final ValueNotifier<double> value;

  static const _labels = ['Normal', 'Besar', 'Lebih besar', 'Sangat besar'];

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: value,
        builder: (_, v, _) {
          final steps = AppSettings.textScaleSteps;
          var i = steps.indexWhere((s) => (s - v).abs() < 0.01);
          if (i < 0) i = 0;
          return Row(children: [
            const Text('Aa', style: TextStyle(fontSize: 14)),
            Expanded(
              child: Slider(
                value: i.toDouble(),
                max: steps.length - 1.0,
                divisions: steps.length - 1,
                label: _labels[i],
                semanticFormatterCallback: (d) => 'Ukuran teks ${_labels[d.round()]}',
                onChanged: (d) => value.value = steps[d.round()],
              ),
            ),
            const Text('Aa', style: TextStyle(fontSize: 24)),
            const SizedBox(width: V5Space.sm),
            SizedBox(width: 92, child: Text(_labels[i], style: const TextStyle(fontSize: 13, color: V5Colors.muted))),
          ]);
        },
      );
}
