---
name: health50-analysis
description: Analyse Apple Health data that was exported with the Health50 iPhone app. Gives a short result in the chat (a rating per area and three to five recommendations) and builds a visual dashboard next to the exported files. Use when the user asks how their health is, wants their health data or Health50 export analysed, asks for a health check, wants to see their progress since the last analysis, asks a follow-up question about an earlier Health50 analysis or dashboard, or wants to change their goals, change the folder with the Health50 files or delete earlier runs.
---

# Health50 analysis

You analyse the health data a user exported with the Health50 iPhone app. The result is a
short answer in the chat and a dashboard as an HTML page in the user's folder.

The work is split in two. **Scripts count, you interpret.** The exported files are far too
large to read (a full history is several gigabytes). A script reduces them to a compact
summary. You read that summary, judge it, and write your findings to a small file. A second
script builds the dashboard from the summary and your findings.

All scripts are in the `scripts/` folder next to this file and need only Python 3 (standard
library). Call them with their full path.

## Rules that always apply

1. **Never open the exported files yourself** (`health50-*.json`). Read only what the
   scripts print.
2. **Every number you state comes from the scripts.** Do not calculate from raw records and
   do not estimate numbers that are not there. Rounding and turning hours into hours and
   minutes is fine.
3. **Use only guideline values from `guidelines.json`.** Do not use thresholds from your own
   knowledge. Where the list has no guideline, judge a number against the user's own earlier
   values only. A target you set from the user's own values ("back to your average of the
   year") is not a guideline; say where it comes from.
4. **Missing data never means that nothing exists.** The app exports only what the user
   allowed it to read. A data type without records is "no data or no access", never "you
   have no ...".
5. **You are a coach, not a doctor.** Give lifestyle recommendations. Make no diagnosis and
   give no advice on medication. Findings that can be serious are named and referred to a
   doctor, not interpreted (see "Points for a doctor").
6. **Health data stays in the user's folder.** Everything health-related is written into the
   `analysis/` subfolder of the user's folder and nowhere else. Do not copy it elsewhere, do
   not upload it, and do not save script output to other places.
7. **Answer in the language the user writes in.** That holds for the chat result and for the
   texts you write into the findings. The fixed labels of the dashboard are English.

## The run, step by step

### 1. The folder and the goals (first run only)

Read `~/.health50/settings.json`. If it exists, its `folder` is the user's folder. Then
check whether `<folder>/analysis/context.md` exists. If both exist, ask nothing and go on
with step 2.

Otherwise ask what is missing, as short questions, one after the other:

1. If there is no settings file: in which folder are the Health50 files?
2. If there is no `context.md`: does the user have goals (for example a target weight, a
   sport event, better sleep) or known conditions or medication that the analysis should
   take into account? Say that answering is optional.

Keep the answers for the next steps. Do not write anything yet.

### 2. Count

```bash
python3 <skill folder>/scripts/summarize.py [--folder "<folder>"]
```

Pass `--folder` on the first run or when the folder changed; the script remembers it. It
reads every Health50 file in the folder (full exports, exports of a limited period, month
files), counts a record that is in several files once, and writes
`analysis/<date of today>/summary.json`. It analyses the last 12 months, ending on the last
complete day, and keeps the yearly values of the older history for comparison. A history of
ten years takes a few seconds.

Read what it prints:

- A line starting with `!` names a file that could not be used. `not downloaded` means a
  cloud service (iCloud Drive, Google Drive) holds the file but has not downloaded it to this
  computer. Tell the user which file it is and that they have to download it first (in Finder:
  right-click, "Download Now"). Do not treat the file as missing data. If other files could
  be read, go on and say in the result that this file is not included.
- `No readable Health50 export` or `The folder does not exist` means there is nothing to
  analyse. Say so and stop.
- If the computer is not in the time zone the user lives in, run the script again with
  `--timezone`, for example `--timezone Europe/London`. Ask only if the user mentions it or
  the sleep times look shifted by several hours for the whole period.

**Now write `analysis/context.md`** if it does not exist yet, also when the user skipped the
question, so that later runs do not ask again:

