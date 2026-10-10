import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/message.dart';
import '../../../core/models/session.dart';
import '../../../core/services/alerts.dart';
import '../../../core/services/llm_service.dart';
import '../../../core/services/services.dart';
import '../../../core/services/stt_service.dart';
import '../../../ux_kit/ux_controller.dart';

enum SuggestState { hidden, loading, ready, error }

/// State of one Obrolan conversation: messages, speakers, live STT, TTS
/// status, AI suggestions and alerts. One screen for 1:1 and group talk.
class ObrolanController extends ChangeNotifier {
  ObrolanController(this.s, this.ux, {ChatSession? resume}) {
    session = resume ??
        ChatSession(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: '',
          createdAt: DateTime.now(),
          speakers: [Speaker(id: Speaker.meId, name: 'Saya', colorIndex: 0)],
        );
    _subs = [
      s.stt.events.listen(_onStt),
      s.tts.updates.listen(_onTts),
      s.alerts.stream.listen(_onAlert),
    ];
    s.stt.status.addListener(notifyListeners);
    s.settings.separateSpeakers.addListener(notifyListeners);
  }

  final Services s;
  final UxController ux;
  late final ChatSession session;
  late final List<StreamSubscription<Object?>> _subs;

  final Map<String, ChatMessage> _partial = {};
  int _ids = 0;
  bool _disposed = false;

  List<String> suggestions = const [];
  SuggestState suggestState = SuggestState.hidden;
  Timer? _suggestDebounce;
  int _suggestSeq = 0;

  AlertKind? alert;
  Timer? _alertTimer;

  List<ChatMessage> get messages => session.messages;
  SttStatus get sttStatus => s.stt.status.value;
  ValueListenable<double> get level => s.stt.level;
  bool get isGroup => session.partnerCount > 1;
  bool get isEmpty => messages.isEmpty;

  /// True while a study task runs: v5-only extras are hidden (see R15).
  bool get studyMode => ux.inStudy;

  Speaker speaker(String id) => session.speakers.firstWhere(
        (sp) => sp.id == id,
        orElse: () => _addSpeaker(id),
      );

  Speaker _addSpeaker(String id) {
    final n = session.partnerCount + 1;
    final sp = Speaker(id: id, name: _knownNames[id] ?? 'Pembicara $n', colorIndex: n - 1);
    session.speakers.add(sp);
    return sp;
  }

  final Map<String, String> _knownNames = {};

  /// Scripted scenarios supply role names (e.g. "Petugas bank"), applied
  /// when that speaker first talks so group mode starts only when needed.
  void seedSpeakerNames(Map<String, String> names) => _knownNames.addAll(names);

  // ---------------- Listening ----------------

  Future<void> startListening() async {
    final ok = await s.stt.init();
    if (!ok) {
      s.alerts.raise(AlertKind.micDenied);
      return;
    }
    await s.stt.start();
    ux.track('listen_started');
  }

  Future<void> togglePause() async {
    if (sttStatus == SttStatus.listening) {
      await s.stt.pause();
      ux.track('listen_paused');
    } else {
      await s.stt.start();
      ux.track('listen_resumed');
    }
  }

  void otherPersonSpeaking() {
    s.stt.nextSpeaker();
    ux.track('speaker_switched_manual');
  }

  String _partnerId(String raw) => s.settings.separateSpeakers.value ? raw : 's1';

  void _onStt(SttEvent e) {
    final sid = _partnerId(e.speakerId);
    speaker(sid); // registers new speakers
    final existing = _partial[sid];
    if (existing != null) {
      existing.text = e.text;
      existing.partial = !e.isFinal;
      existing.lowConfidence = e.lowConfidence;
    } else {
      final m = ChatMessage(
        id: 'm${_ids++}',
        speakerId: sid,
        text: e.text,
        time: DateTime.now(),
        partial: !e.isFinal,
        lowConfidence: e.lowConfidence,
      );
      session.messages.add(m);
      if (!e.isFinal) _partial[sid] = m;
    }
    if (e.isFinal) {
      _partial.remove(sid);
      s.haptics.tick();
      _requestSuggestions();
    }
    notifyListeners();
  }

  /// Fix a misheard partner message.
  void correct(ChatMessage m, String text) {
    m
      ..text = text
      ..lowConfidence = false
      ..simplified = null;
    ux.track('stt_corrected');
    notifyListeners();
  }

