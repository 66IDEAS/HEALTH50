# Health50 - Export Format

Status: approved on 2026-11-05. It follows the decision to keep one file per month in Google Drive (see [architecture.md](architecture.md)).

## Design goals

- **Readable without the app.** Plain JSON, clear key names, no codes that need a lookup table.
- **Nothing invented.** Record types use Apple's own identifiers (for example `HKQuantityTypeIdentifierHeartRate`), so every type can be looked up in Apple's documentation.
- **Every file stands on its own.** A tool can read a single month and understand it completely.
- **Meaning is preserved.** Every value has a unit, every record has its dates, its source and its extra context.
- **No false claims.** Files say that they contain what the user allowed, not that they are complete.

## Files

| File | Content | When it is written |
|---|---|---|
| `health50-index.json` | List of all month files, the profile, an overview per data type | After every run |
| `health50-YYYY-MM.json` | All records that start in that month | When something in that month changed |
| `health50-export.json` | The full history in one file (manual "Save to Files…") | On demand |

All three use the same structure. Only `kind` and `period` differ.

A record belongs to the month in which it **starts**, measured in UTC. A night of sleep that starts on 31 October at 23:10 UTC is in the October file.

## General rules

- **Times** are ISO 8601 in UTC, for example `2026-11-05T05:58:12Z`. If Health stored the original time zone of a record, it is in the record's `metadata`.
- **`end` is left out** when it is identical to `start` (a single measurement such as a weight).
- **Units** use Health's own unit names (`count/min`, `kcal`, `km`, `mmHg`, `degC`). Each data type always uses the same unit, independent of the phone's language or region.
- **`id`** is the record's unique ID from Health. It is stable, so tools can detect duplicates across files.
- **`source`** is a short key into the `sources` table of the same file, so app and device names are not repeated for every record.
- **`metadata`** holds everything else Health stored with the record, with Apple's key names. It is left out when empty. Yes/no values appear as `1` and `0`, the way Health stores them.
- **Empty sections are left out.** A month without workouts has no `workouts` key.

## Month file

```json
{
  "format": "health50",
  "formatVersion": 1,
  "kind": "month",
  "period": {
    "month": "2026-11",
    "from": "2026-11-01T00:00:00Z",
    "to": "2026-12-01T00:00:00Z"
  },
  "generatedAt": "2026-11-05T06:12:03Z",
  "monthClosed": false,
  "generator": { "app": "Health50", "version": "1.0 (12)", "device": "iPhone18,1", "os": "iOS 27.1" },
  "access": "Contains only the data the user allowed Health50 to read. A missing data type can mean that access was not given or that no data exists.",

  "sources": {
    "s1": { "name": "Apple Watch", "bundleId": "com.apple.health.A1B2C3", "version": "13.1", "device": "Watch7,3", "osVersion": "13.1" },
    "s2": { "name": "iPhone", "bundleId": "com.apple.health.D4E5F6", "version": "27.1", "device": "iPhone18,1", "osVersion": "27.1" },
    "s3": { "name": "Withings", "bundleId": "com.withings.wiScaleNG", "version": "7.2" }
  },

  "quantities": { },
  "categories": { },
  "workouts": [ ],
  "correlations": [ ],
  "electrocardiograms": [ ],
  "heartbeatSeries": [ ],
  "audiograms": [ ],
  "statesOfMind": [ ],
  "activitySummaries": [ ]
}
```

`monthClosed` is `false` for the running month and `true` once the month is over. A closed month can still be rewritten later if data in it changes.

The order of the keys in a file carries no meaning. Because files are written as a stream, `sources` comes last, after the records that refer to it. A month without any records gets no file.

## Record sections

### quantities

Everything that is a number with a unit: steps, heart rate, weight, blood oxygen, distance and so on. Grouped by type, with the unit stated once per type.

```json
"quantities": {
  "HKQuantityTypeIdentifierHeartRate": {
    "unit": "count/min",
    "samples": [
      { "id": "6F1C…", "start": "2026-11-05T05:58:12Z", "value": 58, "source": "s1",
        "metadata": { "HKMetadataKeyHeartRateMotionContext": 1 } }
    ]
  },
  "HKQuantityTypeIdentifierStepCount": {
    "unit": "count",
    "samples": [
      { "id": "0A9E…", "start": "2026-11-05T06:00:00Z", "end": "2026-11-05T06:09:41Z", "value": 412, "source": "s2" }
    ]
  },
  "HKQuantityTypeIdentifierBodyMass": {
    "unit": "kg",
    "samples": [
      { "id": "77B2…", "start": "2026-11-05T06:30:10Z", "value": 81.4, "source": "s3",
        "metadata": { "HKWasUserEntered": 0 } }
    ]
  }
}
```

