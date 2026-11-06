# Health50 - Tasks

Source requirements:
- **F1 to F12**: user stories in [specifications.md](specifications.md)
- **U1 to U41**: UX requirements in [ux.md](ux.md)
- **A1 to A20**: decisions in [architecture.md](architecture.md), plus the export format in [export-format.md](export-format.md)

The tasks of the iPhone app belong to version 1 and are not split into phases. The tasks of the analysis skill (T32 to T40) come after it.

A checked box means the task is implemented in `dev/`. What was actually verified, and what was not, is listed under "Verification" below.

## Foundation

- [x] **T01 Project setup** - Xcode project in `dev/` (generated with XcodeGen), bundle identifier `com.66ideas.health50`, iPhone only, iOS 27, HealthKit capability, background task registration, no third-party code. (Inputs, A10, A11)
- [x] **T02 Brand assets** - app icon with dark and tinted variants, logo with and without claim in light and dark, brand blue as accent color. (U3, U4, U5, U6)
- [x] **T03 Texts** - String Catalog with six languages in the app, permission text in `InfoPlist.xcstrings`. (U28, A12)

## Health data

- [x] **T04 Data type catalog** - all non-clinical data types, generated from the iOS 27 SDK. (F1, A1)
- [x] **T05 Read-only authorization** - request read access on first launch, never write access. (F1)
- [x] **T06 JSON stream writer** - writes large files without holding them in memory. (A9)
- [x] **T07 Record encoding** - quantities, categories, workouts with routes, correlations, ECGs, heartbeat series, audiograms, states of mind, activity summaries, profile and sources as defined in the export format. (F2, A9)

## Manual export

- [x] **T08 Full export** - full accessible history in one file `health50-export.json`. (F2, A5)
- [x] **T09 Save to Files flow** - location picker first, then progress, then result on the status card. (F5, U13, U22, U23, U24)
- [x] **T10 Temporary file cleanup** - delete after success, after failure and on app start. (A6)

## Automatic export

- [x] **T11 Month files and index** - `health50-YYYY-MM.json` and `health50-index.json`. (F3, A2)
- [x] **T12 Change detection** - only months with changes are rewritten. (A3)
- [x] **T13 Google sign-in** - sign-in on Google's page, key in the Keychain, no server. (F3, A7)
- [x] **T14 Google Drive client** - narrow permission, export folder, upload, replace in place. (F3, A4, A8)
- [x] **T15 Drive sync run** - generate, upload and delete each changed month, then the index. (F3, F4)
- [x] **T16 Scheduling** - interval in days, background runs, Wi-Fi by default, optional cellular, retry. (F4)
- [x] **T17 Notifications** - ask after setup, notify only when the user must act. (F4, U29)

## User interface

- [x] **T18 App state** - one model that drives all status states. (U8 to U12, U23, U24, U25, U30)
- [x] **T19 Welcome screen** (U7)
- [x] **T20 Main screen structure** - single scrolling screen, logo title, light and dark. (U1, U2, U4, U5)
- [x] **T21 Status card and ring** (U8 to U12, U23, U24, U25, U30)
- [x] **T22 Manual action buttons** (U13)
- [x] **T23 Automatic Export section** - switch, interval, Google Drive row, cellular switch, explanatory text. (U14 to U18)
- [x] **T24 Google Drive sheet** (U26)
- [x] **T25 Health Access section and sheet** (U19, U27)
- [x] **T26 Privacy note and footer links** (U20, U31)
- [x] **T27 Honest wording** - no claim of completeness anywhere. (U21)

## Changes after the first test on a real iPhone

- [x] **T31 Period menu for Save to Files** - menu with "Last 30 days", "Last 12 months" and "Full history", a file name per period, `kind` "range" in the export format, texts in six languages, four more unit tests. (F2, U13, U22, U32, A5)

## Analysis skill

Started on 2026-11-06 with the summary script and the dashboard. Requirements: F7 to F12, U33 to U41, A15 to A20.

