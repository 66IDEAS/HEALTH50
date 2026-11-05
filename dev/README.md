# Health50 - reference implementation

Native iPhone app for iOS 27, written in Swift 6 and SwiftUI. No third-party code.

## Build and run

Requirements: Xcode 27 or later. [XcodeGen](https://github.com/yonaskolb/XcodeGen) only if you change `project.yml`.

```bash
cd dev
xcodebuild -project Health50.xcodeproj -scheme Health50 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project Health50.xcodeproj -scheme Health50 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Or open `Health50.xcodeproj` in Xcode and run the `Health50` scheme. For a real iPhone, select your development team under Signing & Capabilities.

After changing `project.yml`, regenerate the project with `xcodegen generate`.

## Google Drive setup

Automatic export needs a Google OAuth client ID. Without one the app builds and runs, and "Sign in with Google" reports that sign-in is not set up.

1. In the Google Cloud console, create a project and enable the **Google Drive API**.
2. Configure the consent screen with the scope `https://www.googleapis.com/auth/drive.file`.
3. Create an OAuth client ID of type **iOS** for the bundle identifier `com.66ideas.health50`.
4. Put the client ID into `Config/Health50.xcconfig` as `GOOGLE_CLIENT_ID`.

The client ID is not a secret. The app uses Google's page in the system browser sheet with PKCE and keeps the sign-in key in the Keychain.

## Layout

| Folder | Content |
|---|---|
| `Health50/App` | App entry point and `AppModel`, the one model behind the single screen |
| `Health50/Health` | Catalog of data types, reading from Health, encoding of records |
| `Health50/Export` | Streaming JSON writer, UTC months |
| `Health50/Drive` | Google sign-in, Drive client, monthly sync, bookkeeping |
| `Health50/Background` | Settings, background scheduling, notifications |
| `Health50/UI` | Welcome screen, main screen, status card, sheets |
| `Health50/Resources` | Assets, String Catalogs (six languages), Info.plist, entitlements |
| `Health50Tests` | Unit tests |
| `Tools` | Generator for the data type catalog, and a seeding tool for the simulator |

## Data type catalog

`Health50/Health/HealthCatalog+Generated.swift` lists every quantity type, category type and enum name the app exports. It is generated from the HealthKit headers of the installed SDK, so a new iOS version only needs a re-run:

```bash
python3 Tools/generate_health_catalog.py Health50/Health/HealthCatalog+Generated.swift
```

## Testing with data in the simulator

A fresh simulator has no health data. `Tools/HealthSeeder` is a separate small app that writes test records (weight, steps, heart rate, sleep, a blood pressure reading and a run with a GPS route) into the simulator's Health store. Health50 itself never writes to Health.

```bash
cd Tools/HealthSeeder
xcodebuild -project HealthSeeder.xcodeproj -scheme HealthSeeder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build build
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/HealthSeeder.app
xcrun simctl launch booted com.66ideas.health50.seeder
```

## Debug launch arguments

Debug builds only.

| Argument | Effect |
|---|---|
| `-demo <state>` | Shows a state without real data, for screenshots: `welcome`, `ready`, `upToDate`, `reconnect`, `exporting`, `saved`, `failed`, `waiting`, `noData`, `driveSignIn`, `driveConnected`, `healthSheet` |
| `-debugLocalSync YES` | Runs the monthly export into the app's `Documents/DebugSync` folder instead of Google Drive, to check month files and the index without a Google account |

```bash
xcrun simctl launch booted com.66ideas.health50 -demo upToDate
```
