# v5 design deviations

The app follows `design/v5/screens/*.png`. Where two expert reviews (Deaf accessibility, interaction design) found a problem, the build deviates. Code marks each with a `REVIEW:` comment. Update the Figma to match before submission, since judges compare the Figma, the report and the app.

| Screen | Figma | Implemented | Review finding | Why |
| --- | --- | --- | --- | --- |
| Obrolan header | Red dot + "Mendengarkan…" in every state | Distinct states: listening (pulsing red + live level bars), paused (grey), idle "Tidak merekam", mic unavailable (red) | False "listening" signal is a trust/privacy failure | Deaf users cannot hear whether recording stopped |
| Obrolan "Jeda" | Floating button over messages | Pill button in the header next to status | FAB covered bubble text | Content stays readable |
| Obrolan bubbles | Own = grey (blue outline while spoken), partner = white | Matches Figma (2026-11 alignment pass) | | |
| Group speakers | Pembicara 1 blue, Pembicara 2 green, person avatar | Matches Figma; further speakers get orange, purple, pink, teal (all 4.5:1 on white) | | |
| Speaker rename | Pencil icon after every name | Pencil kept as in Figma; name + pencil is one 48 px target | Small, noisy target | |
| TTS feedback | "Sedang disuarakan" pill, "Sudah disuarakan" + "Suarakan lagi" | Matches Figma, plus red Gagal / Volume 0 state | User cannot tell if the message failed | Visual-verbal parity principle |
| Suggestions | "Rekomendasi Balasan" with chevron; one scrolling row, chip clipped mid-word | Chevron folds the panel as in Figma; chips wrap to show all options; tap = send, long-press = edit | Hidden options | |
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
