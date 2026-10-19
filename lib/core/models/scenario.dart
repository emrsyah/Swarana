import 'dart:convert';

/// One step of a role-play script: a partner line, or a wait for the user.
class ScenarioTurn {
  ScenarioTurn({
    this.speaker,
    this.text,
    this.suggest = const [],
    this.waitForUser = false,
  });

  final String? speaker;
  final String? text;
  final List<String> suggest;
  final bool waitForUser;

  factory ScenarioTurn.fromJson(Map<String, Object?> j) => ScenarioTurn(
        speaker: j['speaker'] as String?,
        text: j['text'] as String?,
        suggest: (j['suggest'] as List?)?.cast<String>() ?? const [],
        waitForUser: j['waitForUser'] == true,
      );
}

/// A role-play scenario with two parallel forms (A/B) to avoid learning effects.
class Scenario {
  Scenario({
    required this.id,
    required this.title,
    required this.complexity,
    required this.speakers,
    required this.forms,
  });

  final String id;
  final String title;
  final String complexity;

  /// Speaker id -> display name, e.g. {'s1': 'Penjual'}.
  final Map<String, String> speakers;
  final Map<String, ScenarioForm> forms;

  factory Scenario.fromJson(Map<String, Object?> j) => Scenario(
        id: j['id'] as String,
        title: j['title'] as String,
        complexity: j['complexity'] as String,
        speakers: (j['speakers'] as Map).cast<String, String>(),
        forms: (j['forms'] as Map).map((k, v) => MapEntry(
            k as String, ScenarioForm.fromJson((v as Map).cast()))),
      );

  static Scenario parse(String source) =>
      Scenario.fromJson(jsonDecode(source) as Map<String, Object?>);
}

class ScenarioForm {
  ScenarioForm({required this.instruction, required this.turns, this.glossary = const {}});

  /// Shown to the Deaf participant in the briefing.
  final String instruction;
  final List<ScenarioTurn> turns;

  /// Canned explanations for "Tanya arti" in scripted mode.
  final Map<String, String> glossary;

  int get interactionCount => turns.where((t) => t.waitForUser).length;

  factory ScenarioForm.fromJson(Map<String, Object?> j) => ScenarioForm(
        instruction: j['instruction'] as String,
        turns: (j['turns'] as List)
            .map((e) => ScenarioTurn.fromJson((e as Map).cast()))
            .toList(),
        glossary: (j['glossary'] as Map?)?.cast<String, String>() ?? const {},
      );
}
