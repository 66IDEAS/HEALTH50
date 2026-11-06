# Health50 - UX Requirements

Status: requirements 1 to 32 (iPhone app) agreed on 2026-11-05. Requirements 33 to 41 (analysis skill) agreed in outline on 2026-11-05. The mockup of the dashboard was agreed on 2026-11-06.

Reference mockup: [mockups/health50-single-screen-v3.html](mockups/health50-single-screen-v3.html) (all eleven states and sheets at iPhone 17 Pro size, light and dark; add `?theme=dark` to the address to open it in dark mode).

Brand assets: `/Volumes/main/git/66ideas/03-brand/kit/logos/health50` (logos) and `/Volumes/main/git/66ideas/03-brand/kit/app-icons/health50` (app icon).

## 1. Single screen

**Description:** The whole app is one vertically scrolling screen. There are no tabs and no separate settings screen. Anything that needs more room (Google Drive setup, Health access guidance) opens as a sheet over this screen. From top to bottom the screen shows: the logo as title, the status card, the manual export actions, the Automatic Export section, the Health Access section and a short privacy note.

## 2. Native iOS look with a brand touch

**Description:** The app uses the standard iOS look: system font, grouped inset lists with rounded cards, capsule-shaped buttons and system switches and steppers. The brand shows in three places only: the accent color, the logo as screen title and the status ring. Everything else looks like a built-in Apple utility.

## 3. Brand color

**Description:** The single accent color is the Health50 blue from the brand kit: `#2E62E8` on light backgrounds and `#7A99F5` on dark backgrounds. It is used for the primary button, switches in the on position, the status ring, icons and tappable text. Filled buttons and switches keep `#2E62E8` with white content in both appearances. Orange is reserved for the needs-attention state.

## 4. Light and dark appearance

**Description:** The app follows the system appearance. Light mode uses the standard light grouped background with white cards. Dark mode uses the standard dark grouped background with dark gray cards. The logo switches between its light and dark versions accordingly.

## 5. Logo as screen title

**Description:** The Health50 wordmark from the brand kit (without the claim) sits at the top left of the main screen in place of a text title. "HEALTH" appears in ink (cream in dark mode) and "50" in the brand blue.

## 6. App icon

**Description:** The app uses the Health50 app icon from the brand kit: the blue "50" on the dark ink background, with the supplied dark and tinted variants.

## 7. Welcome screen on first launch

**Description:** On first launch the user sees one explanation screen before any system dialog. It shows, centered from the top: the app icon, then the Health50 logo with the "by 66IDEAS" claim. Below follow three short points, each with a blue icon, a bold title and one sentence:
- Your health data, as JSON: everything the user allows is exported as plain JSON files for the tools they choose.
- Private by design: data goes straight from the iPhone to the chosen place, with no account and no servers in between.
- Read-only: Health50 only reads and never changes health records.

At the bottom, a short note explains that iOS asks next which health data Health50 may read and that the user can share all or only part of it. A full-width primary button labelled "Continue" opens the iOS Health permission sheet. On iOS 27 that sheet has two steps: which data types to share, then whether to share only the past 30 days or all recorded data. After that the user lands on the main screen. The welcome screen is not shown again.

## 8. Status card

**Description:** A white rounded card directly under the title shows the current state at a glance. It contains a large ring with a symbol in its center, a bold headline and one or two lines of secondary text, all centered. The ring is the main visual element of the app.

## 9. Status: ready to export

**Description:** Before any export has happened, the ring is an empty gray track with a blue export symbol. Headline: "Ready to export". The text invites the user to save a copy now or to let Health50 keep one up to date in Google Drive.

## 10. Status: up to date

**Description:** When the latest delivery succeeded, the ring is fully closed in a blue gradient with a soft blue glow and a checkmark in the center. Headline: "Up to date". Below it the time of the last successful delivery, and a small gray pill with the Google Drive icon and the destination folder. No file size is shown, because the folder holds one file per month.

## 11. Status: needs attention

**Description:** When the user has to act, for example to reconnect Google Drive, the ring turns orange with an exclamation mark. The headline names the action ("Reconnect Google Drive"). The text explains that automatic export is paused and reassures the user that the files from the last successful delivery are still safe in their folder. An orange capsule button inside the card performs the fix in one tap. In the Automatic Export section the Google Drive row shows "Reconnect" in orange.

