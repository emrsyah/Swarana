import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/message.dart';
import '../models/session.dart';

/// JSON-file persistence for sessions, study results and raw tracking events.
class Storage {
  late Directory _root;
  late Directory _study;

  Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    _root = Directory('${docs.path}/swarana')..createSync(recursive: true);
    _study = Directory('${_root.path}/study')..createSync(recursive: true);
    if (!_file('chats.json').existsSync()) await _writeList('chats.json', _demoChats());
  }

  File _file(String name) => File('${_root.path}/$name');

  Future<List<Map<String, Object?>>> _readList(String name) async {
    final f = _file(name);
    if (!f.existsSync()) return [];
    try {
      return (jsonDecode(await f.readAsString()) as List)
          .map((e) => (e as Map).cast<String, Object?>())
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> _writeList(String name, List<Map<String, Object?>> list) =>
      _file(name).writeAsString(jsonEncode(list));

  Future<void> _upsert(String name, Map<String, Object?> item) async {
    final list = await _readList(name);
    final i = list.indexWhere((e) => e['id'] == item['id']);
    i >= 0 ? list[i] = item : list.insert(0, item);
    await _writeList(name, list);
  }

  Future<void> _remove(String name, String id) async {
    final list = await _readList(name)..removeWhere((e) => e['id'] == id);
    await _writeList(name, list);
  }

  // ---------------- Chats & transcripts ----------------

  Future<List<ChatSession>> chats({bool includeDemo = true}) async =>
      (await _readList('chats.json'))
          .map(ChatSession.fromJson)
          .where((c) => includeDemo || !c.demo)
          .toList();

  Future<void> saveChat(ChatSession s) => _upsert('chats.json', s.toJson());
  Future<void> deleteChat(String id) => _remove('chats.json', id);

  Future<List<TranscriptSession>> transcripts() async =>
      (await _readList('transcripts.json'))
          .map(TranscriptSession.fromJson)
          .toList();

  Future<void> saveTranscript(TranscriptSession t) =>
      _upsert('transcripts.json', t.toJson());
  Future<void> deleteTranscript(String id) => _remove('transcripts.json', id);

  // ---------------- Study ----------------

  Future<void> appendEvent(String participantId, Map<String, Object?> e) =>
      File('${_study.path}/$participantId.events.jsonl')
          .writeAsString('${jsonEncode(e)}\n', mode: FileMode.append);

  Future<void> saveStudy(String participantId, Map<String, Object?> json) =>
      File('${_study.path}/$participantId.json').writeAsString(jsonEncode(json));

  Future<List<Map<String, Object?>>> studies() async {
    final out = <Map<String, Object?>>[];
    for (final f in _study.listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      try {
        out.add((jsonDecode(await f.readAsString()) as Map).cast());
      } on FormatException {
        // Skip a half-written file rather than failing the whole dashboard.
      }
    }
    return out;
  }

  Future<void> deleteStudy(String participantId) async {
    for (final ext in ['json', 'events.jsonl']) {
      final f = File('${_study.path}/$participantId.$ext');
      if (f.existsSync()) await f.delete();
    }
  }

  /// One JSON file with every study and its raw events, ready to share.
  Future<File> exportAll() async {
    final studies = await this.studies();
    final events = <String, List<Object?>>{};
    for (final f in _study.listSync().whereType<File>()) {
      if (!f.path.endsWith('.events.jsonl')) continue;
      final pid = f.uri.pathSegments.last.replaceAll('.events.jsonl', '');
      events[pid] = (await f.readAsLines())
          .where((l) => l.trim().isNotEmpty)
          .map(jsonDecode)
          .toList();
    }
    final tmp = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    return File('${tmp.path}/swarana-study-$stamp.json').writeAsString(
        const JsonEncoder.withIndent('  ')
            .convert({'exportedAt': stamp, 'studies': studies, 'events': events}));
  }

  // ---------------- Demo seed ----------------

  static List<Map<String, Object?>> _demoChats() {
    final now = DateTime.now();
    ChatSession chat(String id, String title, int daysAgo, List<(String, String)> lines,
        List<String> names) {
      final speakers = [
        Speaker(id: Speaker.meId, name: 'Saya', colorIndex: 0),
        for (var i = 0; i < names.length; i++)
          Speaker(id: 's${i + 1}', name: names[i], colorIndex: i),
      ];
      final t = now.subtract(Duration(days: daysAgo, hours: 2));
      return ChatSession(
        id: id,
        title: title,
        createdAt: t,
        speakers: speakers,
        demo: true,
        messages: [
          for (var i = 0; i < lines.length; i++)
            ChatMessage(
              id: '$id-$i',
              speakerId: lines[i].$1,
              text: lines[i].$2,
              time: t.add(Duration(seconds: 20 * i)),
              source: lines[i].$1 == Speaker.meId
                  ? MessageSource.keyboard
                  : MessageSource.stt,
            ),
        ],
      );
    }

    return [
      chat('demo-1', 'Rencana rapat', 0, [
        ('me', 'Halo, saya tuli. Rapat dimulai jam berapa, ya?'),
        ('s1', 'Kurang lebih setengah jam lagi, menunggu yang lain datang.'),
        ('me', 'Baiklah, kita tunggu saja.'),
        ('s2', 'Maaf terlambat. Kita fokus dulu ke progres desain dan hasil riset minggu lalu.'),
      ], ['Pembicara 1', 'Pembicara 2']),
      chat('demo-2', 'Beli obat di apotek', 3, [
        ('s1', 'Selamat sore, ada resep dari dokter?'),
        ('me', 'Ada, ini resepnya.'),
        ('s1', 'Obatnya diminum tiga kali sehari sesudah makan, ya.'),
      ], ['Apoteker']),
    ].map((c) => c.toJson()).toList();
  }
}
