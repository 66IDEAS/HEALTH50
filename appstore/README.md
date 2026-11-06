# App Store submission

Everything that goes into App Store Connect for Health50, and the order of the steps.

| File | Content |
|---|---|
| [texts/](texts/) | Name, subtitle, promotional text, keywords and description in six languages, within Apple's length limits |
| [screenshots/](screenshots/) | Five screenshots per language for the 6.9 inch iPhone slot (1320 x 2868), taken in the simulator with the app's demo states |
| [screenshots-duo/](screenshots-duo/) | Four screenshots per language of the open iPhone Duo (2853 x 2007). Apple shows a badge for apps with iPhone Duo screenshots. The accepted size is not checked against Apple's specification yet: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications |
| [review-notes.md](review-notes.md) | The notes for Apple's reviewer |
| this page | Checklist and the answers for the forms |

The translations of the texts were written by an AI assistant and are not yet checked by
native speakers.

## Checklist

### Before the upload

- [ ] Google Drive tested on a real iPhone with month files of real size and a run in the background
- [x] The app checked on the iPhone Duo simulator, closed and open (see T41 in `specs/tasks.md` for what is not checked)
- [ ] Google consent screen published ("Publish app"), so that people other than the test users can sign in: https://console.cloud.google.com/auth/audience?project=health50
- [ ] Decision on "Choose another folder" (see `specs/tasks.md`)
- [x] Privacy manifest in the app (`dev/Health50/Resources/PrivacyInfo.xcprivacy`)
- [x] Privacy policy and support page reachable without login

### In the Apple developer portal

- [x] Bundle ID `com.66ideas.health50` registered. Xcode did this when the app was first run on the iPhone; the release archive of 2026-11-06 was signed with its team profile. Worth a look that **HealthKit** is ticked: https://developer.apple.com/account/resources/identifiers/list
- [ ] Agreements up to date (the free apps agreement is enough): https://appstoreconnect.apple.com/agreements

### In App Store Connect

Create the app at https://appstoreconnect.apple.com/apps ("+" > New App).

| Field | Value |
|---|---|
| Platform | iOS |
| Name | Health50 |
| Primary language | English (U.S.) |
| Bundle ID | com.66ideas.health50 |
| SKU | health50 |
| Primary category | Health & Fitness |
| Secondary category | Utilities |
| Price | Free |
| Availability | All countries and regions |
| Content rights | Does not contain third-party content |
| Age rating | Answer "None" to every question. "Medical/Treatment Information": None (the app shows no medical information, it exports the user's own data). |
| Privacy Policy URL | https://github.com/66IDEAS/HEALTH50/blob/main/PRIVACY.md |
| Support URL | https://github.com/66IDEAS/HEALTH50/blob/main/SUPPORT.md |
| Marketing URL | https://github.com/66IDEAS/HEALTH50 |
| Copyright | 2026 Alexander Ilg |
| Export compliance | The app uses only the encryption of the operating system (HTTPS). `ITSAppUsesNonExemptEncryption` is set to `false` in the app, so no question should appear. |
| EU trader status | Your declaration. Health50 is free, has no purchases and no advertising. |

Add the languages German, French, Spanish (Spain), Italian and Japanese, and paste the
texts and upload the screenshots of each.

### App Privacy

Answer: **"No, we do not collect data from this app."**

Reasoning, to be confirmed by you as the publisher: Apple counts data as collected when it
is sent off the device in a way that lets the developer or the developer's partners access
it. Health50 sends nothing to 66IDEAS. Exports go to a file location or to the user's own
Google Drive, on the user's request, and the app contains no third-party code. The Google
account's email address is shown in the app and stays on the device.

### Upload and review

- [ ] Archive in Xcode (Product > Archive) with your team selected, then "Distribute App > App Store Connect"
- [ ] Install the build through TestFlight on your iPhone and run through the test of the review notes
- [ ] Select the build in the version, paste the review notes, submit for review

## Version

Version 1.0, build 1 (`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `dev/project.yml`).
Every upload needs a higher build number.