## 12. Status: export in progress

**Description:** While an export runs, the ring becomes a progress ring that fills clockwise in blue, with the percentage in its center. Headline: "Exporting…". The text asks the user to keep Health50 open until the export is done. The manual export buttons are visible but dimmed and cannot be tapped. There is no cancel button.

## 13. Manual export actions

**Description:** Directly below the status card are the manual actions as full-width capsule buttons:
- "Save to Files…" is the primary button (filled blue, folder icon). It is always visible. Tapping it opens the period menu (requirement 32).
- "Upload to Google Drive now" is the secondary button (light blue tint, blue text, cloud icon). It is only shown once Google Drive is connected. It brings the Google Drive folder up to date right away instead of waiting for the next automatic run.

The two actions are separate buttons. The user is never asked a follow-up question about where the export should go.

## 14. Automatic Export section

**Description:** A section titled "Automatic Export" holds everything about scheduled delivery in one grouped card. Each row has a small colored icon tile on the left. The first row is the "Automatic export" switch. While the switch is off, it is the only row in the card. When the user turns it on, the remaining rows unfold below it: Every, Google Drive and Use cellular data.

## 15. Interval row

**Description:** The row "Every" shows the current interval as text ("1 day", "2 days") next to a minus and plus stepper. The minus button is disabled at 1 day.

## 16. Google Drive row

**Description:** The row "Google Drive" shows the Google Drive icon. Its value on the right shows "Connect" in blue when nothing is connected, the name of the chosen folder when connected, or "Reconnect" in orange when the connection needs attention. A chevron indicates that tapping the row opens the Google Drive sheet (requirement 26).

## 17. Cellular data row

**Description:** The row "Use cellular data" is a switch that is off by default.

## 18. Explanatory text under the Automatic Export section

**Description:** Small gray text under the card explains the current situation in plain words:
- Switch off: automatic export keeps the user's health data current in a Google Drive folder they choose, and Google Drive is connected when turning it on.
- Running: the expected time of the next export, and that the interval is a target because iOS decides when the app may run in the background.
- Needs attention: the time of the last successful delivery, and that Health50 retries as soon as the problem is fixed.

## 19. Health Access section

**Description:** A section titled "Health Access" contains one row, "Health data access", with a heart icon, the value "Manage" and a chevron. Tapping it opens the Health data access sheet (requirement 27). Gray text below explains that Health50 exports only what the user allows it to read, and that a missing data type can be checked here.

## 20. Privacy note

**Description:** At the very bottom of the screen a small lock icon and one sentence state that data goes straight from this iPhone to the user's destination, with no Health50 account and no servers in between.

## 21. Honest wording

**Description:** Texts never claim that all health data was exported or that missing data does not exist. They speak of the data the user allows Health50 to read. Times for automatic exports are worded as expectations ("around tomorrow, 07:00"), not promises.

## 22. Save to Files: location first

**Description:** After the user has picked a period in the menu of "Save to Files…" (requirement 32), the system location picker opens at once, before any waiting. If the user cancels the picker, nothing happens and the screen stays as it was. After the user chooses a location, the status card switches to the export-in-progress state (requirement 12) and the file is written to the chosen place.

## 23. Status: saved to Files

**Description:** When a manual save succeeds, the result is shown on the status card, not in a banner or an alert. The ring closes in blue with a checkmark. Headline: "Saved to Files". Below it the chosen location, and one small line saying that a cloud provider may still be uploading the file. The card keeps this state until the user leaves the app or starts another action, then returns to the regular delivery state.

## 24. Status: manual export failed

**Description:** When a manual save or a manual upload to Google Drive fails, the status card shows it: the ring turns red with a cross, the headline says "Export failed", the text gives the reason in plain words, and a "Try again" capsule button inside the card repeats the action. Red is used only for this state.

## 25. Status: waiting to retry

**Description:** When an automatic export fails for a reason that fixes itself (no Wi-Fi, the phone was locked, iOS gave the app no time), the status card stays calm. The ring stays blue and is shown open, not closed. Headline: "Waiting to retry". The text shows the time of the last successful delivery and the reason in plain words. There is no orange, no button and no notification, because the user does not need to act. Orange stays reserved for cases where the user must act (requirement 11).

## 26. Google Drive sheet

