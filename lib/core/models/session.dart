import 'message.dart';

class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    List<Speaker>? speakers,
    List<ChatMessage>? messages,
    this.demo = false,
  })  : speakers = speakers ?? [],
        messages = messages ?? [];

  final String id;
  String title;
  final DateTime createdAt;
  final List<Speaker> speakers;
  final List<ChatMessage> messages;
  final bool demo;

  /// Partner speakers only (excludes the user).
  int get partnerCount => speakers.where((s) => !s.isMe).length;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'speakers': speakers.map((s) => s.toJson()).toList(),
        'messages': messages.map((m) => m.toJson()).toList(),
        if (demo) 'demo': true,
      };

  factory ChatSession.fromJson(Map<String, Object?> j) => ChatSession(
        id: j['id'] as String,
        title: j['title'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        speakers: (j['speakers'] as List)
            .map((e) => Speaker.fromJson((e as Map).cast()))
            .toList(),
        messages: (j['messages'] as List)
            .map((e) => ChatMessage.fromJson((e as Map).cast()))
            .toList(),
        demo: j['demo'] == true,
      );
}

class TranscriptSession {
  TranscriptSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.duration,
    required this.text,
    this.simplified,
  });

  final String id;
  String title;
  final DateTime createdAt;
  final Duration duration;
  final String text;
  String? simplified;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'durationMs': duration.inMilliseconds,
        'text': text,
        if (simplified != null) 'simplified': simplified,
      };

  factory TranscriptSession.fromJson(Map<String, Object?> j) =>
      TranscriptSession(
        id: j['id'] as String,
        title: j['title'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        duration: Duration(milliseconds: (j['durationMs'] as num).toInt()),
        text: j['text'] as String,
        simplified: j['simplified'] as String?,
      );
}
