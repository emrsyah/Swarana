import 'dart:math';

import 'questionnaires.dart';

/// Hotspots (normalised 0–1 screen coordinates, measured from device
/// screenshots) and how often each is tapped per task.
typedef _Spot = ({double x, double y, int weight});

const _v3Board = <_Spot>[
  (x: 0.50, y: 0.17, weight: 4), // text field
  (x: 0.88, y: 0.17, weight: 5), // speak icon
  (x: 0.15, y: 0.25, weight: 2), (x: 0.40, y: 0.25, weight: 2), (x: 0.72, y: 0.25, weight: 1), // categories
  (x: 0.30, y: 0.33, weight: 2), (x: 0.70, y: 0.33, weight: 2), // Kata / Kalimat
  (x: 0.19, y: 0.45, weight: 3), (x: 0.40, y: 0.45, weight: 3), (x: 0.60, y: 0.45, weight: 2), (x: 0.81, y: 0.45, weight: 2),
  (x: 0.19, y: 0.605, weight: 2), (x: 0.40, y: 0.605, weight: 2), (x: 0.60, y: 0.605, weight: 1), (x: 0.81, y: 0.605, weight: 1),
  (x: 0.19, y: 0.76, weight: 1), (x: 0.40, y: 0.76, weight: 1), (x: 0.60, y: 0.76, weight: 1), (x: 0.81, y: 0.76, weight: 2),
  (x: 0.50, y: 0.90, weight: 6), // Dengar mic
];
const _v3Dengar = <_Spot>[
  (x: 0.29, y: 0.38, weight: 4), (x: 0.71, y: 0.38, weight: 3), (x: 0.29, y: 0.52, weight: 2), // suggestion cards
  (x: 0.88, y: 0.17, weight: 2), // keyboard toggle
  (x: 0.50, y: 0.81, weight: 5), // mic again
  (x: 0.88, y: 0.10, weight: 3), // close
];
const _v5Obrolan = <_Spot>[
  (x: 0.42, y: 0.94, weight: 6), // composer
  (x: 0.90, y: 0.94, weight: 6), // send
  (x: 0.46, y: 0.733, weight: 4), (x: 0.42, y: 0.80, weight: 3), (x: 0.45, y: 0.87, weight: 2), // suggestions
  (x: 0.08, y: 0.94, weight: 1), // board button
  (x: 0.79, y: 0.147, weight: 1), // Jeda / Lanjutkan
  (x: 0.38, y: 0.55, weight: 1), // partner bubble (long-press menu)
];

/// SIMULATED tap and rage-click events for P1–P5 (heatmap). Each event
/// carries `simulated: true`.
Map<String, List<Map<String, Object?>>> simulatedEvents() {
  final rnd = Random(42);
  const scenarios = ['warung', 'bank', 'cs'];
  const interactions = {'warung': 2, 'bank': 5, 'cs': 9};
  const orderV3First = {'P1': true, 'P2': false, 'P3': true, 'P4': false, 'P5': true};
  final start = DateTime(2026, 9, 22, 9);
  final out = <String, List<Map<String, Object?>>>{};

  _Spot pick(List<_Spot> spots) {
    final total = spots.fold<int>(0, (a, s) => a + s.weight);
    var r = rnd.nextInt(total);
    for (final s in spots) {
      if ((r -= s.weight) < 0) return s;
    }
    return spots.last;
  }

  double jitter(double v) => (v + (rnd.nextDouble() - 0.5) * 0.06).clamp(0.01, 0.99);

  var day = 0;
  orderV3First.forEach((pid, v3First) {
    final events = <Map<String, Object?>>[];
    var t = start.add(Duration(days: day++));
    for (final variant in v3First ? ['v3Board', 'v5Chat'] : ['v5Chat', 'v3Board']) {
      final v3 = variant == 'v3Board';
      for (final sc in scenarios) {
        // v3 needs ~3.2 taps per interaction (board hunting, mode switching),
        // v5 ~1.8 (type/suggest + send).
        final n = (interactions[sc]! * (v3 ? 3.2 : 1.8) + rnd.nextInt(4)).round();
        for (var i = 0; i < n; i++) {
          final dengar = v3 && rnd.nextDouble() < 0.35;
          final screen = v3 ? (dengar ? '/v3/dengar' : '/v3/board') : '/v5/obrolan';
          final s = pick(v3 ? (dengar ? _v3Dengar : _v3Board) : _v5Obrolan);
          t = t.add(Duration(milliseconds: 1500 + rnd.nextInt(4000)));
          final e = {
            'event': 'ux_tap',
            'at': t.toIso8601String(),
            'participant': pid,
            'variant': variant,
            'scenario': sc,
            'in_task': true,
            'simulated': true,
            'x': jitter(s.x),
            'y': jitter(s.y),
            'screen': screen,
          };
          events.add(e);
          // Occasional rage clicks: v3 on the speak icon / Dengar mic.
          if (v3 && (s.y > 0.85 || s.x > 0.85) && rnd.nextDouble() < 0.18) {
            events.add({...e, 'event': 'ux_rage_click'});
          } else if (!v3 && s.x > 0.85 && s.y > 0.9 && rnd.nextDouble() < 0.04) {
            events.add({...e, 'event': 'ux_rage_click'});
          }
        }
      }
    }
    out[pid] = events;
  });
  return out;
}

