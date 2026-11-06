# Health50 - Functional Specifications

**Version 1 requirements of the iPhone app (stories 1 to 6) are complete.** Stories 7 to 12 describe the analysis skill, agreed in outline on 2026-11-05 and not implemented yet. UX requirements are in [ux.md](ux.md), architecture decisions in [architecture.md](architecture.md).

Intended audience: The owner for use with their own AI tooling, and the general public through a free App Store app. Exports should be usable outside the app with tools chosen by each user. Version 1 uses JSON only. A manual export contains the last 30 days, the last 12 months or the full accessible history in one file and uses a user-selected file location. Automatic uploads use Google Drive and keep the full accessible history there as one file per month, updating only the months that changed. Clinical records are not part of version 1.

## 1. Authorize access to health data

**Description:** As an iPhone user, I want the app to request access to my health data on first launch so that I can export the data I choose to make available.

**Acceptance criteria:**
- On first launch, the app explains the export purpose and requests permission to read all health data types available to this app for that purpose, except clinical records.
- The user controls which requested data they permit the app to read.
- The app can export the data it can read when the user grants only partial access.
- The app requests read access for export; it does not request permission to change health records.
- The app does not claim that all health records are accessible or that an absence of returned records proves no records exist.

## 2. Export health data on demand

**Description:** As a user, I want to initiate an export of my accessible health data so that I have a copy outside the Health app.

**Acceptance criteria:**
- The user can start an export manually.
- For every manual export the user chooses the period: the last 30 days, the last 12 months or the full accessible history. The export includes all supported health data types for that period at the time of that export.
- Each manual export is a single, uncompressed `.json` file that opens without a password.
- The export preserves the meaning of the exported records, including measurement values and units, applicable dates, and available record context.
- The user can tell whether the export completed or failed.

The JSON representation of records is defined in [export-format.md](export-format.md).

**Period choice.** A full-history export of a history of more than ten years measured 2.46 GB on 2026-11-05. That works, but few tools can open a file of that size, so the user chooses the period for every manual export.

## 3. Keep the export current in Google Drive

**Description:** As a user, I want my full accessible history kept current in my chosen Google Drive folder, as one file per month, so my tools can read the latest data and load only the months they need.

**Acceptance criteria:**
- The user connects Google Drive and chooses a destination folder when setting up automatic uploads.
- The app uploads directly from the iPhone to that folder. Health data stays on the device until the user authorizes an export or automatic delivery. No health data passes through a developer server.
- The folder holds one `.json` file per month of health data and one index file that lists them. Each month file is complete on its own, uncompressed, and opens without a password.
- The first successful run uploads all months. Each later run uploads only the months in which data changed, normally the current month.
- A month file is replaced only after its new version has been uploaded successfully. If export generation or upload fails or is interrupted, the previous version of that file remains available and intact.
- After a successful run, the files in the folder together reflect the full accessible history at the time of that run.

## 4. Schedule automatic export and delivery

**Description:** As a user, I want to enable recurring exports at an interval I specify so that my health data is exported and delivered without manually starting each export.

**Acceptance criteria:**
- Automatic export is optional.
- The user can configure and change the recurrence interval, and disable recurring exports.
- The user chooses a whole number of days between exports. The default and minimum are both one day.
- The interval is a target. Actual delivery depends on when iOS allows the app to run, access to health data, and connectivity.
- Automatic uploads use Wi-Fi by default. The user can enable cellular uploads.
- If a run is missed or fails, the app retries when conditions allow. The next successful run brings every affected month up to date and so covers all missed intervals.
- The app shows the time of the last successful delivery and any current problem. It sends a notification only when the user needs to act, such as reconnecting Google Drive.

## 5. Export to a user-selected file location

**Description:** As a user, I want to start an export and choose where to save the file so that I can use the data with my own tools and storage.

**Acceptance criteria:**
- The user can initiate a manual export and choose a destination from the available permitted file locations.
- The user can cancel destination selection without saving an export there.
- Manual file export does not require the user to configure an automatic schedule or connect Google Drive.
- The app reports whether the export was saved successfully to the chosen location; a local save does not imply that a cloud provider has finished uploading it.

**Release consideration.** Manual export supports user-selected, permitted file locations. Whether Apple permits choosing an iCloud Drive folder for this data still needs clarification before iCloud Drive can be advertised as supported.

## 6. Use the export app for free

**Description:** As an iPhone user, I want to download the app for free from the App Store and export my accessible health data for use with tools of my choice.