### categories

Everything that is a state instead of a number: sleep phases, mindful minutes, symptoms, cycle tracking. `value` is the readable name, `code` is Apple's number for it. `value` is left out in the rare case that the app does not know a name for the code.

```json
"categories": {
  "HKCategoryTypeIdentifierSleepAnalysis": {
    "samples": [
      { "id": "C31D…", "start": "2026-11-04T22:41:00Z", "end": "2026-11-04T23:52:30Z", "value": "asleepCore", "code": 3, "source": "s1" },
      { "id": "C31E…", "start": "2026-11-04T23:52:30Z", "end": "2026-11-05T00:31:00Z", "value": "asleepDeep", "code": 4, "source": "s1" }
    ]
  }
}
```

### workouts

```json
"workouts": [
  {
    "id": "9D40…",
    "activity": "running", "activityCode": 37,
    "start": "2026-11-03T17:02:11Z", "end": "2026-11-03T17:32:16Z",
    "duration": 1805.2,
    "source": "s1",
    "statistics": {
      "HKQuantityTypeIdentifierActiveEnergyBurned": { "sum": 312.4, "unit": "kcal" },
      "HKQuantityTypeIdentifierDistanceWalkingRunning": { "sum": 5.02, "unit": "km" },
      "HKQuantityTypeIdentifierHeartRate": { "average": 148, "minimum": 92, "maximum": 171, "unit": "count/min" }
    },
    "events": [
      { "type": "pause", "start": "2026-11-03T17:14:02Z" },
      { "type": "resume", "start": "2026-11-03T17:14:40Z" }
    ],
    "route": [
      { "time": "2026-11-03T17:02:12Z", "latitude": 47.3769, "longitude": 8.5417, "altitude": 408.1, "speed": 2.9, "horizontalAccuracy": 4.2 }
    ],
    "metadata": { "HKIndoorWorkout": 0 }
  }
]
```

`duration` is in seconds. `route` is only present when the workout has GPS data and the user allowed Health50 to read workout routes.

### correlations

Records that belong together, such as the two values of a blood pressure reading. The member values are also listed under `quantities` with the same `id`, so tools that only read `quantities` miss nothing and tools that read both can match them by `id`.

```json
"correlations": [
  {
    "type": "HKCorrelationTypeIdentifierBloodPressure",
    "id": "51AA…", "start": "2026-11-05T06:35:00Z", "source": "s3",
    "samples": [
      { "id": "51AB…", "type": "HKQuantityTypeIdentifierBloodPressureSystolic", "value": 122, "unit": "mmHg" },
      { "id": "51AC…", "type": "HKQuantityTypeIdentifierBloodPressureDiastolic", "value": 78, "unit": "mmHg" }
    ]
  }
]
```

### electrocardiograms

```json
"electrocardiograms": [
  {
    "id": "E0C1…", "start": "2026-11-02T08:15:00Z", "end": "2026-11-02T08:15:30Z", "source": "s1",
    "classification": "sinusRhythm",
    "symptomsStatus": "none",
    "averageHeartRate": { "value": 64, "unit": "count/min" },
    "samplingFrequency": { "value": 512, "unit": "Hz" },
    "voltages": { "unit": "mcV", "values": [ -12.4, -11.9, -10.2 ] }
  }
]
```

`voltages.values` holds the whole recording in order, one value per sampling step (about 15,000 values for a 30 second recording).

### heartbeatSeries

Beat-to-beat recordings. `time` is seconds since `start`.

```json
"heartbeatSeries": [
  { "id": "B7F0…", "start": "2026-11-05T02:10:00Z", "end": "2026-11-05T02:11:00Z", "source": "s1",
    "beats": [ { "time": 0.812 }, { "time": 1.640 }, { "time": 2.455, "precededByGap": true } ] }
]
```

### audiograms

```json
"audiograms": [
  { "id": "A2D9…", "start": "2026-11-01T10:00:00Z", "source": "s2",
    "points": [
      { "frequency": { "value": 1000, "unit": "Hz" }, "left": { "value": 15, "unit": "dBHL" }, "right": { "value": 10, "unit": "dBHL" } }
    ] }
]
```

