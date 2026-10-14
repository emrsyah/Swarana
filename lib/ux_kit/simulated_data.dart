import 'questionnaires.dart';

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