**Description:** Google Drive is set up in a sheet that slides up over the main screen. It opens when the user turns on automatic export without a connection, or taps the Google Drive row.
- Not connected: the sheet explains briefly that Health50 uploads the health data to a folder the user chooses, one file per month, and keeps it current. It shows a "Sign in with Google" button.
- After sign-in: the sheet suggests a new folder named "Health50" in My Drive as the export folder, and offers "Choose another folder" below it. "Done" at the top right confirms and closes the sheet.
- Connected: the sheet shows the signed-in account, the export folder, "Choose another folder" and "Disconnect" (in red, with a confirmation before it takes effect). Small text under the folder says that Health50 keeps one file per month there and updates the months that changed. "Choose another folder" asks for a folder name and creates that folder in My Drive; it does not browse existing folders, because the app can only use folders it created itself.

If the user closes the sheet without finishing the setup, the automatic export switch returns to off.

## 27. Health data access sheet

**Description:** Tapping "Health data access" opens a small sheet over the main screen with "Done" at the top right. It repeats that Health50 only reads the data the user allows, then lists three numbered steps for changing it: open the Health app, tap your picture, choose Apps and then Health50. A full-width button "Open Health" opens the Health app. If there are health data types the app has not asked about yet, the sheet also offers "Review new data types", which shows the iOS permission sheet.

## 28. Languages

**Description:** The app's texts are available in six languages: English, German, French, Spanish, Italian and Japanese. The app follows the iPhone's language and falls back to English for every other language. Dates, times and numbers follow the iPhone's region setting. The logo and the name Health50 are the same in every language. No text may be cut off in any of the six languages: layouts leave room for the longest translation, and button labels may wrap onto a second line where needed. The exported JSON files are identical in every language.

All texts in all six languages are in [Localizable.xcstrings](../dev/Health50/Resources/Localizable.xcstrings), a String Catalog that Xcode opens directly. It uses the wording Apple and Google use themselves for their product names (for example the Health app, the Files app, "Sign in with Google", "My Drive"). One deliberate difference: the interval row is labelled "Every" in English, and with the word for "Interval" in the other five languages, because "every" does not combine with a number in them.

## 29. Asking for notification permission

**Description:** The app asks for permission to send notifications only when automatic export is set up. Right after the user finishes the Google Drive sheet with "Done", one line explains the reason ("Health50 only notifies you when automatic export needs you"), then the iOS notification dialog appears. Users who only export manually are never asked. If the user declines, nothing else changes: problems still show on the status card, and the text under the Automatic Export section adds that notifications are off, so problems are only visible when Health50 is opened.

## 30. Status: no health data found

**Description:** When an export finds no records at all, the status card shows an orange state: the ring turns orange with an exclamation mark and the headline reads "No health data found". The text says that Health50 could not read any data, and that this usually means access is turned off in Health or that there is no data yet. It does not claim to know which of the two is the case. An orange capsule button "Check Health access" opens the Health data access sheet (requirement 27). No empty file is saved or uploaded. This applies to manual and automatic exports alike.

## 31. Privacy policy, support and version

**Description:** At the very bottom of the main screen, under the privacy note (requirement 20), small centered gray text shows two links, "Privacy Policy" and "Support", separated by a dot, and the version number on the line below. The welcome screen (requirement 7) also shows a small "Privacy Policy" link under its note about the iOS permission sheet. Both links open in the in-app browser. There is no separate About screen or section.

The links lead to the two pages in the public GitHub repository:
- Privacy Policy: `https://github.com/66IDEAS/HEALTH50/blob/main/PRIVACY.md`
- Support: `https://github.com/66IDEAS/HEALTH50/blob/main/SUPPORT.md`

Both pages are in English only.

## 32. Period menu for Save to Files

**Description:** Tapping "Save to Files…" opens a standard iOS menu directly at the button. It has the small heading "Period" and three entries: "Last 30 days", "Last 12 months" and "Full history". Tapping an entry continues with the location picker (requirement 22). Tapping outside the menu closes it and nothing happens. The choice is made anew for every save and is not remembered. The menu applies only to "Save to Files…"; the Google Drive folder always holds the full history. "Try again" after a failed save repeats the save with the same period and location.

## Analysis skill

Requirements 33 to 41 describe the analysis skill (stories 7 to 12 in [specifications.md](specifications.md)). Agreed in outline on 2026-11-05.

