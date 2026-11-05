# Health50 Privacy Policy

Last updated: 5 November 2026

Health50 is an iPhone app that exports the health data you choose as JSON files. It is published by 66IDEAS, a non-commercial open-source project.

## The short version

- Health50 has no servers and no user accounts. 66IDEAS never receives your health data or any other personal data from the app.
- The app reads only the health data you allow, and it only reads. It never changes your health records.
- Your data leaves your iPhone only when you export it, and only to the place you choose: a file location you pick, or your own Google Drive.
- The app contains no analytics, no advertising and no tracking.

## Who is responsible

66IDEAS is a non-commercial open-source project based in Switzerland.

Contact: hello@66ideas.com

## What the app reads

Health50 asks iOS for permission to **read** the health data stored in the Health app on your iPhone. You decide in the iOS permission sheet which types of data the app may read, and you can change this at any time in the Health app.

- The app never asks for permission to write, and it never changes or deletes anything in Health.
- Version 1 does not read clinical records.
- iOS does not tell the app which types you declined. The app only sees the data it is allowed to read.

## What happens to your health data

Everything happens on your iPhone.

- When you start an export, or when an automatic export runs, the app reads the permitted data and writes it into JSON files in its private temporary storage.
- Each file is deleted from that storage as soon as it has been saved or uploaded. Files left over from a failed run are deleted on the next run.
- The app keeps no copy of your health data.

The app stores a small amount of technical information on your iPhone so that it can work:

- your settings, such as the export interval and whether cellular data may be used;
- markers that record how far the app has read in Health, so that the next run only looks at what changed;
- the time and result of the last export;
- if you connect Google Drive: the sign-in key from Google, kept in the iPhone's Keychain, plus the name of your export folder and your Google account's email address.

None of this is sent to 66IDEAS.

## Where your data goes

Your data goes only where you send it.

**Save to Files.** The app writes one JSON file to the location you choose in the iOS file picker. If that location belongs to a cloud service you have set up on your iPhone, that service then handles the file under its own terms and privacy policy.

**Google Drive.** If you turn on automatic export, the app uploads JSON files directly from your iPhone to a folder in your own Google Drive. The upload does not pass through any server of 66IDEAS, because there is none. Google stores the files under its own terms and privacy policy.

**The files are not encrypted.** Exported files are plain JSON so that you can use them with your own tools. Anyone who has access to the place where you store them can read them. You decide who that is.

## Google account and Google Drive

Connecting Google Drive is optional and only needed for automatic export.

- You sign in on Google's own page. Health50 never sees your Google password.
- Google gives the app a sign-in key that allows only what you approved. The key is stored in the iPhone's Keychain and nowhere else.
- The app receives your Google account's email address in order to show you which account is connected.
- The app can only work with the files and folders it created itself or that you explicitly picked. It cannot see the rest of your Google Drive.
- The app uses this access for one purpose: to store and update your export files in your Google Drive. It does not transfer information received from Google to anyone, does not use it for advertising, and no person at 66IDEAS can see it.

Health50's use and transfer to any other app of information received from Google APIs will adhere to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements.

You can end the connection at any time: tap "Disconnect" in the app, or remove Health50 under "Third-party apps and services" in your Google Account. The files already in your Google Drive stay there until you delete them yourself.

## What the app does not do

- No analytics and no usage statistics.
- No advertising, and no use of health data for advertising or similar purposes.
- No tracking across apps or websites.
- No selling or sharing of data with anyone.
- No third-party code that collects data.

## Notifications

If you allow notifications, the app shows a notification only when automatic export needs you, for example to reconnect Google Drive. Notifications are created on your iPhone. No notification server is involved.

## Crash reports from Apple

If you have chosen in the iOS settings to share analytics with app developers, Apple may provide 66IDEAS with anonymous crash and performance reports for the app. These reports come from Apple, not from the app itself, and they contain no health data.

## Your control

- **Change what the app may read:** in the Health app, tap your picture, then Apps, then Health50.
- **Stop automatic export:** turn off the switch in the app.
- **Disconnect Google Drive:** tap "Disconnect" in the app.
- **Delete exported files:** delete them in the place where you stored them. The app does not delete files it has already delivered.
- **Remove everything the app stored on your iPhone:** delete the app.

Because 66IDEAS does not receive or store your data, there is nothing we could look up, correct or delete on your behalf. Your data stays under your control on your device and in the places you chose.

## If you contact us

If you write to hello@66ideas.com or open an issue on GitHub, we use what you send only to answer you. Issues on GitHub are public and are handled by GitHub under its own privacy statement. Please never post health data or export files in an issue.

## Children

Health50 is not directed at children.

## Open source

The source code of Health50 is public under the MIT license at https://github.com/66IDEAS/HEALTH50. Anyone can check that the app does what this policy says.

## Changes to this policy

If the policy changes, the new version is published in the same place and the date at the top is updated. Earlier versions remain visible in the history of the repository.
