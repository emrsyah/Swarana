/// Where the text of a sent message came from. Used for the input-mix metric.
enum MessageSource { keyboard, suggestion, board, quickPhrase, stt }

enum TtsState { idle, speaking, done, failed, muted }

class Speaker {
  Speaker({required this.id, required this.name, required this.colorIndex});

  static const meId = 'me';

  final String id;
  String name;
  final int colorIndex;

  bool get isMe => id == meId;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'color': colorIndex};

  factory Speaker.fromJson(Map<String, Object?> j) => Speaker(
        id: j['id'] as String,
        name: j['name'] as String,
        colorIndex: (j['color'] as num?)?.toInt() ?? 0,
      );
}

/// Characters contributed by each input source to one sent message.
class Composition {
  Composition({this.typed = 0, this.board = 0, this.suggestion = 0});

  int typed;
  int board;
  int suggestion;

  bool get isEmpty => typed + board + suggestion == 0;

  /// The report's bucket: whichever source contributed the most characters.
  MessageSource get majority {
    if (board >= typed && board >= suggestion && board > 0) {
      return MessageSource.board;
    }
    if (suggestion >= typed && suggestion > 0) return MessageSource.suggestion;
    return MessageSource.keyboard;
  }

  Map<String, int> toJson() =>
      {'typed': typed, 'board': board, 'suggestion': suggestion};
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.speakerId,
    required this.text,
    required this.time,
    this.source = MessageSource.stt,
    this.partial = false,
    this.lowConfidence = false,
    this.simplified,
  });

  final String id;
  final String speakerId;
  String text;
  final DateTime time;
  final MessageSource source;

  /// Live STT bubble still forming.
  bool partial;

  /// Whole-utterance confidence below threshold; the UI offers a correction.
  bool lowConfidence;

  String? simplified;
  TtsState tts = TtsState.idle;

  bool get isMe => speakerId == Speaker.meId;

  Map<String, Object?> toJson() => {
        'id': id,
        'speaker': speakerId,
        'text': text,
        'time': time.toIso8601String(),
        'source': source.name,
        if (simplified != null) 'simplified': simplified,
      };

  factory ChatMessage.fromJson(Map<String, Object?> j) => ChatMessage(
        id: j['id'] as String,
        speakerId: j['speaker'] as String,
        text: j['text'] as String,
        time: DateTime.parse(j['time'] as String),
        source: MessageSource.values.byName(j['source'] as String? ?? 'stt'),
        simplified: j['simplified'] as String?,
      );
}
