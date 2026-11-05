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

**Description:** "Save to Files…" writes the full accessible history as one file (`health50-export.json`) to the location the user chose, in the same format as the month files.

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

**Description:** All app texts live in one String Catalog, [Localizable.xcstrings](Localizable.xcstrings), in English, German, French, Spanish, Italian and Japanese. Keys are stable identifiers; keys that take a value end with the format specifier. The entry `NSHealthShareUsageDescription` belongs in the app's `InfoPlist.xcstrings`.

## To check after implementation

1. **File size.** Measure the real size of the full manual export and of the month files. If the full export is too large, restrict it to a fixed period (for example the last year or the last month).
2. **Google Drive permission.** Check whether "Choose another folder" works well enough with the narrow permission (through Google's own folder picker), or whether it should be removed or the wider permission requested.
3. **Deleted records in old months.** Health reports a deletion only by record ID, without its date. Decide between a small private lookup (record ID to month) on the phone and a periodic full rebuild of all month files.

## Consistency with other specs

[specifications.md](specifications.md) (introduction and stories 1 to 4), [ux.md](ux.md) (requirements 7, 10, 11, 13, 18 and 26) and the v3 mockup were updated on 2026-11-05 to match the monthly-file decision and the exclusion of clinical records.