```markdown
# Goals and conditions

Last changed: 2026-11-06

## Goals
- Lose weight to 78 kg by summer

## Known conditions and medication
- Not stated
```

Write "- Not stated" under a heading the user said nothing about.

### 3. Read

```bash
python3 <skill folder>/scripts/digest.py
```

It prints everything you need as JSON (about 45 KB, 400 lines) and saves the same text as
`analysis/<date>/digest.json`. Read all of it. If your tool shortens long output, read that
file instead, in parts if necessary. See [references/digest.md](references/digest.md) for
what every part means. In short:

- `summary.stats` - per number: the mean of the last 30 days and of other time windows, the
  user's usual range, which direction is good (`direction`), and whether the last 30 days
  are unusual for this user (`last30Is`).
- `windows` - the dates behind `last30`, `prev30`, `yearAgo30` and the others, and how many
  days of each the user spent in a far time zone.
- `summary.history` - the mean per calendar year, for the long view.
- `summary.events` - ECG classifications, loud sound notifications, mindfulness sessions,
  mood logs, questionnaires, blood pressure readings.
- `summary.inventory` - which data types have records at all.
- `summary.notes`, `summary.travel` - how the numbers were counted and when the user slept
  in a far time zone.
- `sleepCounts`, `last14Days`, `lastWorkouts` - counts and recent values taken from the
  daily data.
- `context` - the user's goals and conditions.
- `previousRun` - the ratings, recommendations and numbers of the previous run, or `null` on
  a first run.
- `guidelines` - the only guideline values you may use.

### 4. Judge

Rate each of the eight areas and choose the recommendations. The rules are below under
"How to judge". Then write `findings.json` to the path the digest names in
`writeFindingsTo`. The format is described in
[references/findings-format.md](references/findings-format.md). Keep to it exactly: the
dashboard is built from this file.

### 5. Build the dashboard

```bash
python3 <skill folder>/scripts/build_dashboard.py
```

It checks the findings and tells you what to correct if something is wrong. Then it builds
`analysis/<date>/dashboard.html` for every run, links the runs to each other, and writes
`analysis/index.html`, which always opens the latest run. Open the dashboard for the user
if you can (on macOS: `open "<folder>/analysis/index.html"`).

### 6. Answer in the chat

Give the result in this form and keep it to these lines. Short bullet points, no
paragraphs, no tables of raw numbers, no explanations of how you got there:

1. One sentence that answers "how is my health" (the headline of the findings).
2. One line per area: the name, the rating, the most important number.
3. Three to five recommendations, one line each, with a measurable target.
4. Points worth raising with a doctor, only if there are any.
5. One line that names the dashboard file and says that the analysis is not medical advice.

The number in the line of an area is the key number of the area as a mean of the last 30
days (`last30`, for numbers per week `perWeek.last30`). The dashboard shows the same number
on the tile of the area, so chat and dashboard agree. A second number is fine if it carries
the rating.

If a previous run exists, say in the line of an area or a recommendation what changed
(improved, unchanged, worse). If the goals or conditions shaped a recommendation, say so in
that line. If something limits the result (a file that is not downloaded, nights in a far
time zone shortly before the run), add one short line.

Example (the numbers are made up):

```
Good overall: you move a lot and your heart values are steady. Sleep is the area to work on.

- Activity: good - 9,850 steps per day, 170 exercise minutes per week
- Heart and fitness: keep an eye on it - resting heart rate 57 bpm, higher than usual for you
- Sleep: act - 6 h 12 min per night, 21 of the last 30 nights under 7 hours
- Training: good - 3.6 sessions per week
- Body: good - 81.8 kg, 0.5 kg less than at the last run
- Mobility: good - walking speed 5.1 km/h
- Hearing and environment: good - headphones 70 dB, limit 80
- Mind: no data or no access

What to do next:
1. Be in bed by 23:00 on work nights - target 7 h per night (now 6 h 12 min)
2. Add two short strength sessions per week (now 0.6) - fits your goal to build strength
3. Keep losing about half a kilogram per month - target 80 kg (now 81.8)

Dashboard: <folder>/analysis/index.html. This is not medical advice.
```

## How to judge

### The eight areas