  // ---------------- Sending ----------------

  Future<void> send(String text, Composition c, {MessageSource? source}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final src = source ?? c.majority;
    final m = ChatMessage(
      id: 'm${_ids++}',
      speakerId: Speaker.meId,
      text: t,
      time: DateTime.now(),
      source: src,
    );
    session.messages.add(m);
    ux.messageSent(t, c, override: source);
    if (src != MessageSource.quickPhrase) s.stt.userReplied();
    suggestions = const [];
    suggestState = SuggestState.hidden;
    notifyListeners();
    await speak(m);
  }

  Future<void> speak(ChatMessage m) async {
    m.tts = TtsState.speaking;
    notifyListeners();
    await s.tts.speak(m.id, m.text);
  }

  void _onTts(({String id, TtsState state}) u) {
    final m = messages.where((x) => x.id == u.id).firstOrNull;
    if (m == null) return;
    m.tts = u.state;
    notifyListeners();
  }

  // ---------------- AI ----------------

  /// Debounced suggestions; [draft] continues what the user is typing.
  void _requestSuggestions({String draft = ''}) {
    _suggestDebounce?.cancel();
    _suggestDebounce = Timer(Duration(milliseconds: draft.isEmpty ? 150 : 600), () => _fetchSuggestions(draft));
  }

  void onDraftChanged(String draft) {
    if (draft.trim().length >= 3) _requestSuggestions(draft: draft.trim());
  }

  Future<void> _fetchSuggestions(String draft) async {
    if (!messages.any((m) => !m.isMe)) return;
    final seq = ++_suggestSeq;
    suggestState = SuggestState.loading;
    notifyListeners();
    try {
      final r = await s.llm.suggestReplies(messages, {for (final sp in session.speakers) sp.id: sp}, draft: draft);
      if (seq != _suggestSeq || _disposed) return;
      suggestions = r;
      suggestState = r.isEmpty ? SuggestState.hidden : SuggestState.ready;
    } on LlmException {
      if (seq != _suggestSeq || _disposed) return;
      suggestState = SuggestState.error;
      s.alerts.raise(AlertKind.offline);
    }
    notifyListeners();
  }

  void retrySuggestions() => _fetchSuggestions('');

  void hideSuggestions() {
    suggestState = SuggestState.hidden;
    notifyListeners();
  }

  /// Returns null on failure (UI shows an error state).
  Future<String?> simplify(ChatMessage m) async {
    if (m.simplified != null) return m.simplified;
    ux.track('simplify_used', {'context': 'obrolan'});
    try {
      m.simplified = await s.llm.simplify(m.text);
      notifyListeners();
      return m.simplified;
    } on LlmException {
      s.alerts.raise(AlertKind.offline);
      return null;
    }
  }

  Future<String?> explain(String word, String context) async {
    ux.track('explain_used', {'word': word});
    try {
      return await s.llm.explainWord(word, context);
    } on LlmException {
      s.alerts.raise(AlertKind.offline);
      return null;
    }
  }

  // ---------------- Speakers, alerts, saving ----------------

  void renameSpeaker(String id, String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    speaker(id).name = n;
    ux.track('speaker_renamed');
    notifyListeners();
  }

  void _onAlert(AlertKind k) {
    alert = k;
    _alertTimer?.cancel();
    _alertTimer = Timer(const Duration(seconds: 8), dismissAlert);
    notifyListeners();
  }

  void dismissAlert() {
    alert = null;
    if (!_disposed) notifyListeners();
  }

  Future<String> suggestTitle() async {
    final text = messages.map((m) => m.text).join('\n');
    if (text.isEmpty) return 'Obrolan baru';
    try {
      return await s.llm.titleFor(text);
    } on LlmException {
      return 'Obrolan ${session.createdAt.day}/${session.createdAt.month}';
    }
  }

  Future<void> save(String title) async {
    session.title = title.trim().isEmpty ? 'Obrolan baru' : title.trim();
    session.messages.removeWhere((m) => m.partial);
    await s.storage.saveChat(session);
    ux.track('chat_saved');
  }

  @override
  void dispose() {
    _disposed = true;
    _suggestDebounce?.cancel();
    _alertTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    s.stt.status.removeListener(notifyListeners);
    s.settings.separateSpeakers.removeListener(notifyListeners);
    s.stt.stop();
    s.tts.stop();
    super.dispose();
  }
}
