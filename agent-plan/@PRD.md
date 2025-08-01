# AAC Application – MVP Product Requirements Document (PRD)

## 1. Purpose
Build an Augmentative and Alternative Communication (AAC) mobile application that empowers Deaf and Hard-of-Hearing (DHH) users to communicate quickly and naturally via an interactive word board, predictive suggestions, speech recognition, and customizable “decks” of words or sentences.

## 2. Goals & Success Metrics
| Goal | Success Metric | Target |
|------|---------------|--------|
| Enable rapid sentence construction | Median time to create & speak a 5-word sentence < **15 sec** | 80 % of test users |
| Improve communication clarity | User-reported clarity rating ≥ **4 / 5** | Post-session survey |
| Reduce effort vs. typing | % of interactions using board taps vs. manual typing ≥ **70 %** | In-app analytics |
| Early retention | Day-7 retention ≥ **40 %** | Cohort analysis |

## 3. User Personas
1. **Alex (12)** – late-deafened, enjoys visual cues and haptic feedback; uses tablet.  
2. **Sam (31)** – profoundly Deaf, ASL fluent, needs quick text-to-speech for encounters with hearing people.  
3. **Jordan (65)** – hard-of-hearing senior, prefers larger buttons and simple UI.

## 4. User Stories (MVP)
1. *As Alex*, I tap words on a board and feel a vibration + hear TTS so I know each word was added.
2. *As Sam*, I press “Speak Sentence” and the phone voices my constructed sentence.
3. *As Jordan*, I delete the last word if I tapped the wrong one.
4. *As any user*, I type in the input box and receive word suggestions to finish faster.
5. *As any user*, I speak into the mic to convert speech to text in the sentence field.
6. *As power user*, I create a new custom deck for grocery shopping terms.

## 5. Functional Requirements

### 5.1 Interactive Word Board
FR-1  Display a grid of pre-made word tiles (text + optional icon).  
FR-2  Tapping a tile:
 a. Appends the word to the sentence field (space-delimited).  
 b. Triggers device haptic feedback.  
 c. Plays immediate TTS of the tapped word.  

### 5.2 Sentence Construction & Playback
FR-3  Show dynamic sentence field above the board.  
FR-4  “Speak” button voices the entire sentence using TTS.  
FR-5  Backspace button removes the last word and provides subtle haptic feedback.  
FR-6  Clear-all gesture or long-press on backspace empties the sentence.

### 5.3 Manual Input & Suggestions
FR-7  Text input field supports system keyboard.  
FR-8  Real-time suggestion bar (up to 3 words) based on current context.  
FR-9  Selecting a suggestion adds it to the sentence like a normal word tap.

### 5.4 Speech Recognition
FR-10 Mic button toggles speech-to-text.  
FR-11 Recognized text inserts at cursor in the sentence field.  
FR-12 If SR fails (>3 sec silence or error), show non-blocking toast.

### 5.5 Deck System
FR-13 Default deck (“Core Words”) ships with ~100 common words & 10 short sentences.  
FR-14 Deck Manager screen lists decks with add, rename, delete actions.  
FR-15 Word/Sentence Editor:
 a. Add new word or sentence.  
 b. Assign/change icon (emoji or uploaded image).  
 c. Reorder items via drag-and-drop.  

### 5.6 Common Sentences
FR-16 Tiles flagged as “sentence” speak immediately when tapped (optional: still append to sentence field depending on user setting).

## 6. Non-Functional Requirements
NFR-1  Support iOS 14+ and Android 8+.  
NFR-2  Local-first; all core features work offline once assets are cached.  
NFR-3  Average tap-to-response latency < 100 ms (haptic + TTS start).  
NFR-4  WCAG AA color-contrast & scalable text for accessibility.  
NFR-5  English language only for MVP; architecture allows localization.  
NFR-6  Data stored on-device; no account required.

## 7. Technical Notes
• Flutter chosen for cross-platform parity and fast iteration.  
• Use platform TTS engines (Android `TextToSpeech`, iOS `AVSpeechSynthesizer`).  
• Haptics via Flutter’s `HapticFeedback`.  
• Speech-to-text: leverage on-device APIs (`speech_to_text` plugin).  
• Predictive suggestions: basic n-gram model seeded from default corpus; replaceable later with ML service.  
• Deck data persisted in local SQLite via `sqflite` or lightweight NoSQL (`hive`).  
• Icons stored as SVG/PNG or Emoji; provide fallback glyph.

## 8. MVP Out-of-Scope (Phase 2+)
• Adaptive UI that listens to partner’s speech.  
• TV Mode with audio recognition of media.  
• Cloud sync or user accounts.  
• Multi-language packs.  
• Analytics beyond basic event logging.

## 9. Milestones & Timeline (tentative)
| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Tech Spike | 1 wk | Evaluate TTS/SR plugins, latency tests |
| Alpha | 4 wks | Word board, sentence field, TTS, basic deck, manual typing |
| Beta | 3 wks | Suggestions, SR, deck manager, icons |
| Polish & QA | 2 wks | Accessibility, performance, bug fixes |
| Launch | – | MVP released on App Store & Play Store |

## 10. Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|-----------|
| SR accuracy in noisy environments | Medium | Allow manual correction; guidance to users |
| TTS latency on low-end devices | High | Cache short audio clips; pre-warm engine |
| UI overload from many tiles | Medium | Pagination or folders; user customization |

## 11. Open Questions
1. Preferred device orientations? (Portrait only vs. landscape/desktop)  
2. Do we need child-safety or profanity filtering for TTS?  
3. Should common sentence tiles append to field or speak instantly?  
4. Any specific analytics KPIs to track beyond the metrics above?  
5. Asset licensing for icon library—can we use open-source sets or require custom art? 