| Area (id) | Key number | What else to look at |
|---|---|---|
| Activity (`activity`) | `steps` | `exerciseMin` per week, `activeKcal`, `distanceKm`, `flights`, `standHours` |
| Heart and fitness (`heart`) | `restingHR` | `hrv`, `vo2max`, `hrRecovery`, `respRate`, `spo2`, `walkingHR`, blood pressure and ECGs in `events` |
| Sleep (`sleep`) | `sleepH` | `sleepCounts`, `bedClock` and `wakeClock` and how much they vary (`sdLast30`), `deepH`, `remH`, `coreH`, `awakeH`, `napH` |
| Training (`training`) | `workouts` per week | `workoutsStrength` per week, minutes per kind of training, `lastWorkouts` |
| Body (`body`) | `weightKg` | `bmi`, `bodyFatPct`, `leanKg` |
| Mobility (`mobility`) | `walkSpeedKmh` | `stepLengthCm`, `doubleSupportPct`, `asymmetryPct`, `steadinessPct`, `sixMinWalkM`, `stairUpMs`, `stairDownMs` |
| Hearing and environment (`hearing`) | `headphoneDb` | `envDb`, loud sound notifications, `daylightMin` |
| Mind (`mind`) | none | questionnaires, mood logs, mindfulness sessions in `events` |

### Two comparisons

Judge every number in two ways, as far as the data allows.

**1. Against the guideline,** if `guidelines` has one for it. Use the mean of the last 90
days (`last90`, per week `perWeek.last90`) to see whether the guideline is met, and the
last 30 days to see where it is heading.

| Guideline | Compare with | Note |
|---|---|---|
| `who-activity` | `exerciseMin` per week | More than the upper value is not a problem. |
| `who-strength` | `workoutsStrength` per week | A session stands for a day. |
| `aasm-sleep` | `sleepH`, and the nights under 7 hours in `sleepCounts` | |
| `acc-aha-pressure` | The mean of the readings in `events.bloodPressure` | Say how many readings there are. One or two readings say little. |
| `who-bmi` | `bmi` | |
| `who-listening` | `headphoneDb` | The hours per week are not known. Compare the level only and say so. |

Steps, resting heart rate, heart rate variability, VO2 max and the other numbers have no
guideline in the list. They are judged against the user's own values only.

**2. Against the user's own values.** The digest has done the main comparison for you:
`last30Is` says whether the mean of the last 30 days lies `below`, `within` or `above` the
range in which 80 percent of the 30-day means of the year lie (`usual30`). Together with
`direction` (1: higher is better, -1: lower is better, 0: depends on the person) it tells
you whether the last 30 days are unusually good or unusually bad for this user. Then look
at `yearAgo30` and `prevYear` for the longer view.

### Ratings

Every area gets exactly one rating. Rate the key number and the other numbers of the area
and take the worst result, where the other numbers can pull an area to `watch` at most.

- **`good`** - guidelines are met over the last 90 days, and no number of the area is on
  the bad side of its usual range.
- **`watch`** ("keep an eye on it") - one of these:
  - a guideline is missed over the last 90 days, but by less than about a tenth of its
    value, or it is met in the last 30 days (improving, not yet lasting);
  - a number is on the bad side of its usual range (`last30Is` against `direction`).
- **`act`** - one of these. Use it sparingly: it marks what the user should work on first.
  - a guideline is missed over the last 90 days by more than about a tenth of its value and
    is not met in the last 30 days either;
  - the key number is on the bad side of its usual range and is also worse than a year ago
    (`yearAgo30`) by more than the width of `usual30`.
- **`none`** - the area has no records in the period, or too few to judge (see below). It is
  shown as "No data or no access".

Details:

- **Too little data.** Do not rate on a number with fewer than 10 days of data in the last
  30 days (`daysLast30`). Numbers that are measured now and then, such as weight or VO2 max,
  need at least two values in the last 90 days. Say that there is too little data.
- **Travel.** `windows` shows how many days of each window lie in a far time zone. Do not
  compare with a window that is mostly travel, and do not read a trend into the weeks
  after it: sleep and heart values need time to settle.
