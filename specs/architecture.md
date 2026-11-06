# Health50 - Architecture

Status: decisions of 2026-11-05 recorded below, including the approved export format. Three points are deliberately left for after the first implementation (section "To check after implementation").

## Inputs

User-supplied implementation constraints, recorded separately from the functional user stories:

- Bundle identifier: `com.66ideas.health50`.
- Build a native iPhone app targeting iOS 27 and following Apple's platform best practices.

## Decisions

### 1. No clinical records

**Description:** Version 1 does not request or export clinical records. All other record types Health offers to apps are in scope.

### 2. One file per month in Google Drive

**Description:** The automatic export does not upload the full history on every run. The history is split into one JSON file per month (`health50-YYYY-MM.json`) plus one index file (`health50-index.json`). A run rewrites and uploads only the months in which something changed, normally just the current month. Every month file is complete on its own.

**Reason:** iOS gives background work only limited time, and Health data cannot be read while the phone is locked. A full-history export on every run is not reliable under these limits. Monthly files keep each run small.

### 3. Change detection

**Description:** The app remembers per data type how far it has read (Health's own change markers) and asks Health only for what was added or deleted since the last run. From that it works out which months are affected and rewrites those month files from Health.

### 4. Replacing a month file

**Description:** A month file in Google Drive is replaced in place by the new version. There is no separate backup copy. The previous version must stay intact until the new upload has completed; if an upload fails or is interrupted, the old file remains. Whether Google Drive guarantees this for an in-place update is verified during implementation; if not, the app uploads under a temporary name and swaps afterwards.

### 5. Manual export stays one file

**Description:** "Save to Files…" writes one file to the location the user chose, in the same format as the month files. The user picks the period for every save: the last 30 days (`health50-export-30-days.json`), the last 12 months (`health50-export-12-months.json`) or the full accessible history (`health50-export.json`). Each period has its own file name, so saving one period never replaces the file of another. A record belongs to a period when it starts inside it.

### 6. Temporary files are deleted

**Description:** Export files are created in the app's private temporary storage. Each file is deleted as soon as it has been uploaded or saved successfully. Leftovers from failed or interrupted runs are deleted on the next run and when the app starts. The app keeps no copy of exported health data.

### 7. Google sign-in on the phone, no server

**Description:** The user signs in on Google's own page, opened by iOS. Health50 never sees the Google password. Google hands the app an access key that allows only what the user approved. The key is stored in the iPhone's Keychain and nowhere else. There is no Health50 server; all communication goes directly from the phone to Google. If the key stops working (access revoked, password changed, expired), the app shows the "Reconnect Google Drive" state.

### 8. Narrow Google Drive permission to start with

**Description:** The app starts with the narrow Google Drive permission, which lets it work only with files and folders it created itself or that the user explicitly picked. This needs no paid security assessment by Google. The suggested "Health50" folder works fully with it.

### 9. Export format

**Description:** The JSON structure is defined in [export-format.md](export-format.md) (approved on 2026-11-05).

### 10. Open source

**Description:** Health50 is open source under the MIT license, like all 66IDEAS products. The public home is the GitHub repository `66IDEAS/HEALTH50`. The privacy policy ([PRIVACY.md](../PRIVACY.md)) and the support page ([SUPPORT.md](../SUPPORT.md)) live in the root of that repository, and the app links to them there.

### 11. No analytics, advertising or tracking

**Description:** The app contains no analytics, no advertising, no tracking and no third-party code that collects data. This is a promise made in the privacy policy, so every dependency added during implementation must be checked against it.

### 12. Texts and languages

**Description:** All app texts live in one String Catalog, [Localizable.xcstrings](../dev/Health50/Resources/Localizable.xcstrings), in English, German, French, Spanish, Italian and Japanese. Keys are stable identifiers; keys that take a value end with the format specifier. The text iOS shows in the Health permission sheet is in [InfoPlist.xcstrings](../dev/Health50/Resources/InfoPlist.xcstrings).

### 13. Data types come from the SDK

**Description:** The list of exported data types is not kept by hand. A script reads the HealthKit headers of the installed iOS SDK and generates the catalog (121 quantity types and 71 category types for iOS 27.2). A new iOS version only needs a re-run. Data types that need a separate permission per record are left out, because they cannot be requested together with the others: medications and vision prescriptions.

### 14. Implementation choices

**Description:**
- Swift 6 and SwiftUI, no third-party code. The project file is generated with XcodeGen from `dev/project.yml`.
- Export files are written as a stream, so a large history never has to fit into memory. Health is read in pages of 20,000 records.
- Change detection uses Health's own change markers per data type. The first run reads every record once to find the months that hold data.
- The background run is a processing task that iOS schedules; the app does not use Health's background delivery.
- Uploads run inside the app or the background task, not in a separate background transfer. A very large upload that outlives the background task is retried on the next run.

### 15. Analysis skill: where it lives

**Description:** The analysis skill is a folder `skill/health50-analysis/` in the repository: the instructions for the AI assistant (`SKILL.md`), the scripts and the list of guidelines with their sources. A user installs it by copying that folder into the skills folder of their AI assistant. It needs Python, which macOS and Linux bring along, and no other software.

### 16. Analysis skill: the script counts, the AI interprets

**Description:** The export files are far too large for an AI assistant to read (a month is 17 to 68 MB, a full history more than 2 GB). A script reads the files line by line, one record per line as the export format guarantees, and reduces them to a compact summary: values per day and week, trends, the user's usual ranges and the comparison with the guidelines. The AI assistant reads only a digest of this summary, printed by a second script: the statistics without the values of every single day, together with the user's goals, the guidelines and the previous run. All numbers in the result come from the scripts; the AI assistant does not calculate from raw records.

### 17. Analysis skill: what is stored where

**Description:**
- The path of the user's folder is remembered in a small settings file in the user's home folder (`~/.health50/settings.json`). It holds nothing else.
- Everything that concerns the user's health stays in the user's folder, in a subfolder `analysis/`: the goals and conditions (`context.md`), and one subfolder per run, named by its date, with the summary (`summary.json`), the digest the AI assistant read (`digest.json`), the findings of the AI assistant (`findings.json`) and the dashboard (`dashboard.html`). `analysis/index.html` always opens the latest dashboard.
- Deleting the `analysis/` folder removes everything the skill has stored about the user's health.

### 18. Analysis skill: dashboard

**Description:** The dashboard is one self-contained HTML file per run. Charts, styles and data are inside the file. It loads nothing from the internet, so it works offline and sends no data anywhere. The links between runs are plain links between these files. When a new run is added, the dashboards of all runs are built again from their stored summary and findings, so every page knows its neighbours.

### 19. Analysis skill: counting correctly

**Description:**
- Records are identified by their `id`, so a record that is in several files is counted once. Month files take precedence over manual exports. The IDs are compared only for the time spans that more than one file covers, which keeps the memory small even for a history of many years.
- Amounts that several devices record at the same time, such as steps, distance and flights of stairs, are counted from one source per quarter of an hour: the watch first, then the phone, then other apps. Exercise minutes, active energy and stand hours come from the daily totals of the Activity rings, which Health has already cleaned up.
- For values that are averaged per day, such as resting heart rate, the source with the most days in the period is used, and other sources fill its gaps.
- When several apps or devices recorded the same night of sleep, one source per night is used: the one that recorded the most nights in the period, and another one only for nights it missed. A workout that two sources recorded is counted once.
- Days are formed in the time zone of the computer. A night of sleep is not cut at a fixed time of day: records that follow each other form one sleep, and it belongs to the evening it began on. Nights in a far time zone are recognised by their shifted hours; the sleep duration is kept and the bed and wake times are left out, because the local time is unknown. See the open point below.

### 20. Analysis skill: privacy

**Description:** The exported files are read on the user's computer only. The summary, the goals and the conditions are given to the AI assistant the user runs the skill with, and so to the provider of that assistant. The privacy policy gets a section on this when the skill is released.

## To check after implementation

1. **File size.** Measure the real size of the full manual export and of the month files. If the full export is too large, restrict it to a fixed period (for example the last year or the last month). *Measured on 2026-11-05 on a real history of more than ten years: 2.46 GB, written in about 10 minutes. Workout routes are 42% of the file. One recent year is about 350 MB; a month file is 17 MB in the middle and 68 MB at most. Decided on 2026-11-05: the user chooses the period for every manual save (decision 5). A smaller route format is still open.*
2. **Google Drive permission.** Check whether "Choose another folder" works well enough with the narrow permission, or whether it should be removed or the wider permission requested. *Implemented: the app asks for a folder name and creates that folder in My Drive. Not yet tested against Google.*
3. **Deleted records in old months.** Health reports a deletion only by record ID, without its date. Decide between a small private lookup (record ID to month) on the phone and a periodic full rebuild of all month files. *Implemented without a lookup: the current and previous month are rewritten at once, and the next manual upload rewrites every month.*

## Open point for the analysis skill

**Time zone in the export.** All times in the files are UTC, and a file does not say in which time zone the user lives. The skill needs the local day for values such as steps per day or bedtime. Proposal: the app adds the phone's time zone to the header of every file. This is an addition to the approved export format and is not decided yet. Until then the skill uses the time zone of the computer.

Finding of 2026-11-06 on a real history: only a small part of the records carries a time zone of its own, and during travel those few named the home time zone. They are therefore not used. A time zone in the file header would name the zone at the moment of the export only, so it would not help for past travel either. It would still spare the user the assumption that the computer and the phone are in the same time zone.

## Consistency with other specs

[specifications.md](specifications.md) (introduction and stories 1 to 4), [ux.md](ux.md) (requirements 7, 10, 11, 13, 18 and 26) and the v3 mockup were updated on 2026-11-05 to match the monthly-file decision and the exclusion of clinical records.