- [x] **T32 Dashboard mockup** - HTML mockup of the dashboard with sample data. (U35 to U41) Version 1: `specs/mockups/health50-dashboard-v1.html`, checked in light and dark appearance and at phone width. Agreed on 2026-11-06.
- [x] **T33 Summary script** - reads all Health50 files of a folder line by line, counts each record once, forms local days and writes the compact summary. (F7, A16, A19) `skill/health50-analysis/scripts/summarize.py`. Run on 2026-11-06 on a real history of more than ten years (a full export of 2.46 GB and an export of 30 days in one folder): about 6 seconds, records that are in both files are counted once.
- [ ] **T34 Guidelines with sources** - the list of guideline values the skill may use. (F7, F12) Draft with six entries in `skill/health50-analysis/guidelines.json`. Every entry still has to be checked against its source document.
- [x] **T35 Skill instructions** - first run with folder and goals, the chat result, follow-up questions, the limits. (F8, F10, F12, U33, U34) `skill/health50-analysis/SKILL.md` with two reference files (`references/digest.md`, `references/findings-format.md`) and `scripts/digest.py`, which prints what the AI assistant reads. Tested on 2026-11-06: an AI agent that knew only the skill folder ran it from the first question to the chat result and the dashboard on a real history, and reported 34 points. The defects and the unclear rules among them are corrected (E9 to E12). The corrected instructions have not been run by a fresh agent again.
- [x] **T36 Dashboard** - self-contained HTML page with the charts per area and the recommendations. (F9, U35 to U39, U41, A18) Page template `skill/health50-analysis/assets/dashboard-template.html` (made from the agreed mockup) and `scripts/build_dashboard.py`. Checked on 2026-11-06 with real data at desktop and phone width.
- [ ] **T37 Runs and progress** - one folder per run, comparison with the previous run, navigation between dashboards. (F11, U40, A17) Implemented in `build_dashboard.py`, `digest.py` and the page template. Tested on 2026-11-06 with a made-up earlier run: the links between the runs, the changes since the previous run and the state of each recommendation (improved, unchanged, worse) work. Not tested yet with two real runs some weeks apart.
- [ ] **T38 Test with real exports** - a full export, a limited period and month files in one folder. Done on 2026-11-06 for a full export together with an export of 30 days. Month files and the index file are not tested, because automatic export has not produced any yet.
- [ ] **T39 Privacy policy and README** - section on the skill. (A20) The README describes the skill and what reaches the AI assistant (2026-11-06). The privacy policy has no section on the skill yet.
- [ ] **T40 Decide the time zone in the export** - open point in the architecture. Finding of 2026-11-06 recorded there: a time zone in the file header would not help for past travel.

## Verification

- [x] **T28 Unit tests** - 26 tests for the JSON writer, month handling, sync planning, the data type catalog, the index file, outcome handling and the export period. All pass.
- [x] **T29 Run in the simulator** - built and run on the iPhone 17 Pro simulator with iOS 27.2.
- [ ] **T30 Checks after implementation** - partly done, see below.

### Verified in the simulator

- Build without errors or warnings in Swift 6 mode.
- All screens and states in light mode, three of them also in dark mode, compared with mockup v3.
- First launch for real: welcome screen, the iOS Health permission sheet (205 data types, read access only), then the main screen.
- "Save to Files…" for real, with test data written by `dev/Tools/HealthSeeder`: location picker first, progress, "Saved to Files". The file was checked with a strict JSON parser: 356 records with the expected units, value names, a workout with events and a 60 point route, a blood pressure pair and the source table.
- Saving again replaces the file instead of adding a second one.
- No temporary file is left in the app after an export.
- The monthly export for real, into a local folder instead of Google Drive (`-debugLocalSync YES`): three month files and the index, all valid, record counts matching. A second run rewrote only the index.

### Verified on a real iPhone

An iPhone with iOS 27.0.1 and a real health history of more than ten years, on 2026-11-05.

- The app is signed with the HealthKit capability, installs and starts.
- "Save to Files…" with the full history into iCloud Drive: several million records in one file of 2.46 GB, written in about 10 minutes.
- The file is valid under a strict JSON parser. Every record has an ID, a start and a source that exists in the source table. There are no duplicate records.
- Record types the seeding tool cannot write were checked against real records, as far as the history contained them, and were correct.
- The app's working copy on the phone was deleted after the save.
- The period menu with "Last 30 days" into the same iCloud Drive folder: `health50-export-30-days.json` with 35.4 MB, written in under a minute. The file is valid under a strict JSON parser, has no duplicate records, and no record starts before the start of the period. It holds one activity summary per day. The full export next to it was left untouched.

### Not verified

