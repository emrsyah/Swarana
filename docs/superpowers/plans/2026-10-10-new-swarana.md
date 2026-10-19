# New Swarana Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One Flutter app with two runtime-switchable variants (v3 board baseline, v5 chat) plus a Maze-style test kit (tasks, tracking, SUS, NASA-TLX, export) to run the within-subject A/B study from the GEMASTIK report.

**Architecture:** `SwaranaApp` owns shared services (STT, TTS, LLM, haptics, storage, tracker) and a `VariantController`. It renders `MaterialApp(key: ValueKey(variant))` with that variant's theme, routes and home, so switching rebuilds the whole tree. Each variant lives in its own folder with its own design tokens and never imports the other. Services have Live and Scripted implementations so studies run deterministically and offline.

**Tech Stack:** Flutter 3.47 / Dart 3.13, `speech_to_text`, `flutter_tts`, `http` (OpenRouter chat completions, Gemini Flash), `vibration`, `volume_controller`, `shared_preferences`, `path_provider`, `share_plus`, `flutter_svg`, `iconsax_plus`, `intl`, `google_fonts` (Inter for v5). v3 keeps Plus Jakarta Sans bundled.

**Sources:**
- Report PDF in repo root (features, study design, metrics).
- `design/v5/screens/*.png` (19 screens) and IA diagram.
- v3 code: https://github.com/emrsyah/swarana (clone to `%TEMP%/swarana-v3`).
- `tracker/ux_task_kit.dart` (the tracker we upgrade).
- UX review findings (two expert reviews, summarized in chunk 6/7 requirements).

**Conventions:**
- Tests: only for pure logic that is easy to get wrong: SUS scoring, TLX scoring, rage-click/success detection, scripted scenario playback, OpenRouter response parsing. No widget tests.
- Verify each chunk with `flutter analyze` (0 errors) and `flutter test`, and build check `flutter build apk --debug` at the end of chunks 1, 5 and 8.
- Commit once per chunk (user asked: commit by chunk). Message style `feat(scope): ...`. **No Co-Authored-By line.**
- UI copy in Bahasa Indonesia, sentence case.
- API key: `--dart-define=OPENROUTER_API_KEY=...`. Never commit keys. Missing key => LLM falls back to Scripted.

---

## Revisions after plan review (OVERRIDE the chunk text below where they conflict)

**Order of execution:** 1 Scaffold → 2 Core → 4 UX kit → 3 Variant system (with stub specs) → 5 v3 port → 6 v5 Obrolan → 7 v5 rest → 8 Wire + polish. Each chunk must pass `flutter analyze` (0 errors) alone.

**Build/deps**
- R1. `pub add` also: `hexcolor loading_animation_widget material_symbols_icons flutter_material_design_icons cupertino_icons permission_handler`. Drop `flutter_portal` and `google_fonts`; bundle Inter ttf (download from Google Fonts GitHub `rsms/inter` static files into `fonts/`) as family `Inter`.
- R2. `main.dart` calls `await initializeDateFormatting('id_ID')`. Manifest also gets `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_CONNECT` (from v3). Create `assets/scenarios/` in Task 1.2. Android only (`--platforms android`); iOS out of scope.
- R3. `http`: decode with `utf8.decode(res.bodyBytes)`. Share: `SharePlus.instance.share(ShareParams(files: [XFile(path)]))`, export file in `getTemporaryDirectory()`.

**Core services**
- R4. `Scenario` model lives in `lib/core/models/scenario.dart`. `ScriptedStt` gets `onSignal(String)` callback, no tracker reference. `Services` does not hold `ux`; `UxController` is a separate singleton.
- R5. STT: use `SpeechListenOptions(partialResults:, listenMode:)`; normalize level with plugin min/max sound level; restart loop with 300 ms delay, ignore `error_no_match`/`error_speech_timeout`, back off on `error_busy`, skip empty finals; document Android restart beep. Add `start({bool continuous = true})` (v3 uses single-shot 30 s / pauseFor 4 s / confirmation mode).
- R6. Confidence: utterance-level only on finals, ≤ 0 = unknown; low-confidence (< 0.6) flags the **whole bubble** ("Mungkin kurang tepat — ketuk untuk perbaiki"); drop per-word underline.
- R7. Feedback loop: STT is paused while TTS speaks and resumed on completion. `TtsService` state via `setStartHandler/setCompletionHandler/setCancelHandler/setErrorHandler`. Both variants use the same speech rate 0.5.
- R8. Drop the `speechWhilePaused` and automatic `noisy` heuristics. Alerts (noisy, volumeLow, volumeMuted, offline, speechWhilePaused) are real where measurable (volume, offline/LLM failure) and also **triggerable from the researcher panel** for demo/testing.
- R9. Haptics minimum 40 ms. Mic permanently denied → `permission_handler.openAppSettings()`.
- R10. LLM adds `suggestionsFromTranscript(String text, {int max = 6})` for v3 (keeps its 6 suggestions behaviour).