### statesOfMind

```json
"statesOfMind": [
  { "id": "D5A3…", "start": "2026-11-05T07:00:00Z", "source": "s2",
    "kind": "momentaryEmotion", "valence": 0.42, "valenceClassification": "slightlyPleasant",
    "labels": [ "calm", "content" ], "associations": [ "work" ] }
]
```

### scoredAssessments

Questionnaires with a score, such as GAD-7 and PHQ-9. `answers` are Apple's numbers for the chosen answers, in order.

```json
"scoredAssessments": [
  { "type": "HKScoredAssessmentTypeIdentifierGAD7", "id": "7C1E…", "start": "2026-11-03T19:00:00Z", "source": "s2",
    "score": 6, "risk": "mild", "answers": [1, 1, 0, 1, 1, 1, 1] }
]
```

### activitySummaries

The Activity rings, one entry per day. These are per calendar day, so they carry a `date` instead of `start` and have no `id`.

```json
"activitySummaries": [
  { "date": "2026-11-04",
    "activeEnergy": { "value": 512, "goal": 600, "unit": "kcal" },
    "exerciseTime": { "value": 34, "goal": 30, "unit": "min" },
    "standHours": { "value": 11, "goal": 12, "unit": "count" } }
]
```

## Index file

`health50-index.json` tells a tool what exists without opening every month. It also holds the profile, because those values are not tied to a date.

```json
{
  "format": "health50",
  "formatVersion": 1,
  "kind": "index",
  "generatedAt": "2026-11-05T06:12:05Z",
  "generator": { "app": "Health50", "version": "1.0 (12)", "device": "iPhone18,1", "os": "iOS 27.1" },
  "access": "Contains only the data the user allowed Health50 to read. A missing data type can mean that access was not given or that no data exists.",

  "profile": {
    "dateOfBirth": "1976-05-21",
    "biologicalSex": "male",
    "bloodType": "aPositive",
    "fitzpatrickSkinType": "typeIII",
    "wheelchairUse": "no"
  },

  "files": [
    { "month": "2026-10", "name": "health50-2026-10.json", "updatedAt": "2026-11-01T06:10:44Z", "monthClosed": true, "records": 148210, "bytes": 24113876 },
    { "month": "2026-11", "name": "health50-2026-11.json", "updatedAt": "2026-11-05T06:12:03Z", "monthClosed": false, "records": 18234, "bytes": 4193221 }
  ],

  "types": {
    "HKQuantityTypeIdentifierHeartRate": { "first": "2019-09-20T08:11:00Z", "last": "2026-11-05T05:58:12Z", "records": 2841120 },
    "HKCategoryTypeIdentifierSleepAnalysis": { "first": "2020-01-03T22:40:00Z", "last": "2026-11-05T05:40:00Z", "records": 61234 }
  }
}
```

Profile fields the user did not allow or did not fill in are left out.

## Full file (manual save)

`health50-export.json` has `"kind": "full"`, a `period` that spans from the first to the last record, the same record sections as a month file, and additionally the `profile` block from the index.

## What is included

All record types Health offers to apps, with these exceptions:

- **Clinical records** are not part of version 1.
- **Medications and vision prescriptions** are left out. iOS asks for permission for each of these records separately, so they cannot be requested together with the other types.

The list of types is generated from the iOS 27.2 developer kit: 121 quantity types and 71 category types, plus workouts with routes, blood pressure and food correlations, ECGs, heartbeat series, audiograms, states of mind, scored assessments, activity summaries and the profile.

On iOS 27 the user also chooses, in the permission sheet, whether an app may read only the past 30 days or all recorded data. Health50 exports whatever that choice allows.

## Choices made in this format

Approved together with the format:

1. **Readable keys over smallest size.** Records use full words (`start`, `value`, `source`). A more compact form would save roughly a third of the size but is harder to read. With monthly files, size is no longer the main concern.
2. **Months are cut in UTC.** This is unambiguous even when travelling. The alternative is the phone's local time, which is more intuitive but shifts when the time zone changes.
3. **GPS routes of workouts are included** when the user allows it. They are location data and can be large.
4. **Full ECG recordings are included**, not only their classification.
5. **Blood pressure values appear twice**, once under `quantities` and once in their `correlations` entry, linked by `id`.
