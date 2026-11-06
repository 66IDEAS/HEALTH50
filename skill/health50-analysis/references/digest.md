# What `digest.py` prints

`digest.py` prints one JSON object and saves the same text as `digest.json` in the folder of
the run. This page says what its parts mean.

## Top level

| Key | Meaning |
|---|---|
| `run` | Date of the run, which is also the name of its folder |
| `runFolder`, `writeFindingsTo`, `contextFile` | Paths in the user's folder. Write the findings to `writeFindingsTo`. |
| `context` | Text of `analysis/context.md`: the user's goals and conditions. `null` means the user has not been asked yet. |
| `summary` | The summary without the daily values and the workout list (see below) |
| `windows` | The dates behind the names of the time windows (see below) |
| `seriesNames` | Names of all numbers that have daily values. Use them with `digest.py --series` and as `metric` in a recommendation. |
| `last14Days` | The last 14 daily values of every number, oldest first; `windows.last14Days` gives the dates. `null` is a day without a value. Bed and wake times are given as clock times. |
| `sleepCounts` | Counts over the nights of the period (see below). `null` if there is no sleep data. |
| `lastWorkouts` | The ten most recent workouts |
| `previousRun` | The previous run that has findings, or `null` on a first run (see below) |
| `allRuns` | Dates of all runs |
| `guidelines` | The guideline values you may use, each with `id`, `topic`, `value` and `source` |

## `summary`

| Key | Meaning |
|---|---|
| `timezone` | Time zone in which the days were formed |
| `dataUntil` | Time of the newest export file, in UTC. Data after that is not in the files. |
| `period` | `from`, `to`, `days`. The period ends on the last complete day. |
| `profile` | Date of birth, age, biological sex, wheelchair use, height, as far as the user allowed access |
| `notes` | How numbers were counted: which source was used where several devices recorded the same thing |
| `travel` | Periods in which the user slept in a far time zone: `from`, `to`, `nights` (the nights with sleep data in between), `hoursShifted` (by how many hours the sleep was shifted on average, in either direction). For these nights the sleep duration is kept and the bed and wake times are left out. |
| `stats` | Statistics per number (see below) |
| `weekly` | The complete weeks (Monday to Sunday) inside the period, oldest first, usually 51, as totals per week: `exerciseMin`, `workoutMin`, `workouts`, `workoutsStrength`. `windows.weekly` gives the dates. |
| `history` | Per calendar year: the mean of the daily values. For workout counts and workout minutes it is the total of the year. The first and the current year are usually incomplete. |
| `events` | Single events (see below) |
| `workoutGroups` | The kinds of training that occur: Walking (includes hiking), Running, Cycling, Strength, Other |
| `inventory` | Every data type that has records in the files, with the number of records and the first and last date (in UTC, so a date can differ by one day from the dates elsewhere). A type that is not listed has no records: no data or no access. Not every listed type is summarised: types such as swimming distance or running power appear here only. |
| `files` | The files in the folder with their status, kind, size, number of records and how many of them were already counted from another file |

## `windows`

Each time window has `from`, `to` and `daysInFarTimeZone`. A window in which the user was
mostly in a far time zone is a poor basis for a comparison.

| Window | Meaning |
|---|---|
| `last30` | The last 30 days of the period |
| `prev30` | The 30 days before those |
| `yearAgo30` | The same 30 days one year earlier |
| `last90` | The last 90 days |
| `year` | The whole period |
| `prevYear` | The period of the same length before it |
| `weekly` | The weeks of `summary.weekly` |
| `last14Days` | The days of `last14Days` |

## `summary.stats`

One entry per number. All values are per day unless stated otherwise.

| Key | Meaning |
|---|---|
| `last30`, `prev30`, `yearAgo30`, `last90`, `year`, `prevYear` | Mean of the number in that window |
| `direction` | `1`: higher is better. `-1`: lower is better. `0`: no fixed good direction, it depends on the person and their goals. |
| `usual30` | The user's usual range for a 30-day mean: 80 percent of all 30-day stretches of the period have a mean between these two values |
| `last30Is` | `below`, `within` or `above`: where `last30` lies compared with `usual30`. With `direction` it says whether the last 30 days are unusually good or bad for this user. |
| `perWeek` | Only for numbers that are stated per week: the window means and `usual30` multiplied by 7 |
| `daysWithData`, `daysLast30` | Number of days with a value in the period and in the last 30 days |
| `first`, `last` | Date of the first and the last value in the whole history. `last` can be one day after the end of the period, because the day of the export is incomplete and not counted. |
| `min`, `max`, `median` | Over the days of the period that have a value |
| `p10`, `p90` | The user's usual range for a single day: 80 percent of the days with a value lie between them |
| `sdLast30`, `sdYear` | How much the daily values vary (standard deviation) |
| `weekLast12`, `weekYear` | Mean per week over the last 12 complete weeks and over all complete weeks of the period. Only for `exerciseMin`, `workouts`, `workoutsStrength`, `workoutMin`. |
| `weeksWith150`, `weeksCounted` | Only for `exerciseMin`: the number of weeks with 150 minutes or more, and the number of weeks counted |

