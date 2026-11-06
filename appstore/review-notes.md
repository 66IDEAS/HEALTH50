# Notes for App Review

Paste the block below into "App Review Information > Notes" in App Store Connect. No sign-in
is required, so the "Sign-in required" box stays unticked.

```
Health50 exports the health data the user chooses from the Health app as plain JSON files.
It has one screen. There is no Health50 account and no server of ours; nothing needs a login
to be reviewed.

HOW TO TEST
1. Launch the app and tap Continue. iOS shows the Health access sheet. Turn on the data
   types to share (or "Turn On All") and tap Allow.
2. Tap "Save to Files…", pick a period, then pick a location. The app writes one JSON file
   there and shows "Saved to Files" with the folder and the size.
3. Optional: turn on "Automatic export". The app asks to sign in with Google (any Google
   account) and then keeps one JSON file per month in a folder "Health50" in that account's
   Google Drive.

IF THE TEST DEVICE HAS NO HEALTH DATA
The app then shows "No health data found". That is the correct behaviour: it can only
export what the Health app holds. To see an export, add a value in the Health app first,
for example Browse > Body Measurements > Weight > Add Data, then tap "Save to Files…" again.

HEALTHKIT
- The app only reads from HealthKit. It requests no write access and never changes health
  records.
- Health data is used for one purpose: to write it into the export files the user asks for.
  It is not used for advertising or analytics, and it is not sent to us or to any third
  party of ours. The app contains no analytics, advertising or tracking code and no
  third-party SDK.
- The app does not store health data in iCloud. "Save to Files…" uses the system file
  picker, and the user chooses the location.
- Exported files leave the device only to the destination the user chooses: a file location,
  or the user's own Google Drive.

GOOGLE SIGN-IN
Google sign-in is used only to let the user upload their export to their own Google Drive.
It is not a login to Health50 and creates no account with us, so we understand that
guideline 4.8 (login services) does not apply. The app requests the narrow Google Drive
permission (drive.file): it can only work with the files and folders it created itself.

BACKGROUND
The app uses a background processing task (BGProcessingTask) to keep the Google Drive export
current when automatic export is on. It runs only when the user has switched that on.

OPEN SOURCE
Source code, privacy policy and support page: https://github.com/66IDEAS/HEALTH50
Contact: hello@66ideas.com
```

## Before you paste it

- Step 3 works for the reviewer only when the Google consent screen is published. While it
  is in "Testing", only the listed test users can sign in.
- Check that hello@66ideas.com is read by someone.