Dashboard mockup (v1, agreed on 2026-11-06): [mockups/health50-dashboard-v1.html](mockups/health50-dashboard-v1.html). All numbers in it are made up for a fictional person. The run navigation at the top, the values under the pointer and the "Values" button of each chart are live. The switch Auto / Light / Dark in the bar above the logo belongs to the mockup only; the real dashboard follows the computer's setting.

## 33. First run of the skill

**Description:** On its first run the skill asks two things in the chat, one after the other: the folder with the Health50 files, and the user's goals and known conditions. Both questions are short. The second one can be skipped. Later runs ask nothing and start right away. The user can say at any time that the folder or the goals have changed.

## 34. Chat result

**Description:** The result in the chat is short enough to read without scrolling much, at most about 15 lines:
- one sentence that answers "how is my health";
- one line per area: the name of the area, its rating and the most important number;
- three to five recommendations, one line each, with a measurable target;
- points worth raising with a doctor, only if there are any;
- one line that names the dashboard file and says that the analysis is not medical advice.

There are no paragraphs and no tables of raw numbers. If something is unclear, the user asks.

## 35. Ratings

**Description:** Every area has one of three ratings: "good", "keep an eye on it" and "act". A rating is always shown as a word together with a color, never as a color alone: blue for good, orange for keep an eye on it, red for act. An area without enough data has no rating and is shown in gray as "no data or no access".

## 36. Dashboard: one page, mostly charts

**Description:** The dashboard is a single HTML page in the Health50 look: brand blue, the logo at the top left, system font, rounded cards, light and dark appearance following the computer's setting. It reads well on a computer and on a phone. Text is limited to titles, ratings, numbers with units and one short sentence per chart at most. Everything else is shown as a chart.

## 37. Dashboard: overview at the top

**Description:** The top of the page shows the date of the run, the analysed period and one tile per area. Each tile shows the name of the area, its rating, its most important number and a small trend line. Tapping a tile jumps to that area further down.

## 38. Dashboard: one section per area

**Description:** Below the overview follows one section per area with its charts, for example:
- lines over time for values such as resting heart rate or weight, with the user's own usual range as a band and the guideline as a line;
- bars per week for activity, exercise and training;
- a calendar view for values per day, such as steps or sleep duration;
- a chart of bed and wake times for the regularity of sleep.

Every chart shows the unit, and the exact value appears when the user points at or taps a data point.

## 39. Dashboard: recommendations

**Description:** The recommendations are shown as three to five cards. Each card has one short sentence, the current number, the target and a small chart of the related value. From the second run on, each card of the previous run shows whether the number moved towards the target: improved, unchanged or worse.

## 40. Dashboard: moving between runs

**Description:** The top of every dashboard has a "previous" and a "next" control and a list of all runs by date. With them the user steps back and forth between the dashboards of earlier and later runs. Next to the key numbers, every dashboard shows the change since the previous run.

## 41. Dashboard: notice and doctor points

**Description:** If there are points worth raising with a doctor, they appear in their own clearly visible card directly under the overview. The bottom of the page states in one line that the analysis is not medical advice and names the guidelines used with their sources.

## Open points

For the iPhone app: none. All requirements are captured as of 2026-11-05.

For the analysis skill: the dashboard mockup (v1) was agreed on 2026-11-06. It contains four things the requirements above do not state: one sentence as headline, a count of the ratings under it, the recommendations placed above the area sections, and a "Values" button on every chart that shows the numbers as a table. They are part of the agreed design. The first dashboard made from real data adds three more things that are not agreed yet: on a first run the changes compare with the same 30 days a year earlier, because there is no previous run; periods in a far time zone are shaded gray in the sleep and heart charts; and a foldable list "How this was counted" at the bottom names the files read and the sources used. The test of the skill added two more, also not agreed yet: an area that has records but too few to rate is labelled "Not rated" instead of "No data or no access", and the Mind area, which has no charts, lists its records of the period in a card. The fixed labels of the dashboard are English in the first version; the short texts written by the AI assistant follow the user's language.

The reference mockup (v3) does not show: the system location picker in requirement 22 (standard iOS), the confirmation before "Disconnect" in requirement 26, the languages other than English (requirement 28), the notification dialog (requirement 29), the "No health data found" state (requirement 30), the footer links (requirement 31) and the period menu (requirement 32).
