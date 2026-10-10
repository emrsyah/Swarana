# v5 design deviations

The app follows `design/v5/screens/*.png`. Where two expert reviews (Deaf accessibility, interaction design) found a problem, the build deviates. Code marks each with a `REVIEW:` comment. Update the Figma to match before submission, since judges compare the Figma, the report and the app.

| Screen | Figma | Implemented | Review finding | Why |
| --- | --- | --- | --- | --- |
| Obrolan header | Red dot + "Mendengarkan…" in every state | Distinct states: listening (pulsing red + live level bars), paused (grey), idle "Tidak merekam", mic unavailable (red) | False "listening" signal is a trust/privacy failure | Deaf users cannot hear whether recording stopped |
| Obrolan "Jeda" | Floating button over messages | Pill button in the header next to status | FAB covered bubble text | Content stays readable |
| Obrolan bubbles | Own = grey, partner = white | Own = light blue tint, partner = white with speaker colour border | Reverses WhatsApp convention | Jakob's law, the report's own rationale |
| Group speakers | Same blue avatar for all | Okabe-Ito colour per speaker, initial or number in avatar, coloured left border | Speakers indistinguishable, not colourblind-safe | Multi-speaker is a headline feature |
| Speaker rename | Pencil icon after every name | Tap the name (48 px target) | Small, noisy target | |
| TTS feedback | "Bunyikan Lagi" looks identical before/during/after | Per-bubble status: Sedang dibunyikan (wave), Sudah dibunyikan (check), Gagal / Volume 0 (red) + "Bunyikan lagi" | User cannot tell if the message was spoken | Visual-verbal parity principle |
| Suggestions | One scrolling row, second chip clipped mid-word, red close X | Chips wrap to all options; neutral close; tap = send, long-press = edit | Hidden options, X signals error | |
| Composer | Text field + send only | Leading board button opens the Kata / Kalimat board | IA lists "template board visual" but no entry existed | Board is the AAC core |
| Simplify / ask AI | Only in Riwayat detail / Transkrip | Long-press menu on every bubble (Bunyikan lagi, Sederhanakan, Tanya arti, Perbaiki, Minta ulangi, Salin); long partner bubbles show a visible Sederhanakan | Needed during live talk | |
| STT errors | No correction | Low-confidence bubble shows "Mungkin kurang tepat, ketuk untuk perbaiki"; menu has Perbaiki tulisan and Minta ulangi | No way to fix mishearing | |
| Save dialog | Simpan / Buang, no cancel or confirm | Batal, primary Simpan, red Buang with confirmation; AI title editable and labelled | Data loss risk | |
| Sidebar | Collapse chevron, primary "Hentikan obrolan" always | App name header, current item highlighted, "Lihat semua", destructive "Akhiri obrolan" only while chatting | Accidental stop, unclear location | |
| Transkrip detail | "Versi Asli" pill + "Ringkasan transkrip" button | One segmented toggle Asli / Sederhana | "Ringkasan" means summary, not simplified | Consistent labels |
| All long text | Justified | Left-aligned | Rivers hurt low-literacy and dyslexic readers | |
| Copy | "handphone", "Putar ulang" vs "Bunyikan Lagi" | "ponsel", one glossary (`lib/variants/v5_chat/copy.dart`) | Inconsistent labels | |
| Secondary text | Light grey | `#5B6270` | Below 4.5:1 contrast | WCAG AA |

## Screens without Figma (design pending)

Built in plain v5 style; please design them:

- Onboarding: microphone permission rationale, denied state, consent notice
- Pengaturan
- Alert banners: noisy, volume low/0, speech while paused, offline, mic denied (plus vibration and edge flash)
- Board sheet (Kata / Kalimat, categories, quick phrases)
- Bubble long-press menu and the "Tanya arti" sheet
- Rename speaker and correct-text dialogs
- Face-to-face mode (top half rotated for the partner) and the intro card
- Empty states: new chat, empty Riwayat tabs, no search results
- Riwayat search
- Paused session state

## Study mode

During A/B tasks v5 hides face mode, quick phrases and the "Mohon tunggu, saya sedang mengetik" offer, because v3 has no equivalent. Kept: history, unified group chat, suggestions, board, simplify, alerts, TTS status. The comparison is "v3 vs v5 as designed".