**Variant + harness**
- R11. `SwaranaApp` listens only to `VariantController` + a `studyEpoch` int; key = `ValueKey((variant, studyEpoch))`. Navigator keys, observer and themes are stable fields. Use `home:` (the spec's start widget) instead of a nested `initialRoute` to avoid prefix-route building. New task in study = bump epoch → whole tree and controllers rebuild with fresh services; never `pushNamedAndRemoveUntil` right after a switch. Pages read `Services` in `didChangeDependencies`.
- R12. Harness is placed inside its own `Overlay` + `Material` (via `Overlay(initialEntries: [OverlayEntry(builder: ...)])`) so Slider labels and TextField work above the Navigator.
- R13. Hidden researcher entry: `Listener` + 2 s `Timer`; disabled while a task runs.
- R14. Resume: researcher panel shows "Lanjutkan sesi P03" when an unfinished study exists in storage.

**Study validity (scope review)**
- R15. `studyMode` flag (true during study tasks): v5 hides face mode, typing-chip auto-offer, quick phrases. Keeps the paradigm features (history, unified group chat, suggestions, board, simplify, alerts, TTS status). README states the comparison is "v3 vs v5 as designed", listing the remaining differences.
- R16. **Primary study mode = Live with a human partner** reading printed script cards (README includes the cards generated from scenario json). Scripted mode = pilot/demo/offline fallback; in scripted mode both variants use the same delivery rule: a partner turn is queued until the app is in a listening state, wait time is logged and excluded from task time.
- R17. Success is **marked by the researcher** on a post-task screen (Berhasil / Sebagian / Gagal) before the SEQ; auto-signal is only a hint. Rewrite `cs` so turn 7 asks the user to repeat information given in turn 2 (order number), exercising history.
- R18. Parallel forms: each scenario has form A and B (same structure, different items/numbers). Form assignment and scenario order rotate by participant index (Latin square over 3 scenarios). Results page notes n and AB/BA counts.
- R19. Input mix: each sent message stores composition counts `{typed, board, suggestion}` (characters from each source; board taps and chip taps inserted into the composer are tagged). Report bucket = majority source; quickPhrase excluded in study mode.
- R20. Time = from "Mulai" to researcher marking outcome, minus scripted wait time; briefing, SEQ and questionnaires excluded.
- R21. Speaker identification is **manual / Wizard-of-Oz** in live mode ("Orang lain bicara" button, and researcher can assign); setting renamed "Pisahkan pembicara" ; README states automatic diarization is simulated.
- R22. Add `docs/design-deviations.md` in chunk 6 (screen, Figma state, implemented state, review finding, reason) + list of screens without Figma ("design pending"): Pengaturan, onboarding/consent, alerts, board sheet, rename sheet, bubble menu, face mode.
- R23. Copy glossary in `lib/variants/v5_chat/copy.dart` (single source for labels: Obrolan, Transkrip, Riwayat, Jeda, Lanjutkan, Akhiri obrolan, Bunyikan lagi, Sederhanakan, Tanya arti, Asli/Sederhana). Long partner bubbles (> 25 words) show a visible "Sederhanakan" icon button (not only long-press).
- R24. Cut: CSV export (JSON only), TTS speed slider, disabled language row, 3 onboarding cards (keep rationale + consent), duplicated text-size slider (one shared setting used by Transkrip and Obrolan). Seeded demo chats are skipped when a study is active.

---

## File structure

```
swarana/                      (repo root = C:\Users\emirsyah\Documents\CODING\swarana)
  pubspec.yaml
  assets/v3/icon/*.svg        copied from v3 repo
  assets/v3/image/*.png       copied from v3 repo (108 board images)
  assets/scenarios/*.json     scripted role-play scenarios
  fonts/PlusJakartaSans-*.ttf copied from v3 repo
  lib/
    main.dart                 bootstrap: services, runApp
    app.dart                  SwaranaApp: VariantController -> MaterialApp(key)
    core/
      env.dart                dart-define constants
      models/message.dart     ChatMessage, Speaker, MessageSource, TtsState
      models/session.dart     ChatSession, TranscriptSession (+ json)
      services/stt_service.dart        abstract SttService + LiveSttService
      services/tts_service.dart        abstract TtsService + LiveTtsService (state stream)
      services/llm_service.dart        abstract LlmService + OpenRouterLlm
      services/scripted.dart           ScriptedStt/ScriptedLlm driven by scenario json
      services/haptics.dart            Haptics.alert/tick/done
      services/audio_monitor.dart      volume + noise checks -> AlertEvent stream
      services/storage.dart            JSON-file store for sessions + study results
      services/services.dart           Services container (InheritedWidget)
    variant/
      variant.dart            AppVariant enum, VariantSpec, VariantController
      researcher_panel.dart   hidden setup page
    ux_kit/
      ux_controller.dart      tracker brain (ported + fixed)
      ux_models.dart          UxTask, TaskResult, StudyConfig, StudyResult
      ux_sinks.dart           DebugSink, FileSink
      ux_harness.dart         overlay: briefing, task bar, break, done
      questionnaires.dart     SUS + NASA-TLX widgets + scoring
      results_page.dart       researcher dashboard + export
      scenarios.dart          load scenario json -> UxTask list
    variants/
      v3_board/               ported v3 (features/, core/widgets/, v3_spec.dart)
      v5_chat/
        v5_spec.dart
        design/tokens.dart    colors, speaker palette, spacing, radius
        design/theme.dart     ThemeData + ThemeExtension
        widgets/              header_status.dart, bubble.dart, composer.dart,
                              suggestions.dart, alert_banner.dart, word_explain.dart
        obrolan/              obrolan_page.dart, obrolan_controller.dart,
                              board_sheet.dart, face_mode.dart, save_dialog.dart,
                              rename_speaker_sheet.dart
        transkrip/            transkrip_page.dart, transkrip_detail_page.dart
        riwayat/              riwayat_page.dart, obrolan_detail_page.dart
        settings/             settings_page.dart
        onboarding/           splash_page.dart, onboarding_page.dart
        drawer.dart
  test/
    sus_tlx_test.dart
    ux_controller_test.dart
    openrouter_parse_test.dart
    scripted_test.dart
```

---

## Chunk 1: Scaffold

### Task 1.1: Create project and git

**Files:** Create: everything from `flutter create`, `.gitignore`

- [ ] **Step 1:** In `C:\Users\emirsyah\Documents\CODING\swarana`, run
  `flutter create --org id.swarana --project-name swarana --platforms android,ios .`
  Expected: "All done!". Existing `tracker/`, `design/`, `docs/`, PDF untouched.
- [ ] **Step 2:** `git init -b main`. Append to `.gitignore`: `*.pdf` (11 MB report stays out of git), `.env`.
- [ ] **Step 3:** Delete `test/widget_test.dart` (refers to counter app).

### Task 1.2: Dependencies and assets

**Files:** Modify `pubspec.yaml`

- [ ] **Step 1:** `flutter pub add speech_to_text flutter_tts http vibration volume_controller shared_preferences path_provider share_plus flutter_svg iconsax_plus intl google_fonts`
- [ ] **Step 2:** Copy from `%TEMP%/swarana-v3`: `assets/icon` -> `assets/v3/icon`, `assets/image` -> `assets/v3/image`, `fonts/PlusJakartaSans-{Regular,Medium,SemiBold,Bold}.ttf` -> `fonts/` (bulk copy via shell is allowed: binary assets).
- [ ] **Step 3:** In `pubspec.yaml` `flutter:` add assets `assets/v3/icon/`, `assets/v3/image/`, `assets/scenarios/` and the PlusJakartaSans family with weights 400/500/600/700.
- [ ] **Step 4:** Android: add `RECORD_AUDIO`, `INTERNET`, `VIBRATE` permissions and the `<queries>` for `android.speech.RecognitionService` and `android.intent.action.TTS_SERVICE` to `android/app/src/main/AndroidManifest.xml`. iOS: add `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` (Indonesian text) to `ios/Runner/Info.plist`. Set Android `minSdk 28` (Android 9, per report) in `android/app/build.gradle(.kts)`.

### Task 1.3: env + empty app boots

**Files:** Create `lib/core/env.dart`, replace `lib/main.dart`

```dart
// lib/core/env.dart
class Env {
  static const openRouterKey = String.fromEnvironment('OPENROUTER_API_KEY');
  static const openRouterModel =
      String.fromEnvironment('OPENROUTER_MODEL', defaultValue: 'google/gemini-2.5-flash');
  static bool get hasLlm => openRouterKey.isNotEmpty;
}
```

- [ ] **Step 1:** Before writing, check current Gemini Flash ids: `curl -s https://openrouter.ai/api/v1/models | grep -o '"id":"google/gemini[^"]*flash[^"]*"'`. Use the newest non-preview flash id as the default.
- [ ] **Step 2:** `main.dart` temporarily runs a `MaterialApp(home: Placeholder())`.
- [ ] **Step 3:** `flutter analyze` → no issues. `flutter build apk --debug` → succeeds.
- [ ] **Step 4:** Commit `chore: scaffold flutter project with deps and v3 assets`.

---

## Chunk 2: Core models and services

### Task 2.1: Models

**Files:** Create `lib/core/models/message.dart`, `lib/core/models/session.dart`

```dart
// message.dart
enum MessageSource { keyboard, suggestion, board, quickPhrase, stt }
enum TtsState { idle, speaking, done, failed, muted }

class Speaker {
  Speaker({required this.id, required this.name, required this.colorIndex});
  final String id;          // 'me' for the user, 's1', 's2'...
  String name;              // 'Pembicara 1' until renamed
  final int colorIndex;     // index into speaker palette
  bool get isMe => id == 'me';
  Map<String, Object?> toJson() => {'id': id, 'name': name, 'color': colorIndex};
  factory Speaker.fromJson(Map<String, Object?> j) =>
      Speaker(id: j['id'] as String, name: j['name'] as String, colorIndex: j['color'] as int);
}

class ChatMessage {
  ChatMessage({required this.id, required this.speakerId, required this.text,
      required this.time, this.source = MessageSource.stt, this.partial = false,
      this.lowConfidenceWords = const []});
  final String id;
  final String speakerId;
  String text;
  final DateTime time;
  final MessageSource source;
  bool partial;                     // live STT bubble still forming
  List<String> lowConfidenceWords;  // underlined in UI
  String? simplified;               // cached LLM simplification
  TtsState tts = TtsState.idle;
  // toJson/fromJson for id, speakerId, text, time (iso), source.name, simplified
}
```

`session.dart`: `ChatSession {id, title, createdAt, List<Speaker> speakers, List<ChatMessage> messages}` and `TranscriptSession {id, title, createdAt, Duration duration, String text, String? simplified}`, both with `toJson/fromJson`.

### Task 2.2: Storage

**Files:** Create `lib/core/services/storage.dart`

JSON files under `getApplicationDocumentsDirectory()/swarana/`: `chats.json`, `transcripts.json`, `study/<participant>.json`. API:
```dart
class Storage {
  Future<void> init();
  Future<List<ChatSession>> chats(); Future<void> saveChat(ChatSession s); Future<void> deleteChat(String id);
  Future<List<TranscriptSession>> transcripts(); Future<void> saveTranscript(TranscriptSession t); Future<void> deleteTranscript(String id);
  Future<void> appendEvent(String participantId, Map<String, Object?> e); // events.jsonl
  Future<void> saveStudy(String participantId, Map<String, Object?> json);
  Future<List<Map<String, Object?>>> studies();
  Future<File> exportAll(); // single JSON with every study + events, for share_plus
}
```
Seed `chats.json` with 3 demo sessions on first run so Riwayat isn't empty in a demo (mark `demo: true`).

### Task 2.3: LLM (OpenRouter) — with test

**Files:** Create `lib/core/services/llm_service.dart`, `test/openrouter_parse_test.dart`

```dart
abstract class LlmService {
  Future<List<String>> suggestReplies(List<ChatMessage> history, Map<String, Speaker> speakers, {String draft = ''});
  Future<String> simplify(String text);
  Future<String> explainWord(String word, String context);
  Future<String> titleFor(String text);
}

class OpenRouterLlm implements LlmService {
  OpenRouterLlm({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;
  static final _url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

  Future<String> _ask(String system, String user, {double temperature = 0.4}) async {
    final res = await _http.post(_url,
        headers: {'Authorization': 'Bearer ${Env.openRouterKey}', 'Content-Type': 'application/json',
                  'X-Title': 'Swarana'},
        body: jsonEncode({'model': Env.openRouterModel, 'temperature': temperature,
          'messages': [{'role': 'system', 'content': system}, {'role': 'user', 'content': user}]}))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw LlmException('HTTP ${res.statusCode}');
    return parseContent(res.body);
  }

  static String parseContent(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    final c = (j['choices'] as List?)?.firstOrNull?['message']?['content'];
    if (c is! String || c.trim().isEmpty) throw LlmException('empty');
    return c.trim();
  }

  static List<String> parseLines(String content) => content
      .split('\n')
      .map((l) => l.replaceFirst(RegExp(r'^\s*([-*•]|\d+[.)])\s*'), '').replaceAll('"', '').trim())
      .where((l) => l.isNotEmpty).take(3).toList();
  ...
}
```
Prompts (Role, User Context, Task, Constraint framework, from report iter-2):
- suggestReplies system: "Kamu membantu Teman Tuli membalas percakapan lisan. Beri tepat 3 balasan singkat (maks 8 kata), bahasa sehari-hari yang sopan, berbeda maksud (setuju / bertanya / menolak atau lainnya). Satu per baris, tanpa nomor." User: last 8 messages as `Nama: teks`, plus draft if any ("Lanjutkan draf: ...").
- simplify: "Tulis ulang dengan kalimat pendek (maks 12 kata per kalimat), kata sehari-hari, tanpa istilah sulit. Pertahankan semua angka, nama, tanggal."
- explainWord: "Jelaskan arti kata/frasa '<w>' dalam konteks berikut dalam 1 kalimat sederhana (maks 15 kata)."
- titleFor: "Beri judul 2-4 kata untuk percakapan/transkrip ini. Hanya judul."

`LlmException` caught by callers → UI error state. Test (`openrouter_parse_test.dart`): parseContent on a sample OpenRouter JSON; throws on empty; parseLines strips "1. ", "- ", quotes, keeps 3.

- [ ] Run `flutter test test/openrouter_parse_test.dart` → PASS.

### Task 2.4: STT, TTS, haptics, audio monitor

**Files:** `stt_service.dart`, `tts_service.dart`, `haptics.dart`, `audio_monitor.dart`

```dart
class SttEvent { SttEvent(this.text, {required this.isFinal, this.speakerId, this.confidence = 1, this.lowWords = const []}); ... }
enum SttStatus { idle, listening, paused, unavailable, error }
abstract class SttService {
  ValueListenable<SttStatus> get status;
  ValueListenable<double> get level;      // 0..1 for header meter
  Stream<SttEvent> get events;
  Future<bool> init();                    // asks mic permission
  Future<void> start(); Future<void> pause(); Future<void> stop();
}
```
`LiveSttService` uses `speech_to_text` with `localeId: 'id_ID'`, `listenMode: ListenMode.dictation`, `partialResults: true`, `pauseFor: 3s`, auto-restarts after each final result while status == listening (speech_to_text stops on silence). Maps `onSoundLevelChange` (dB) to 0..1 level. Speaker attribution in live mode: single detected speaker `s1`; the UI offers "Orang lain bicara" button to start a new speaker (`nextSpeaker()`), since on-device STT has no diarization. Words with confidence < 0.6 (from `SpeechRecognitionWords.confidence` when provided) go to `lowWords`.

`TtsService` wraps `flutter_tts` (`setLanguage('id-ID')`, `awaitSpeakCompletion(true)`) and exposes `Stream<(String messageId, TtsState)>`; before speaking checks `VolumeController` volume: if 0 → emit `muted` and an AlertEvent `volumeMuted`; if < 0.3 → `volumeLow` alert but still speaks.

`Haptics`: `tick()` (light, 20ms), `done()` (2× short), `alert()` (pattern [0,200,100,200]) via `vibration`, guarded by `hasVibrator`.

`AudioMonitor`: listens to `SttService.level`; sustained level > 0.85 for 3s while no words recognized → `AlertEvent.noisy`; sound level > 0.4 while STT paused → `AlertEvent.speechWhilePaused`. Connectivity: LLM failure → `AlertEvent.offline`. Each alert = banner + `Haptics.alert()`.

### Task 2.5: Scripted services — with test

**Files:** `lib/core/services/scripted.dart`, `assets/scenarios/{warung,bank,cs}.json`, `test/scripted_test.dart`

Scenario JSON:
```json
{"id":"warung","title":"Beli barang di warung","instruction":"Kamu ingin membeli 2 bungkus mi instan dan bertanya harganya.",
 "complexity":"sederhana","speakers":["Penjual"],
 "turns":[
   {"speaker":"s1","text":"Selamat siang, mau beli apa?","suggest":["Mi instan dua bungkus","Ada air mineral?","Berapa harganya?"]},
   {"waitForUser":true},
   {"speaker":"s1","text":"Dua bungkus jadi enam ribu ya.","suggest":["Ini uangnya","Bisa bayar QRIS?","Terima kasih"]},
   {"waitForUser":true, "successSignal":"warung_done"}
 ]}
```
`bank` = 5 interactions (open account, same as iter-3 scenario-2), `cs` = chat-heavy 8–10 turns with 2 speakers (CS + supervisor joins mid-way, tests group switching). `ScriptedStt` emits each speaker turn as partial words (80ms/word) then final, then waits until the app calls `userReplied()`; emits a `successSignal` via the tracker when the last `waitForUser` is satisfied. `ScriptedLlm.suggestReplies` returns the current turn's `suggest`; `simplify/explainWord` return canned text from optional `simplified`/`glossary` fields, else a generic fallback.
Test: load `warung.json` from a string, drive `userReplied()`, assert event order and that the success callback fires once.

### Task 2.6: Services container

**Files:** `lib/core/services/services.dart`

`Services` (InheritedWidget, `Services.of(context)`) holds `stt, tts, llm, haptics, audio, storage, ux`. Factory `Services.create({required bool scripted, Scenario? scenario})`. Live LLM falls back to `ScriptedLlm.generic()` when `!Env.hasLlm`.

- [ ] `flutter analyze`, `flutter test` → pass. Commit `feat(core): models, storage, openrouter llm, stt/tts, scripted scenarios`.

---

## Chunk 3: Variant system and researcher panel

### Task 3.1: VariantController

**Files:** `lib/variant/variant.dart`, `lib/app.dart`, `lib/main.dart`

```dart
enum AppVariant { v3Board, v5Chat }
abstract class VariantSpec {
  ThemeData get theme;
  Map<String, WidgetBuilder> get routes;
  String get home;
  String get label;
}
class VariantController extends ChangeNotifier {
  VariantController(this._prefs) : current = AppVariant.values.byName(_prefs.getString('variant') ?? 'v5Chat');
  final SharedPreferences _prefs;
  AppVariant current;
  void switchTo(AppVariant v) { if (v == current) return; current = v; _prefs.setString('variant', v.name); notifyListeners(); }
}
```
`SwaranaApp` (in `app.dart`): `ListenableBuilder` on the controller and `UxController`; builds
```dart
MaterialApp(
  key: ValueKey(variant), navigatorKey: navKeys[variant], theme: spec.theme,
  routes: {...spec.routes, '/researcher': (_) => const ResearcherPanel(), '/results': (_) => const ResultsPage()},
  initialRoute: spec.home, navigatorObservers: [UxNavigatorObserver()],
  builder: (ctx, child) => UxHarness(child: child!),
)
```
Each variant gets its own `GlobalKey<NavigatorState>` (map) — reusing one key across two MaterialApps throws.

### Task 3.2: Hidden researcher entry

- [ ] Long-press 2s on the app title ("Obrolan" in v5 header, logo in v3 board header) → `pushNamed('/researcher')`. Also 5 quick taps on splash logo.
- [ ] Deep link deferred (YAGNI): skip uni_links; panel is enough.

### Task 3.3: ResearcherPanel

**Files:** `lib/variant/researcher_panel.dart`

Fields: participant ID (text, required, e.g. `P03`), order (`AB` = v3→v5 / `BA` = v5→v3, SegmentedButton), scenarios (checkboxes warung/bank/cs, default all), data mode (Scripted / Live), break duration (default 15 min). Buttons: "Mulai sesi uji" → `UxController.startStudy(StudyConfig)`; "Lihat hasil" → `/results`; "Mode bebas" (no study, just switch variant: two buttons v3/v5). Plain Material styling.

- [ ] `flutter analyze`. Commit `feat(variant): runtime variant switch and researcher panel`.

---

## Chunk 4: UX test kit v2

### Task 4.1: Models

**Files:** `lib/ux_kit/ux_models.dart` — move `UxTask`, `TaskOutcome`, `TaskResult` from `tracker/ux_task_kit.dart`; add to `TaskResult`: `variant`, `inputMix` (`Map<String,int>` per MessageSource), `messagesSent`. Add:
```dart
class StudyConfig { participantId; List<AppVariant> order; List<String> scenarioIds; bool scripted; Duration breakDuration; }
class VariantBlock { AppVariant variant; List<TaskResult> tasks; int? sus; Map<String,int>? tlx; double? tlxRaw; }
class StudyResult { StudyConfig config; DateTime startedAt; List<VariantBlock> blocks; toJson(); }
```

### Task 4.2: Controller (ported + fixed) — with test

**Files:** `lib/ux_kit/ux_controller.dart`, `lib/ux_kit/ux_sinks.dart`, `test/ux_controller_test.dart`

Port `UxTestController` and fix:
1. Rage clicks only counted and emitted when `isRunning`.
2. `onRoute` on pop: record the route returned to, but don't treat a pop as forward path for direct-success (store path entries as `('push'|'pop', route)`; direct success compares only push entries).
3. Add `track(String event, {MessageSource? source, Map<String,Object?> props})`; `message_sent` increments `inputMix[source]`.
4. Every event includes `variant`, `order_position`, `scenario`.
5. Phase state machine: `idle → briefing → running → rating(SEQ) → (next task | questionnaires) → break → briefing(next variant) … → done`. `questionnaires` shows SUS then TLX for the variant just finished.
6. On entering the second block: `variantController.switchTo(order[1])`, recreate scripted services for the next scenario, reset to the variant's home.
7. `FileSink` writes every event to `Storage.appendEvent` and the controller writes `StudyResult` via `Storage.saveStudy` after each phase change (crash-safe).
8. Testable without Flutter bindings: inject `clock` (`DateTime Function()`), make `onTap` take `Offset`/`Size` only.

Tests: rage click needs 3 taps within 1 s and 40 px while running, none when idle; pop then push yields indirect success; `message_sent` with source keyboard/suggestion fills `inputMix`.

### Task 4.3: Questionnaires — with test

**Files:** `lib/ux_kit/questionnaires.dart`, `test/sus_tlx_test.dart`

SUS: 10 items, Indonesian wording from Sharfina & Santoso (2016), 1–5 scale. `int susScore(List<int> a)` = ((sum over odd items (a-1)) + (sum over even items (5-a))) × 2.5. Test: all 3s → 50; ideal (5,1,5,1…) → 100.
NASA-TLX raw: 6 sliders 0–100 step 5 (Kebutuhan mental, Kebutuhan fisik, Tekanan waktu, Performa [0 = sempurna], Usaha, Frustrasi). `double tlxRaw(Map)` = mean. Test: mean of known values.
SEQ: 1–7, already exists, keep.
Widgets: one question per screen, big tap targets (≥ 56 px), progress "3/10", "Lanjut" disabled until answered.

### Task 4.4: Harness overlay

**Files:** `lib/ux_kit/ux_harness.dart`

Port `UxTestHarness` overlay; changes: Indonesian copy ("Tugas 1 dari 3", "Mulai", "Selesai", "Menyerah"); briefing shows scenario instruction + who the partner is; task bar sits at the **bottom-left** as a small collapsible pill so it does not cover v5's header status (expand on tap); break screen with countdown and "Lanjut ke versi berikutnya" (enabled when countdown ends, researcher can long-press to skip); done screen with "Lihat hasil". Tap `Listener` stays.

### Task 4.5: Results page + export

**Files:** `lib/ux_kit/results_page.dart`

List participants; per participant a table: scenario × variant time (s), outcome, SEQ, input mix bars (keyboard / suggestion / board / quick phrase as %); per variant SUS and TLX. Summary card across participants: mean time per scenario for v3 vs v5 with % difference (same format as the report table), mean SUS, mean TLX, aggregated input mix. "Ekspor JSON" → `Storage.exportAll()` → `Share.shareXFiles`. "Ekspor CSV" (one row per task) too, since the team will chart it in sheets.

- [ ] Delete `tracker/` folder (superseded). `flutter analyze`, `flutter test`. Commit `feat(ux-kit): study flow, tracking, SUS/TLX, results export`.

---

## Chunk 5: v3 board port

### Task 5.1: Copy and adapt

**Files:** `lib/variants/v3_board/**` from `%TEMP%/swarana-v3/lib/` (`features/`, `core/widgets/`, `common/`)

- [ ] Copy files; fix imports to `package:swarana/variants/v3_board/...`; asset paths `assets/icon/` → `assets/v3/icon/`, `assets/image/` → `assets/v3/image/`.
- [ ] Replace v3's own `SpeechService`, `GeminiSuggestionService`, TTS usage and `VolumeAlertService` with calls through `Services.of(context)` (shared STT/TTS/LLM so the A/B compares interface only). Keep their UI and state handling.
- [ ] Remove `flutter_portal` usage only if trivial; otherwise add the dependency and wrap v3 home in `Portal`.
- [ ] Keep hardcoded colors as-is (control condition must look like Iter-3).
- [ ] `v3_spec.dart`: theme copied exactly from v3 `main.dart` (`ColorScheme.fromSeed(seedColor: HexColor('#3C37AF'))`, white scaffold, M3, PlusJakartaSans); routes `/v3` → `MainWrapper`, `/v3/transkrip`, `/v3/transkrip/result` (convert its `MaterialPageRoute` to `RouteSettings(name:)`).

### Task 5.2: Tracking hooks

- [ ] Board word tap that speaks → `ux.track('message_sent', source: MessageSource.board)`; keyboard send → `keyboard`; suggestion tap → `suggestion`. Mode Dengar start → `ux.track('listen_started')`.
- [ ] In scripted mode, v3 Mode Dengar shows ScriptedStt text exactly as its live STT did. Call `stt.userReplied()` after each send.
- [ ] `flutter analyze`; `flutter build apk --debug`. Commit `feat(v3): port Iter-3 board app as baseline variant`.

---

## Chunk 6: v5 design system and Obrolan

Visual reference: `design/v5/screens/5Starting page.png`, `53 Pembicara terdeteksi*.png`, `5Sidebar.png`.

### Task 6.1: Tokens and theme

**Files:** `lib/variants/v5_chat/design/tokens.dart`, `theme.dart`

From the screens: primary `#1F4FFF` (splash and send button), ink `#1A1A1A`, secondary text `#6B7280`, border `#E5E7EB`, page `#FAFAFB`, partner bubble `#FFFFFF`, warning bg `#FFF8E6` / border `#F5C451` / icon `#F59E0B`, error `#DC2626`, AI tint `#EAF0FF`. Font Inter (google_fonts). Radius: bubble 16, chip 999, card 16. Spacing unit 4.

Review-driven changes (mark each as a deliberate deviation in a comment):
- **My bubbles tinted** `#EAF0FF` with ink text (WhatsApp convention), partner bubbles white.
- **Speaker palette (colorblind-safe, Okabe-Ito)**: `#0072B2, #D55E00, #009E73, #CC79A7, #E69F00, #56B4E9`; avatar = colored circle with initial, bubble gets a 3 px left border in that color.
- Body text 17 px / 1.45 line height, left aligned everywhere (no justify).
- Min touch target 48 px.

### Task 6.2: Shared widgets

**Files:** `widgets/header_status.dart`, `bubble.dart`, `composer.dart`, `suggestions.dart`, `alert_banner.dart`, `word_explain.dart`

- `HeaderStatus(title, status, level, onPauseToggle, onMenu)`: left title (long-press 2 s → researcher), right round menu button. Status row with **distinct states**: listening = red pulsing dot + live level bars (5 bars driven by `level`) + "Mendengarkan"; paused = grey pause icon + "Jeda — tidak mendengar"; idle = grey mic-off + "Tidak merekam"; error = red + reason. Text color ≥ 4.5:1. The **Jeda/Lanjut button lives here** (not a floating FAB).
- `MessageBubble(message, speaker, onLongPress)`: partner: avatar + name row (tap name → rename sheet, 48 px target) + bubble with left color border; partial messages show italic text + animated "…" + label "sedang bicara". Low-confidence words dotted-underlined; tap → correct inline. My bubble: text + **TTS status row**: speaking = animated wave + "Sedang dibunyikan", done = check + "Sudah dibunyikan", failed/muted = red + "Gagal — volume 0" + "Bunyikan lagi" button. Timestamp small.
- Long-press any bubble → bottom sheet menu: **Salin, Sederhanakan, Tanya arti kata, Bunyikan** (partner bubbles: Sederhanakan/Tanya/Salin/"Minta ulangi"). Simplified result shows inline under the bubble with toggle "Asli | Sederhana".
- `Composer`: leading **board button** (grid icon) → board sheet; text field "Tulis pesan di sini" (multi-line up to 4); send button (primary circle). While typing (debounce 600 ms) request suggestions with draft.
- `SuggestionsPanel`: header "Rekomendasi balasan" + neutral close; chips **wrap to max 2 rows** (no clipping), each ≤ 8 words; loading = 3 shimmer chips; error = "Saran tidak tersedia" + retry. Tapping a chip sends it (source suggestion) and speaks it. Long-press chip = put in field to edit.
- `AlertBanner`: amber/red banner with icon + text + close; triggers `Haptics.alert()` and a 300 ms screen-edge flash. Messages: noisy "Suasana terlalu bising, dekatkan ponsel ke pembicara", volumeLow "Volume ponsel kecil, lawan bicara mungkin tidak dengar", volumeMuted "Volume 0, suara tidak keluar", speechWhilePaused "Ada yang bicara, tapi Swarana sedang jeda" + action "Lanjutkan", offline "Tidak ada internet. Saran AI mati, papan tetap bisa dipakai".
- `WordExplainPopover`: card near selection, AI answer, loading and error states.

### Task 6.3: ObrolanController

**Files:** `obrolan/obrolan_controller.dart`

`ChangeNotifier` holding `ChatSession`, speakers map, suggestions state, alerts. Subscribes to `stt.events`: partial → upsert partial bubble for that speaker; final → finalize, `haptics.tick()`, refresh suggestions. New speaker id → add `Speaker('Pembicara n', nextColor)`; when speakers (excluding me) > 1 → group mode (names shown on every bubble; in 1:1 names hidden like the design). `send(text, source)` → add my message, `tts.speak`, `ux.track('message_sent', source)`, `stt.userReplied()`, clear suggestions. `pauseListening/resume`. `saveSession()` → title via `llm.titleFor`, `storage.saveChat`. Auto-scroll to bottom unless user scrolled up (then show "Pesan baru ↓" pill).

### Task 6.4: ObrolanPage

**Files:** `obrolan/obrolan_page.dart`

Layout = design: header, message list, suggestions panel above composer, drawer (endDrawer from right as in sidebar design). Empty state (new chat): centered card "Mulai obrolan" + intro-card button + text "Swarana akan mendengarkan dan menuliskan ucapan lawan bicara".

### Task 6.5: Quick phrases + face mode + intro card

**Files:** `obrolan/face_mode.dart`

- Quick phrases row (collapsed under composer's board button sheet top): "Halo, saya tuli. Mohon bicara pelan ke ponsel ini", "Mohon tunggu, saya sedang mengetik", "Bisa diulangi?", "Terima kasih". Tapping speaks + sends (source quickPhrase).
- "Mohon tunggu" auto-offer: when the user has typed for > 4 s with partner idle, show a small chip "Beri tahu sedang mengetik" → speaks the phrase.
- **Face mode** (icon in header): full screen, last message from me in 40 px text, rotated 180° on the top half for the partner, normal on bottom; tap to exit.

### Task 6.6: Board sheet

**Files:** `obrolan/board_sheet.dart`

Draggable bottom sheet, tabs "Kata" | "Kalimat". Reuses v3 board images (`assets/v3/image/`) via a shared list `lib/core/board_items.dart` (word, image path, category) — v3 keeps its own copy untouched. Tap word → appends to composer (so words build a sentence); tap sentence → sends directly (source board). Works offline.

### Task 6.7: Save / end session + rename speaker

**Files:** `obrolan/save_dialog.dart`, `obrolan/rename_speaker_sheet.dart`

End button in drawer is styled **destructive outline** ("Akhiri obrolan"), opens dialog: editable AI title (label "Judul dibuat AI, bisa diubah"), primary "Simpan", text "Buang" (red) → confirm dialog, "Batal". Rename sheet: text field + "Simpan", applies everywhere.

- [ ] `flutter analyze`. Commit `feat(v5): design tokens and Obrolan chat with suggestions, board, alerts, face mode`.

---

## Chunk 7: v5 Transkrip, Riwayat, Settings, onboarding

### Task 7.1: Transkrip live

**Files:** `transkrip/transkrip_page.dart` (ref `5Transkrip - 7/8/9.png`)

Idle: big mic button "Mulai transkrip", header status idle (not "Mendengarkan"). Running: rolling paragraphs (final text in ink, current partial in grey) with a timestamp every 30 s, auto-follow with "Ke bawah" pill when scrolled up; text-size slider with 4 snap points and current size label; stop button "Hentikan transkrip" (red square) → save dialog (same component as Obrolan, AI title, "Batal"). Warning banner "Dekatkan mikrofon ponsel ke sumber suara" when level low for 5 s.

### Task 7.2: Transkrip detail

**Files:** `transkrip/transkrip_detail_page.dart` (ref `5Homepage - Umum - Kata*.png`)

Title, date, "Tersimpan" chip. **SegmentedButton "Asli | Sederhana"** at top (replaces "Versi Asli" pill + "Ringkasan" button); Sederhana loads `llm.simplify` with loading skeleton and caches into session. Text left-aligned, paragraph spacing 16. Persistent "Tanya kata" toggle in the bottom bar: when on, tapping a word highlights it (amber `#F5B000` bg) and shows `WordExplainPopover`; long-press selects a phrase (SelectableText → selection → "Tanya AI" context menu item). First-visit tooltip as in design. Text-size slider shared with live page.

### Task 7.3: Riwayat

**Files:** `riwayat/riwayat_page.dart`, `riwayat/obrolan_detail_page.dart` (ref `5Riwayat*.png`)

Tabs Obrolan | Transkrip, search field on top (filters title + text). Rows: title, date, "3 orang bicara" (plain wording), transcript rows show duration. "⋯" button 48 px → Ubah nama / Hapus (confirm). Empty states per tab. Obrolan detail: read-only chat with same bubbles (long-press menu works, Sederhanakan), bottom primary "Lanjutkan obrolan" → opens ObrolanPage with that session.

### Task 7.4: Drawer + Settings

**Files:** `drawer.dart`, `settings/settings_page.dart`

Drawer (ref `5Sidebar.png`): app logo + name header, "Pilihan" (Obrolan, Transkrip, Riwayat, Pengaturan, current item highlighted), "Obrolan terkini" (3 latest from storage, "Lihat semua" → Riwayat), bottom "Akhiri obrolan" only when an Obrolan session is active. Settings: Identifikasi pembicara otomatis (switch; off = all partner speech as one speaker), ukuran teks obrolan (slider 4 snaps, applies to chat), getaran (switch), suara TTS kecepatan (slider), bahasa (Indonesia only, disabled), "Tentang & privasi".

### Task 7.5: Splash + onboarding + permission + consent

**Files:** `onboarding/splash_page.dart`, `onboarding/onboarding_page.dart`

Splash as design (blue `#1F4FFF`, logo, tagline non-italic medium weight for contrast), 1.2 s. First launch only: 3 onboarding cards (Obrolan, Transkrip, AI bantu) → permission rationale "Swarana butuh mikrofon untuk menuliskan ucapan orang di sekitarmu" → system prompt. Denied state page with "Buka pengaturan" (`openAppSettings` not available without permission_handler: use speech_to_text `hasPermission` + text instructions; YAGNI). Consent note card shown once: "Beri tahu lawan bicara bahwa ucapannya ditulis oleh aplikasi. Audio tidak disimpan, hanya teks." Persist `onboarded` in prefs. Routes `/v5/splash`, `/v5/onboarding`, `/v5/obrolan`, `/v5/transkrip`, `/v5/transkrip/detail`, `/v5/riwayat`, `/v5/riwayat/obrolan`, `/v5/settings`.

- [ ] `flutter analyze`. Commit `feat(v5): transkrip, riwayat, settings, onboarding and consent`.

---

## Chunk 8: Wire study flow end to end + polish

### Task 8.1: Scenario wiring

- [ ] `scenarios.dart` loads `assets/scenarios/*.json` → `UxTask(id, title, instruction, startRoute: spec.home-chat-route, successSignal: '<id>_done', timeLimit: 5 min)`. For v3 startRoute `/v3`, v5 `/v5/obrolan` (skips splash/onboarding during study).
- [ ] When a task starts in scripted mode: `Services` swaps `stt`/`llm` to `ScriptedStt(scenario)`/`ScriptedLlm(scenario)` and the Obrolan/v3 pages re-subscribe (listen to `Services` change notifier).

### Task 8.2: Manual run-through

- [ ] `flutter run` on device/emulator (or `-d windows` won't support STT; use Android emulator). Run study P00, order BA, scripted, break 10 s. Walk all 3 scenarios in both variants; fill SUS/TLX; check results page numbers and the exported JSON/CSV.
- [ ] Live mode smoke test with `--dart-define=OPENROUTER_API_KEY=...`: suggestions, simplify, explain word, title.
- [ ] Fix found issues.

### Task 8.3: README

**Files:** `README.md` — how to run (`flutter run --dart-define=OPENROUTER_API_KEY=...`), how to open the researcher panel, how to run a study, export format, folder map.

- [ ] `flutter analyze`, `flutter test`, `flutter build apk --debug`. Commit `feat(study): wire scripted scenarios end to end, README`.