**Acceptance criteria:**
- The app is offered as a free App Store download for the public.
- The app works without a separate Health50 account. Google sign-in is required only to configure automatic Google Drive uploads.
- The agreed manual and scheduled export capabilities are available without payment to the app provider.
- Exported files can be used independently of the app; they are not restricted to the owner's AI tooling.
- The app is open source. Its source code, privacy policy and support page are public on GitHub, and the app links to the privacy policy and the support page there.
- The app is available in English, German, French, Spanish, Italian and Japanese.

## Analysis skill

Stories 7 to 12 describe a second part of the solution: a skill for an AI assistant that analyses the exported files. It is separate from the iPhone app and runs on the user's computer. Agreed in outline on 2026-11-05; not implemented yet.

## 7. Analyse my exported health data

**Description:** As a user, I want an AI skill to analyse my exported Health50 files so that I learn how my health is and what I can do to improve it.

**Acceptance criteria:**
- The skill is part of the public Health50 repository and open source under the same license. Its instructions are in English.
- The skill works on a folder that holds Health50 files in any mix: full exports, exports of a limited period, month files and the index file.
- On its first run the skill asks for that folder and remembers it. The user can change the folder later.
- If a file in the folder is not available on the computer, for example because a cloud service has not downloaded it yet, the skill says so. It does not treat the file as missing data.
- A record that appears in more than one file is counted once.
- By default the skill analyses the last 12 months and uses older data, where present, for comparison.
- The analysis covers the areas for which the files hold data: activity, heart and fitness, sleep, training, body, mobility, hearing and environment, and mind.
- Each area is judged against the user's own earlier values and against published guidelines. Every guideline used is named with its source.
- The skill never claims that missing data means that nothing exists. A missing data type is reported as "no data or no access".
- The exported records stay on the user's computer. Only a compact summary of them is given to the AI assistant.

## 8. Get the result as short points in the chat

**Description:** As a user, I want the result as a few short points in the chat so that I see the essentials without reading pages of text.

**Acceptance criteria:**
- The chat result consists of short bullet points, not paragraphs.
- It contains one line per area with a rating (good, keep an eye on it, act) and the most important number.
- It contains the three to five recommendations with the most effect. Each one is tied to the user's own numbers and names a measurable target.
- It lists points worth raising with a doctor, if there are any.
- It points to the dashboard for details.
- The user can ask follow-up questions, and the skill answers them from the analysed data.
- The chat result is written in the language the user writes in.

## 9. See the result as a visual dashboard

**Description:** As a user, I want a visual dashboard so that I understand my health at a glance from charts instead of text.

**Acceptance criteria:**
- Every run produces a dashboard as an HTML page that opens in any web browser.
- The dashboard shows as much as possible as charts and uses as little text as possible.
- It shows the rating of every area, the development of the key numbers over time, and the recommendations.
- The page works without an internet connection and loads nothing from the internet.
- The page is stored in the user's folder, next to the exported files.

## 10. Tell the skill about my goals

**Description:** As a user, I want to tell the skill my goals and known health conditions once so that the recommendations fit me.

**Acceptance criteria:**
- On its first run the skill asks for the user's goals and known conditions. Answering is optional.
- The answers are stored on the user's computer and reused in later runs.
- The user can change or delete them at any time.
- Recommendations take them into account, and the result says where they did.

## 11. Follow my progress over time

**Description:** As a user, I want every analysis kept so that I can see my progress and whether the recommendations worked.

**Acceptance criteria:**
- Every run is kept with its date.
- The dashboards of all runs are linked: the user can step back and forth between them and jump to any run.
- A run compares itself with the previous run and shows what improved, what stayed the same and what got worse.
- For every recommendation of the previous run, the next run shows whether the related number moved towards its target.
- The user can delete earlier runs.

## 12. A coach, not a doctor

**Description:** As a user, I want the skill to stay within what it can responsibly say so that I can trust its recommendations.

**Acceptance criteria:**
- The skill gives lifestyle recommendations. It makes no diagnosis and gives no advice on medication.
- Findings that can be serious, for example an irregular ECG classification, are named and referred to a doctor. They are not interpreted.
- The chat result and the dashboard state that the analysis is not medical advice.
- Guideline values come from the list of sources that ships with the skill. The AI assistant does not invent thresholds.

## Reference constraints

- Access is limited to data Apple makes available to this app and the user allows it to read. Read permission cannot be reliably inferred from empty results. [Apple: Authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data).
- Background task launch times are not guaranteed. [Apple: earliestBeginDate](https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate).
- Access to stored health data can be unavailable while the device is locked. [Apple: Protecting access to user health data](https://support.apple.com/guide/security/sec88be9900f/web).
- Apple restricts app storage of personal health information in iCloud. [Apple: App Review Guidelines, 5.1.3](https://developer.apple.com/app-store/review/guidelines/#health-and-health-research).
