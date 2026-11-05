# HEALTH50

A free, open-source iPhone app that exports the health data you choose as plain JSON files, for the tools you choose.

- **Save to Files:** your full accessible history in one JSON file, in a location you pick.
- **Automatic export:** one JSON file per month in your own Google Drive, kept current in the background.
- **Private by design:** read-only access to Health, no account, no server, no analytics. Data goes straight from your iPhone to your destination.

Health50 is a [66IDEAS](https://github.com/66IDEAS) product: the specification is the product, the code is the proof.

## What is in this repository

| Path | Content |
|---|---|
| [specs/specifications.md](specs/specifications.md) | What the app does: the user stories |
| [specs/ux.md](specs/ux.md) | How it looks and behaves: 31 UX requirements |
| [specs/mockups](specs/mockups) | HTML mockups of the single screen |
| [specs/architecture.md](specs/architecture.md) | Architecture decisions |
| [specs/export-format.md](specs/export-format.md) | The JSON format of the exported files |
| [specs/tasks.md](specs/tasks.md) | Implementation tasks and their state |
| [dev](dev) | The reference implementation: a native app for iOS 27 in Swift and SwiftUI |
| [PRIVACY.md](PRIVACY.md) | Privacy policy |
| [SUPPORT.md](SUPPORT.md) | Help and common questions |

To build and run the app, see [dev/README.md](dev/README.md).

## License

[MIT](LICENSE)
