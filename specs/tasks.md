# Health50 - Tasks

Source requirements:
- **F1 to F6**: user stories in [specifications.md](specifications.md)
- **U1 to U31**: UX requirements in [ux.md](ux.md)
- **A1 to A12**: decisions in [architecture.md](architecture.md), plus the export format in [export-format.md](export-format.md)

All tasks belong to version 1. They are not split into phases.

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

## Verification

- [x] **T28 Unit tests** - 22 tests for the JSON writer, month handling, sync planning, the data type catalog, the index file and outcome handling. All pass.
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

### Not verified

- **Google sign-in and upload to Google Drive.** They need a Google client ID, which does not exist yet (see `dev/README.md`). The code compiles and its error handling is unit-tested, but it has never talked to Google.
- **Background runs.** iOS only schedules them on a real device over time.
- **Notifications** and the permission dialog after Drive setup, because they follow the Drive setup.
- **Languages other than English.** The texts are in the app, but no screen was looked at in the other five languages, so text that is too long has not been ruled out.
- **Record types the seeding tool cannot write:** ECGs, heartbeat series, audiograms, states of mind, scored assessments, activity summaries and the profile. Their encoding compiles against the SDK but has not run against real records.
- **A real iPhone and a real, large health history.**

### T30 Checks after implementation

1. **File size:** measured with test data at about 180 bytes per record. A history of three million records would give a full export of roughly 500 MB, and a typical month a few MB. This is an estimate; the real size needs a real history.
2. **Google Drive permission:** implemented with the narrow permission. "Choose another folder" asks for a folder name and creates that folder in My Drive, because the app cannot browse folders it did not create. Whether this is good enough still needs a decision once Drive can be tested.
3. **Deleted records in old months:** implemented without a lookup table. When Health reports deletions, the current and previous month are rewritten at once, and the next manual "Upload to Google Drive now" rewrites every month.

## Errors found during development

All fixed.

- [x] **E1 Trailing comma in exported JSON.** The stream writer wrote a comma before closing brackets. Apple's parser accepted it, so the first unit test passed; a strict parser rejected the real export. Fixed in the writer, and the tests now check for it explicitly.
- [x] **E2 One data type did not resolve.** Apple renamed "environmental audio exposure event" but kept the old stored identifier, so the generated catalog pointed at a type that does not exist. Fixed in the generator; a test now checks that every listed type resolves.
- [x] **E3 Folder name after saving.** Saving to the top level of the phone's storage showed the internal name "File Provider Storage". It now shows "On My iPhone" in the app's language.