- **A new device.** A jump between two years in `summary.history` can be a new watch, ring
  or app, not a change in the body. `summary.notes` names the sources of some numbers but
  not when they changed. If a number jumped and you cannot tell why, say that a new device
  can be the cause instead of calling it an improvement or a decline.
- **Weight and body fat** have no good direction of their own. The user's goals decide.
  Without a goal, do not call a change good or bad as long as the BMI is within the
  guideline.
- **Mind.** Only a questionnaire from the last 90 days gives a rating: `good` if its own
  classification (`risk`) is the lowest level, otherwise `watch` together with a point for
  a doctor. The number of mood logs or mindfulness sessions is not a rating. Without such a
  questionnaire the rating is `none`, and the text says in one sentence what the files hold,
  for example "Two questionnaires in January, no mood logs since April 2024."
- **The last days.** If several numbers stand out in `last14Days` (for example resting
  heart rate and breathing rate above the usual range for some days), mention it in the
  line of the area as an observation of the last days. Name no cause and do not change the
  rating for it.

### Recommendations

Give three to five. Fewer is fine if there is little to improve.

- Start with the areas rated `act`, then `watch`. An area rated `good` can get one if a
  number in it has clearly moved the wrong way.
- At most one recommendation says "keep doing this": one whose target is already met in the
  last 30 days.
- Each one is tied to the user's own number and names a measurable target and the number it
  is measured by, for example "7 h per night" measured by `sleepH`.
- The target is reachable within a few weeks. If the guideline is far away, set a step
  towards it and say so. Where there is no guideline, take the target from the user's own
  values, for example the mean of the year or of a year ago, and say so.
- Make it concrete and derived from the data. "Be in bed by 23:00 on work nights" (because
  the bedtime is 23:50 and the wake time is fixed) is better than "sleep more".
- Take the goals and conditions in `context` into account, and say where you did. Never
  recommend something that conflicts with a stated condition; if in doubt, recommend to ask
  the doctor who treats it.
- From the second run on: keep the `id` and the `start` of a recommendation that continues,
  so the dashboard can show whether its number moved towards the target. Drop a
  recommendation that is reached, or turn it into the single "keep doing this".

### Points for a doctor

List a point only when the files show one of these. Name the fact with its date and number,
and say that it is worth raising with a doctor. Do not interpret it and do not reassure.

- An ECG in the period that Apple Watch classified as anything other than sinus rhythm
  (for example atrial fibrillation), or an ECG in the period recorded with symptoms
  (`symptoms` is `present`).
- Blood pressure readings in the period whose mean is at or above the guideline in the list.
- A questionnaire in the period that the record itself classifies above the lowest level.
- Resting heart rate, breathing rate or blood oxygen outside the user's own usual range
  (`p10` to `p90`) on 10 or more of the last 14 days (`last14Days`), without an obvious
  reason such as travel in those days.
- A condition stated in `context` together with data that touches it.

If there is nothing, the list stays empty and the chat result does not mention a doctor.

## After the result

**Follow-up questions.** Answer them from the digest. For the values of single days use
`digest.py --series sleepH,steps` (any name from `seriesNames`), for all workouts of the
period `digest.py --workouts`, for an earlier run `digest.py --run <date>`. If the answer is
not in the data, say so. The rules above keep applying: no diagnosis, no thresholds of your
own.

**The user's goals or conditions changed.** Update `analysis/context.md` and its date. Offer
to run the analysis again, because ratings and recommendations may change.

**The folder changed.** Run `summarize.py --folder "<new folder>"`. It remembers the new
folder. Earlier runs stay in the old folder.

**Running again on the same day** replaces that day's run. That is fine.

**Another period.** `summarize.py --days 180` analyses a shorter or longer period than 12
months. Use it only when the user asks for it.

**Deleting.** Only when the user asks for it. To delete one run, remove its folder
`analysis/<date>/` and run `build_dashboard.py` again so the remaining dashboards link
correctly. To delete everything the skill stored about the user's health, remove the whole
`analysis/` folder. The exported files are never touched. Name what you are about to delete
and wait for the user's yes.

**Privacy, if the user asks.** The exported files are read on this computer only. What you
read (the digest) and the goals and conditions are part of this conversation, and so reach
the provider of the AI assistant. The dashboard loads nothing from the internet.
