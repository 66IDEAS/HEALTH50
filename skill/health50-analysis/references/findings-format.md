# The findings file

After judging a run you write `findings.json` into the folder of the run (the digest names
the path in `writeFindingsTo`). `build_dashboard.py` builds the dashboard from it. Write
plain JSON in UTF-8. Texts are in the user's language.

## Example

The numbers are made up.

```json
{
  "headline": "Good overall: you move a lot and your heart values are steady. Sleep is the area to work on.",
  "areas": {
    "activity": { "rating": "good", "text": "You reach the weekly activity guideline in most weeks." },
    "heart": { "rating": "watch", "text": "Your resting heart rate is two beats higher than a year ago." },
    "sleep": { "rating": "act", "text": "Seven of ten nights are shorter than seven hours." },
    "training": { "rating": "good", "text": "Three to four sessions per week, mostly running." },
    "body": { "rating": "good", "text": "Your weight is moving towards your goal." },
    "mobility": { "rating": "good", "text": "Walking speed and step length are steady." },
    "hearing": { "rating": "good", "text": "Headphone volume stays below the limit." },
    "mind": { "rating": "none", "text": "" }
  },
  "doctor": [
    "One ECG recording on 14 Mar 2026 was classified as atrial fibrillation by Apple Watch."
  ],
  "recommendations": [
    {
      "id": "sleep-duration",
      "text": "Be in bed by 23:00 on work nights.",
      "metric": "sleepH",
      "now": ["6 h 12 min", ""],
      "target": ["7 h 00 min", ""],
      "value": 6.2,
      "start": 6.2,
      "direction": 1,
      "tolerance": 0.08,
      "progress": 0
    },
    {
      "id": "strength",
      "text": "Add two short strength sessions per week.",
      "metric": "workoutsStrength",
      "weekly": "sum",
      "now": ["0.6", "per week"],
      "target": ["2", "per week"],
      "value": 0.6,
      "start": 0.2,
      "direction": 1,
      "tolerance": 0.3,
      "progress": 0.22
    },
    {
      "id": "weight",
      "text": "Keep losing about half a kilogram per month.",
      "metric": "weightKg",
      "now": ["81.8", "kg"],
      "target": ["80", "kg"],
      "value": 81.8,
      "start": 84.5,
      "direction": -1,
      "tolerance": 0.3,
      "progress": 0.6
    }
  ],
  "guidelinesUsed": ["who-activity", "who-strength", "aasm-sleep"],
  "good": { "weightKg": -1 },
  "goals": { "weightKg": 80 }
}
```

## Fields

### `headline` (required)

One sentence that answers "how is my health". It is the title of the dashboard and the first
line of the chat result. About 100 characters at most.

### `areas` (required)

One entry for each of the eight ids: `activity`, `heart`, `sleep`, `training`, `body`,
`mobility`, `hearing`, `mind`.

| Field | Meaning |
|---|---|
| `rating` | `good`, `watch` (shown as "Keep an eye on it"), `act` or `none` (shown as "No data or no access") |
| `text` | One short sentence, shown under the title of the area. Empty for `none`. |

The dashboard shows an area without records in the period as "No data or no access"
whatever you wrote, with your text below it. The Mind area counts as having records when the
period holds a questionnaire, a mood log or a mindfulness session.

### `doctor` (required, may be empty)

A list of sentences, one per point worth raising with a doctor. Each one names the fact with
its date or number. An empty list means that the dashboard shows no such card.

### `recommendations` (required)

Three to five entries, the most important first. Fewer if there is little to improve.

| Field | Meaning |
|---|---|
| `id` | Short name in lower case with hyphens, for example `sleep-duration`. **Keep the same id in later runs** for a recommendation that continues: the dashboard finds the earlier one by its id and shows whether the number improved. |
| `text` | One short sentence that says what to do |
| `metric` | Optional. A name from `seriesNames`. The card then shows a small trend line of that number over the year. |
| `weekly` | Optional. `"sum"` if the number is counted per week (workouts, exercise minutes): the trend line then shows totals per week. Leave it out for numbers that are averaged. |
| `now` | The current number as it is shown: a list of two strings, the value and its unit. The unit may be empty. |
| `target` | The target in the same form |
| `value` | The current number as a number, in a unit that stays the same from run to run: the mean of the last 30 days (`last30`, for numbers per week `perWeek.last30`). It is compared with the `value` of the same recommendation in the previous run. |
| `start` | The `value` at the run in which this recommendation first appeared. On that run it equals `value`. Later runs copy it from the previous run. |
| `direction` | `1` if a higher `value` is better, `-1` if a lower one is better |
| `tolerance` | A change of `value` smaller than this counts as unchanged, so that ordinary variation does not show as progress. Use the values the dashboard uses for its own arrows: 0.08 for hours of sleep (five minutes), 100 for steps, 15 for exercise minutes per week, 0.5 for beats per minute, 2 for heart rate variability, 0.3 for VO2 max, kilograms, percent values and sessions per week, 0.05 for walking speed, 1 for decibels. |
| `progress` | How far the user has come from `start` to the target, from 0 to 1. It is drawn as a bar. (`value` - `start`) / (target - `start`), not below 0 and not above 1. On the run in which the recommendation first appears it is 0, or 1 if the target is already met ("keep doing this"). |

For a target that is a clock time, such as a bedtime, measure it with a number that has a
clear direction, for example the hours of sleep it leads to.

### `guidelinesUsed` (required, may be empty)

The `id`s of the guidelines from `guidelines.json` that your ratings and recommendations rest
on. The bottom of the dashboard names them with their sources. Guidelines that a chart shows
as a line are added automatically.

### `good` (optional)

Says which direction counts as an improvement for numbers that have no fixed good direction:
`weightKg`, `bodyFatPct` and `respRate`. `1` means higher is better, `-1` lower is better.
Set it from the user's goals, for example `{ "weightKg": -1 }` when the goal is to lose
weight. Without it, changes of these numbers are shown without a judgement.

### `goals` (optional)

`{ "weightKg": 80 }` draws the user's target weight as a line in the weight chart. Only when
the user stated one.

## Check before you build

- Valid JSON, all eight areas present, every rating one of the four words.
- Every number in a text is in the digest.
- Every `metric` is in `seriesNames`.
- Every id in `guidelinesUsed` is in `guidelines`.
- No guideline value in any text that is not in `guidelines`. A target taken from the user's own values is fine if the text says so.
- `build_dashboard.py` checks the form of the file and lists what to correct.