- **Google sign-in and upload to Google Drive.** They need a Google client ID, which does not exist yet (see `dev/README.md`). The code compiles and its error handling is unit-tested, but it has never talked to Google.
- **Background runs.** iOS only schedules them on a real device over time.
- **Notifications** and the permission dialog after Drive setup, because they follow the Drive setup.
- **Languages other than English.** The texts are in the app, but no screen was looked at in the other five languages, so text that is too long has not been ruled out.
- **Record types that did not occur in the test history.** Their encoding compiles against the SDK but has not run against real records.
- **The monthly export on a real iPhone.** It was only run in the simulator.
- **The period "Last 12 months".** It uses the same code as "Last 30 days" with a different start, but was not run.
- **The fix for E4** on the real iPhone, because that needs another full-history export there. A limited period never reaches back to 1969.

### T30 Checks after implementation

1. **File size:** measured on a real history of more than ten years: 2.46 GB, on average 293 bytes per record. Workout routes are 1.04 GB of it (187 bytes per GPS point, 42% of the file). A plain record without a route takes about 170 bytes. One year of recent data is about 350 MB. A month file would be 17 MB in the middle and 68 MB at most. The last 30 days are 35 MB. The first estimate of 500 MB was too low. Decided: the user chooses the period for every manual save (T31). A smaller route format is still open.
2. **Google Drive permission:** implemented with the narrow permission. "Choose another folder" asks for a folder name and creates that folder in My Drive, because the app cannot browse folders it did not create. Whether this is good enough still needs a decision once Drive can be tested.
3. **Deleted records in old months:** implemented without a lookup table. When Health reports deletions, the current and previous month are rewritten at once, and the next manual "Upload to Google Drive now" rewrites every month.

## Errors found during development

All fixed.

- [x] **E1 Trailing comma in exported JSON.** The stream writer wrote a comma before closing brackets. Apple's parser accepted it, so the first unit test passed; a strict parser rejected the real export. Fixed in the writer, and the tests now check for it explicitly.
- [x] **E2 One data type did not resolve.** Apple renamed "environmental audio exposure event" but kept the old stored identifier, so the generated catalog pointed at a type that does not exist. Fixed in the generator; a test now checks that every listed type resolves.
- [x] **E3 Folder name after saving.** Saving to the top level of the phone's storage showed the internal name "File Provider Storage". It now shows "On My iPhone" in the app's language.
- [x] **E4 Empty activity entries dated 1969.** Health returned two empty placeholder activity summaries for 30 and 31 December 1969. They were exported, so the file claimed to start in 1969, and the monthly export would have created a file for December 1969. Activity summaries before 2014, the year Health was introduced, are now skipped. Found on the real iPhone.
- [x] **E5 Xcode changed the text catalog on every build.** Building in Xcode added empty entries to the String Catalog. The automatic text extraction for SwiftUI is now switched off, because all keys are maintained by hand.
- [x] **E6 Nights were cut in two when the user was in a far time zone.** The summary script first cut nights at 18:00 in the computer's time zone. A night slept many hours east or west of home crosses that line and becomes two short nights. Sleep is now found without a fixed time of day, and nights in a far time zone are recognised by their shifted hours.
- [x] **E7 The sleep stages bar lost its style in the page template.** The helper that made the template from the mockup removed one style rule too many. Fixed in the helper and the template.
- [x] **E8 The trend line of a recommendation ran out of its card.** With long numbers such as "6 h 42 min" the small chart next to them had no room. The numbers and the chart now wrap. Fixed in the mockup and the page template.
- [x] **E9 The Mind area could never be rated in the dashboard.** It has no charts, and the page took "no charts" for "no records". It now counts questionnaires, mood logs and mindfulness sessions of the period, lists them in a card, and shows an area that has records but no rating as "Not rated".
- [x] **E10 Numbers per week differed between chat and dashboard.** The instructions allowed two ways to state a number per week, and the summary counted 52 weeks where the dashboard shows the 51 complete weeks of the period. There is now one rule (the mean of the last 30 days, times seven) and one set of weeks.
- [x] **E11 The day of the export was counted for events and workouts but not for the daily values.** The period now ends on the last complete day everywhere.
- [x] **E12 A travel period with shifts in both directions was reported as shifted by one hour.** The shift is now the mean distance from the usual hours, whatever the direction.