/// SIMULATED study data for the report ("Penjabaran Skor Iterasi 5", file
/// marked "simulasi"). Every record carries `simulated: true` and the results
/// page shows a "Data simulasi" banner, so it is never mistaken for a recorded
/// session. Numbers follow the report's tables:
///  - times per participant/scenario (means 43/36, 146/131, 198/127 s)
///  - chat-heavy success per interaction, Teman Tuli only (18/30 → 27/30)
///  - NASA-TLX raw per participant (means 51 → 37)
///  - SUS v5 for the 3 Teman Tuli (85, 87.5, 85 → 85.8)
///  - SEQ v5 for the 3 Teman Tuli (mean 6.2)
/// Input-mix counts are illustrative (v3 ≈ 84/11/5 % like iteration 3).
List<Map<String, Object?>> simulatedStudies() {
  const scenarios = ['warung', 'bank', 'cs'];

  // participant: (deaf, order v3 first?, times v3 [w,b,cs], times v5, tlx v3, tlx v5)
  final people = <String, (bool, bool, List<int>, List<int>, int, int)>{
    'P1': (true, true, [45, 150, 215], [38, 135, 135], 55, 40),
    'P2': (true, false, [40, 140, 190], [34, 126, 120], 48, 35),
    'P3': (true, true, [46, 155, 205], [37, 138, 130], 53, 38),
    'P4': (false, false, [42, 142, 185], [35, 128, 122], 50, 36),
    'P5': (false, true, [42, 143, 195], [36, 128, 128], 49, 36),
  };
  const csOk = {'P1': (6, 9), 'P2': (7, 10), 'P3': (5, 8)};
  const sus = {
    'P1': [5, 1, 4, 2, 4, 2, 5, 2, 4, 1],
    'P2': [5, 2, 4, 1, 5, 2, 4, 1, 5, 2],
    'P3': [4, 1, 5, 2, 4, 2, 5, 1, 4, 2],
  };
  // SEQ per scenario (report: Obrolan 2 orang / kelompok / Transkrip).
  const seq = {'P1': [7, 7, 6], 'P2': [6, 7, 5], 'P3': [6, 6, 6]};
  // Messages per scenario by source: keyboard, suggestion, board.
  const mixV3 = [(1, 0, 1), (5, 1, 0), (10, 1, 0)];
  const mixV5 = [(0, 1, 1), (4, 1, 0), (7, 5, 0)];

  /// Six TLX dimensions shaped like P1's v5 profile, shifted to the target mean.
  Map<String, int> tlx(int mean) {
    const base = [50, 10, 45, 35, 50, 50]; // mean 40
    final keys = tlxItems.map((t) => t.$1).toList();
    return {for (var i = 0; i < 6; i++) keys[i]: base[i] + (mean - 40)};
  }

  final start = DateTime(2026, 9, 22, 9);
  final out = <Map<String, Object?>>[];
  var n = 0;
  people.forEach((pid, p) {
    final (deaf, v3First, t3, t5, tlx3, tlx5) = p;
    final order = v3First ? ['v3Board', 'v5Chat'] : ['v5Chat', 'v3Board'];

    Map<String, Object?> block(String variant, int b) {
      final v3 = variant == 'v3Board';
      final times = v3 ? t3 : t5;
      final mix = v3 ? mixV3 : mixV5;
      final susAnswers = !v3 && deaf ? sus[pid] : null;
      return {
        'variant': variant,
        'tasks': [
          for (var i = 0; i < 3; i++)
            () {
              final cs = scenarios[i] == 'cs' && deaf;
              final ok = cs ? (v3 ? csOk[pid]!.$1 : csOk[pid]!.$2) : null;
              final (kb, sg, bd) = mix[i];
              return {
                'scenario': scenarios[i],
                'form': b == 0 ? 'A' : 'B',
                'variant': variant,
                'outcome': ok == null ? 'success' : (ok >= 8 ? 'success' : 'partial'),
                'success': ok == null || ok >= 8,
                'auto_detected': false,
                'duration_ms': times[i] * 1000,
                'waited_ms': 0,
                'block_index': b,
                'task_position': i,
                if (ok != null) 'ok_interactions': ok,
                if (ok != null) 'total_interactions': 10,
                'path': const <String>[],
                'taps': 0,
                'rage_clicks': 0,
                'input_mix': {
                  if (kb > 0) 'keyboard': kb,
                  if (sg > 0) 'suggestion': sg,
                  if (bd > 0) 'board': bd,
                },
                'messages': const <Object>[],
                'seq': !v3 && deaf ? seq[pid]![i] : null,
              };
            }(),
        ],
        'sus_answers': susAnswers,
        'sus': susAnswers == null ? null : susScore(susAnswers),
        'tlx': tlx(v3 ? tlx3 : tlx5),
        'tlx_raw': (v3 ? tlx3 : tlx5).toDouble(),
      };
    }

    out.add({
      'simulated': true,
      'participant_status': deaf ? 'Tuli' : 'Non-Tuli',
      'config': {
        'participant': pid,
        'order': order,
        'scenarios': scenarios,
        'scripted': false,
        'breakSeconds': 900,
        'timeLimitSeconds': 300,
      },
      'started_at': start.add(Duration(days: n++)).toIso8601String(),
      'finished': true,
      'aborted': false,
      'cursor': {'block': 1, 'task': 3, 'phase': 'done'},
      'blocks': [for (var b = 0; b < 2; b++) block(order[b], b)],
    });
  });
  return out;
}
