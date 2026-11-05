# Health50 Support

Health50 is a free, open-source iPhone app by 66IDEAS that exports the health data you choose as JSON files.

## Getting help

- **Questions and problems:** open an issue at https://github.com/66IDEAS/HEALTH50/issues
- **Email:** hello@66ideas.com

**Never post health data or export files in an issue.** Issues are public. A description of what you did and what happened is enough. If we need more, we will ask you to send it privately.

When you report a problem, these details help:

- the version of Health50 (shown at the bottom of the app's screen);
- your iPhone model and iOS version;
- what the status card at the top of the screen says;
- whether it happened with "Save to Files…" or with the automatic export to Google Drive.

## Common questions

### A data type is missing from my export

Health50 can only export what you allow it to read. In the app, tap "Health data access" and follow the three steps to the Health app, then switch on the missing type. iOS does not tell an app which types were declined, so Health50 cannot point out the missing type itself.

### My export only contains the last 30 days

When iOS asked for permission, "Past 30 Days and Future Data" was chosen instead of "All Recorded Data". Health50 can only export what iOS lets it read. To change it, open the Health app, tap your picture, then Apps, then Health50.

### The app says "No health data found"

Health50 could not read any records. Usually access is turned off in the Health app, or there is no data yet. Tap "Check Health access" and switch on the types you want to export.

### The automatic export did not run today

The interval you set is a target. iOS decides when an app may run in the background, and health data cannot be read while the iPhone is locked. Uploads also wait for Wi-Fi unless you turned on "Use cellular data". The app retries on its own. To update your Google Drive folder right away, open the app and tap "Upload to Google Drive now".

### The app says "Waiting to retry"

An automatic run could not finish for a reason that usually fixes itself, such as no Wi-Fi. You do not need to do anything. The card shows the reason and the time of the last successful delivery.

### The app says "Reconnect Google Drive"

Google no longer accepts the app's sign-in. This happens when you change your Google password, remove the app's access in your Google Account, or after a long time without use. Tap "Reconnect" and sign in again. The files already in your folder are not affected.

### Where are my files?

- **Save to Files…:** in the location you chose in the file picker. The status card names the folder after the save. The file is named `health50-export.json` for the full history, `health50-export-12-months.json` or `health50-export-30-days.json`.
- **Google Drive:** in the folder shown in the "Google Drive" row. It holds one file per month (`health50-YYYY-MM.json`) and an index file (`health50-index.json`).

### What is in the files, and how do I read them?

The files are plain JSON. The structure is described in [specs/export-format.md](specs/export-format.md).

### Are the files encrypted?

No. They are plain JSON so that you can use them with your own tools. Anyone with access to the place where you store them can read them, so choose that place with care.

### "Save to Files…" takes a long time

With the period "Full history", a manual save contains everything in one file. With several years of data this can take ten minutes or more, and the file can be larger than 2 GB. Keep the app open until the ring is complete. If you only need recent data, choose "Last 30 days" or "Last 12 months" in the menu of "Save to Files…".

### How do I stop everything and remove my data?

1. Turn off "Automatic export".
2. Tap the "Google Drive" row and then "Disconnect".
3. Delete the exported files in Google Drive or wherever you saved them. The app does not delete delivered files.
4. Delete the app. This removes everything it stored on your iPhone.

### Which languages does the app support?

English, German, French, Spanish, Italian and Japanese. The app follows the language of your iPhone and uses English for all other languages. The exported files are the same in every language.

## Reporting a security problem

Please do not report security problems in a public issue. Write to hello@66ideas.com instead and describe what you found. We will answer and credit you in the fix if you wish.

## Privacy

See the [Privacy Policy](PRIVACY.md).