A key that is missing or `null` means that there was not enough data for it.

**Numbers per week.** `exerciseMin`, `workouts`, `workoutMin` and the numbers per kind of
training are stated per week. Use `perWeek`: `perWeek.last30` for the current state (the
dashboard shows the same number) and `perWeek.last90` to judge against a guideline.

**Workout numbers.** A day without a workout counts as zero in the window means. Their
`min`, `max`, `median`, `p10`, `p90` and `sd` cover only the days with a workout and are of
no use; do not state them.

**Numbers that are not recorded every day.** For `headphoneMin`, `envMin`, `daylightMin`,
`napH` and all measurements such as weight, the means cover only the days with a value.

### The numbers

| Name | Meaning | Unit |
|---|---|---|
| `steps`, `distanceKm`, `flights` | Steps, walking and running distance, flights of stairs | per day |
| `exerciseMin`, `activeKcal`, `standHours` | Exercise minutes, active energy, hours with standing, from the Activity rings | per day |
| `daylightMin` | Time in daylight | minutes per day |
| `restingHR`, `walkingHR` | Resting heart rate, average heart rate while walking | beats per minute |
| `hrv` | Heart rate variability (SDNN) | ms |
| `vo2max` | Cardio fitness | ml/kg/min |
| `hrRecovery` | Drop of the heart rate one minute after training | beats per minute |
| `respRate` | Breathing rate during sleep | breaths per minute |
| `spo2` | Blood oxygen | percent |
| `sleepH` | Time asleep in the main sleep of the night | hours |
| `deepH`, `remH`, `coreH`, `awakeH` | Sleep stages and time awake during the night | hours |
| `napH` | Sleep outside the main sleep | hours |
| `bedClock`, `wakeClock` | Time of falling asleep and of waking up, as hours of the clock. For `bedClock`, times after midnight continue past 24: 23.5 is 23:30, 24.5 is 00:30. | clock hours |
| `workouts`, `workoutMin` | Number and minutes of workouts | per day, see above |
| `workoutsWalking`, `workoutsRunning`, `workoutsCycling`, `workoutsStrength`, `workoutsOther` and the same with `workoutMin` | Per kind of training | per day, see above |
| `weightKg`, `leanKg` | Weight, lean body mass | kg |
| `bmi` | Body mass index | |
| `bodyFatPct` | Body fat | percent |
| `heightM` | Height | m |
| `walkSpeedKmh` | Walking speed | km/h |
| `stepLengthCm` | Step length | cm |
| `doubleSupportPct` | Share of the step with both feet on the ground | percent |
| `asymmetryPct` | Walking asymmetry | percent |
| `steadinessPct` | Walking steadiness | percent |
| `sixMinWalkM` | Estimated six-minute walk distance. Apple caps the estimate at 500 m: a constant 500 only says "500 or more". | m |
| `stairUpMs`, `stairDownMs` | Speed on stairs | m/s |
| `headphoneDb`, `envDb` | Sound level in headphones and around the user, weighted by duration | dB |
| `headphoneMin`, `envMin` | Time for which a sound level was recorded | minutes per day |

Which numbers exist depends on the user's devices and on the access they gave.

## `summary.events`

| Key | Meaning |
|---|---|
| `electrocardiograms` | All ECGs of the whole history: `date`, `classification` (Apple's own, for example `sinusRhythm`, `atrialFibrillation`, `inconclusive`), `averageHeartRate`, `symptoms` (`present`, `none`, or `notSet` if the user was not asked). Check the dates against the period. |
| `audioExposureEvents` | Notifications of the watch about loud surroundings (not about headphones): `all` (whole history), `inPeriod`, `dates` |
| `mindfulSessions` | `all`, `inPeriod`, `last` |
| `statesOfMind` | Logged moods and emotions: `all`, `inPeriod`, `first`, `last` |
| `scoredAssessments` | Questionnaires of the whole history: `date`, `type` (for example `PHQ9`, `GAD7`), `score`, `risk` (the classification stored with the record). Check the dates against the period. |
| `bloodPressure` | Readings in the period: `date`, `systolic`, `diastolic` |

## `sleepCounts`

A night is named by the evening it began on.

| Key | Meaning |
|---|---|
| `nights`, `nightsUnder7h`, `nightsUnder6h` | Over the period |
| `last30` | The same three counts for the 30 most recent nights with data |
| `sundayToThursdayNights` | Nights that are followed by a working day for most people: number of nights, mean sleep in hours, mean bed and wake time |
| `fridayAndSaturdayNights` | The same for nights followed by a free day |

Do not assume the user's week. If `context` says the user works shifts or weekends, do not
use this split.

## `previousRun`

| Key | Meaning |
|---|---|
| `date` | Date of the previous run |
| `headline`, `ratings` | Its headline and its rating per area |
| `recommendations` | Its recommendations as written to its findings, with `id`, `value`, `start` and `target` |
| `goals`, `good` | As written to its findings |
| `last30` | The `last30` value of every number at that run. Compare it with the current `last30`. |
