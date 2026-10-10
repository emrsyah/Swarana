# New Swarana

AAC app for Teman Tuli (GEMASTIK XIX, UX design). One Flutter app holds two variants for the within-subject A/B study in the report:

- **v3 – Board** (`lib/variants/v3_board/`): the iteration-3 app, ported almost unchanged as the control.
- **v5 – Chat** (`lib/variants/v5_chat/`): Obrolan (chat with live speech-to-text, TTS, AI suggestions, board), Transkrip, Riwayat, Pengaturan.

Both run on the same shared services (`lib/core/`), so the A/B compares the interface, not the engine.

## Run

```bash
flutter pub get
flutter run --dart-define=OPENROUTER_API_KEY=sk-or-...
# optional: --dart-define=OPENROUTER_MODEL=google/gemini-3.8-flash
```

No key: AI features fall back to canned answers. Android 9+ (minSdk 28). The first Gradle build needs several GB free on the drive holding `~/.gradle`; set `GRADLE_USER_HOME` to another drive if C: is tight.

## Researcher panel

Hold the screen title for 2 seconds ("Obrolan" in v5, the top hint text on the v3 board). It is disabled while a study task runs.

- **Sesi uji A/B**: participant ID, order (v3→v5 or v5→v3; even IDs v3 first is the suggested balance), scenarios, partner mode, rest length.
- **Mode bebas**: switch variant without a study.
- **Picu peringatan**: fire any alert (noise, volume, offline...) for demos.
- **Lihat hasil uji**: dashboard and JSON export.

## Study protocol (what the app enforces)

1. Per variant: for each scenario → briefing → task (timer pill bottom-left: *Selesai* / *Menyerah*) → researcher marks **Berhasil / Sebagian / Gagal** → SEQ (1–7).
2. After the variant's scenarios: SUS (Indonesian, Sharfina & Santoso 2016) then NASA-TLX raw.
3. Rest screen (countdown; long-press the button to skip), then the other variant.
4. Scenario order rotates per participant (Latin square). Each scenario has parallel forms A/B; a participant gets A in one variant and B in the other.
5. Task time (`duration_ms`) is raw, from *Mulai* to the end tap. Time a scripted partner line waited for the app to listen is exported separately (`waited_ms`) and not subtracted, because in v3 it includes the mic re-tap cost being compared.
6. Input mix: every sent message is bucketed by where most characters came from (keyboard / AI suggestion / board), like the 84 / 11 / 5 % split in iteration 3.
7. In study mode v5 hides face mode, quick phrases and the "saya sedang mengetik" offer, since v3 has no equivalent. The comparison is "v3 vs v5 as designed".

**Known differences to report as limitations** (kept so each variant behaves as designed):
- AI suggestions: v3 shows up to 6 from the last transcript; v5 shows 3 using the whole conversation (scripted mode gives both the same 3).
- Listening: v3 listens once per tap (30 s); v5 listens continuously and pauses while speaking.
- Haptics: v3 vibrates on an empty capture; v5 on every partner message, TTS done, and alerts.
- v3 uses its own TTS instance (same rate 0.5) and does not pause listening while speaking.
- Form order uses a different participant bit than variant order, so forms are not confounded with variants (P00/P01 A→B, P02/P03 B→A).
- The event log includes events outside tasks; filter on `in_task` when analysing.

**Primary mode: a human partner** reads the script cards below. *Lawan bicara otomatis* plays the same lines as fake speech, for pilots and demos only.

**Speaker identification** is manual (Wizard-of-Oz): on-device speech recognition cannot tell voices apart, so the user taps *Orang lain bicara* (or scripted mode assigns speakers). Don't present it as automatic diarization.

Results are saved after every step (`<app documents>/swarana/study/`). An unfinished session can be resumed from the panel.

## Script cards for the hearing partner

Read one line, wait for the participant's reply, then read the next. The full text is in `assets/scenarios/*.json`.

**Warung (simple, 2 interactions)**
- A: "Selamat siang, mau beli apa?" → "Dua bungkus jadi enam ribu rupiah, ya."
- B: "Sore, cari apa?" → "Yang besar tujuh ribu rupiah."

**Bank (complex, 5 interactions)**
- A: greet → ask for KTP → minimum deposit Rp50.000, how much? → regular or online-shopping ATM card? → sign here, card ready.
- B: same structure, payroll account, minimum Rp100.000.

**Customer service (chat-heavy, 8 interactions, a second speaker joins)**
- A: package delayed, order SWR-4821; CS gives receipt **JX-77310**; the supervisor joins and later asks the participant to repeat that receipt number.
- B: bill too high, customer number 7730-19; CS gives ticket **TK-5502**; the supervisor asks for it later.

The repeat question tests whether chat history helps (the report's chat-heavy claim).

## Code map

```
lib/
  app.dart              root: variant switch, fresh services per task (UxHost)
  core/                 models, settings, services (stt, tts, llm, haptics, alerts, storage, scripted)
  ux_kit/               study controller, harness overlay, SUS/TLX, results dashboard
  variant/              VariantSpec, researcher panel and trigger
  variants/v3_board/    ported iteration-3 app (+ thin adapters to shared services)
  variants/v5_chat/     v5 screens, design tokens, copy glossary
assets/scenarios/       role-play scripts (forms A/B)
docs/design-deviations.md   where the build differs from Figma and why
```

## Tests

```bash
flutter test   # SUS/TLX scoring, study controller, scripted partner, OpenRouter parsing
```
