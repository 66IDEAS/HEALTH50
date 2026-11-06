#!/usr/bin/env python3
"""Health50 analysis skill: print what the AI assistant reads to judge a run.

The summary of a run holds a value for every day of the period, which is more than an AI
assistant should read. This script prints the part that matters for the judgement as JSON:
the statistics, a few counts taken from the daily values, the user's goals and conditions,
the guidelines, and the previous run for the comparison.

Python standard library only. Usage:

    python3 digest.py                       the latest run; also saved as digest.json in the run's folder
    python3 digest.py --run 2026-11-06      a certain run
    python3 digest.py --series sleepH,steps the daily values of these numbers, for follow-up questions
    python3 digest.py --workouts            the list of workouts of the period
"""
import argparse
import datetime as dt
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SETTINGS = os.path.expanduser("~/.health50/settings.json")
LEAVE_OUT = ("series", "workouts")

# Which direction is an improvement: 1 higher is better, -1 lower is better, 0 depends on the person.
DIRECTION = {
    "steps": 1, "exerciseMin": 1, "activeKcal": 1, "distanceKm": 1, "flights": 1, "standHours": 1, "daylightMin": 1,
    "restingHR": -1, "walkingHR": -1, "hrv": 1, "vo2max": 1, "hrRecovery": 1, "spo2": 1, "respRate": 0,
    "sleepH": 1, "awakeH": -1, "deepH": 0, "remH": 0, "coreH": 0, "napH": 0, "bedClock": 0, "wakeClock": 0,
    "workouts": 1, "workoutMin": 1, "weightKg": 0, "bmi": 0, "bodyFatPct": 0, "leanKg": 1, "heightM": 0,
    "walkSpeedKmh": 1, "stepLengthCm": 1, "doubleSupportPct": -1, "asymmetryPct": -1, "steadinessPct": 1,
    "sixMinWalkM": 1, "stairUpMs": 1, "stairDownMs": 1, "headphoneDb": -1, "envDb": -1, "headphoneMin": 0, "envMin": 0,
}
PER_WEEK = ("last30", "prev30", "yearAgo30", "last90", "year", "prevYear")


def additive(name):
    """Workout counts and minutes: a day without a workout is a day with zero."""
    return name.startswith("workout")


def usual30(values, zeros):
    """The range in which 80 percent of the 30-day means of the period lie."""
    means = []
    for i in range(29, len(values)):
        w = values[i - 29:i + 1]
        if zeros:
            means.append(sum(v or 0 for v in w) / 30.0)
        else:
            w = [v for v in w if v is not None]
            if len(w) >= 3:
                means.append(sum(w) / len(w))
    if len(means) < 60:
        return None
    means.sort()
    return [round(means[int(len(means) * .1)], 2), round(means[int(len(means) * .9)], 2)]


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def clock(v):
    """23.5 -> '23:30', 24.5 -> '00:30'."""
    if v is None:
        return None
    m = int(round(v * 60)) % 1440
    return "%02d:%02d" % (m // 60, m % 60)


def mean(a):
    a = [v for v in a if v is not None]
    return round(sum(a) / len(a), 2) if a else None


def sleep_counts(series, first):
    """Counts over the nights of the period. A night is named by the evening it began on."""
    hours = series.get("sleepH") or []
    nights = [(first + dt.timedelta(days=i), i) for i, v in enumerate(hours) if v is not None]
    if not nights:
        return None
    out = {"nights": len(nights),
           "nightsUnder7h": sum(1 for _, i in nights if hours[i] < 7),
           "nightsUnder6h": sum(1 for _, i in nights if hours[i] < 6)}
    recent = nights[-30:]
    out["last30"] = {"nights": len(recent), "nightsUnder7h": sum(1 for _, i in recent if hours[i] < 7),
                     "nightsUnder6h": sum(1 for _, i in recent if hours[i] < 6)}
    # Friday and Saturday evening are followed by a day that is free for most people.
    for name, days in (("sundayToThursdayNights", (6, 0, 1, 2, 3)), ("fridayAndSaturdayNights", (4, 5))):
        idx = [i for d, i in nights if d.weekday() in days]
        bed, wake = series.get("bedClock") or [], series.get("wakeClock") or []
        out[name] = {"nights": len(idx), "sleepH": mean([hours[i] for i in idx]),
                     "bed": clock(mean([bed[i] for i in idx if i < len(bed)])),
                     "wake": clock(mean([wake[i] for i in idx if i < len(wake)]))}
    return out


def main():
    ap = argparse.ArgumentParser(description="Print what the AI assistant reads to judge a Health50 run.")
    ap.add_argument("--folder", help="folder with the Health50 files (default: the remembered one)")
    ap.add_argument("--run", help="date of the run, for example 2026-11-06 (default: the latest)")
    ap.add_argument("--series", help="print the daily values of these numbers instead, separated by commas")
    ap.add_argument("--workouts", action="store_true", help="print the workouts of the period instead")
    args = ap.parse_args()

    try:
        folder = args.folder or load(SETTINGS)["folder"]
    except (OSError, KeyError, ValueError):
        sys.exit("No folder given and none remembered. Run summarize.py with --folder first.")
    analysis = os.path.join(folder, "analysis")
    runs = sorted(d for d in (os.listdir(analysis) if os.path.isdir(analysis) else [])
                  if os.path.isfile(os.path.join(analysis, d, "summary.json")))
    if not runs:
        sys.exit("No run found in %s. Run summarize.py first." % analysis)
    run = args.run or runs[-1]
    if run not in runs:
        sys.exit("No run of %s. Runs: %s" % (run, ", ".join(runs)))
    summary = load(os.path.join(analysis, run, "summary.json"))
    series = summary.get("series") or {}
    first = dt.date.fromisoformat(summary["period"]["from"])

    if args.series:
        names = [n.strip() for n in args.series.split(",") if n.strip()]
        unknown = [n for n in names if n not in series]
        if unknown:
            sys.exit("Unknown: %s. Available: %s" % (", ".join(unknown), ", ".join(sorted(series))))
        days = [(first + dt.timedelta(days=i)).isoformat() for i in range(max(len(series[n]) for n in names))]
        json.dump({"days": days, **{n: series[n] for n in names}}, sys.stdout, ensure_ascii=False, separators=(",", ":"))
        print()
        return
    if args.workouts:
        json.dump(summary.get("workouts") or [], sys.stdout, ensure_ascii=False, separators=(",", ":"))
        print()
        return

    out = {"run": run, "runFolder": os.path.join(analysis, run),
           "writeFindingsTo": os.path.join(analysis, run, "findings.json"),
           "contextFile": os.path.join(analysis, "context.md")}
    try:
        with open(out["contextFile"], encoding="utf-8") as f:
            out["context"] = f.read()
    except OSError:
        out["context"] = None          # the user has not been asked for goals and conditions yet

    out["summary"] = {k: v for k, v in summary.items() if k not in LEAVE_OUT}

    # the dates behind the names of the time windows, and how many days of each lie in a far time zone
    last, n = dt.date.fromisoformat(summary["period"]["to"]), summary["period"]["days"]
    spans = [(dt.date.fromisoformat(t["from"]), dt.date.fromisoformat(t["to"])) for t in summary.get("travel") or []]
    day = dt.timedelta(days=1)

    def window(a, b):
        away = sum(max(0, (min(b, y) - max(a, x)).days + 1) for x, y in spans)
        return {"from": a.isoformat(), "to": b.isoformat(), "daysInFarTimeZone": away}
    out["windows"] = {"last30": window(last - 29 * day, last), "prev30": window(last - 59 * day, last - 30 * day),
                      "yearAgo30": window(last - 394 * day, last - 365 * day), "last90": window(last - 89 * day, last),
                      "year": window(first, last), "prevYear": window(first - n * day, first - day)}
    sunday = last - ((last.weekday() + 1) % 7) * day
    weeks = max([len(v) for v in (summary.get("weekly") or {}).values()] or [0])
    out["windows"]["weekly"] = {"from": (sunday - (weeks * 7 - 1) * day).isoformat(), "to": sunday.isoformat(), "weeks": weeks}
    out["windows"]["last14Days"] = {"from": (last - 13 * day).isoformat(), "to": last.isoformat()}

    # per number: which direction is good, the usual range of its 30-day means, and values per week
    for name, st in out["summary"]["stats"].items():
        base = name
        for group in summary.get("workoutGroups") or []:
            if name.endswith(group):
                base = name[:-len(group)]
        st["direction"] = DIRECTION.get(base, 0)
        rng = usual30(series.get(name) or [], additive(name))
        per_week = additive(name) or name == "exerciseMin"
        if rng and st.get("last30") is not None:
            st["usual30"] = rng
            st["last30Is"] = "below" if st["last30"] < rng[0] else "above" if st["last30"] > rng[1] else "within"
        if per_week:
            st["perWeek"] = {k: round(st[k] * 7, 2) for k in PER_WEEK if st.get(k) is not None}
            if rng:
                st["perWeek"]["usual30"] = [round(rng[0] * 7, 2), round(rng[1] * 7, 2)]

    out["seriesNames"] = sorted(series)
    out["last14Days"] = {n: v[-14:] for n, v in sorted(series.items()) if any(x is not None for x in v[-14:])}
    for n in ("bedClock", "wakeClock"):
        if n in out["last14Days"]:
            out["last14Days"][n] = [clock(v) for v in out["last14Days"][n]]
    out["sleepCounts"] = sleep_counts(series, first)
    out["lastWorkouts"] = (summary.get("workouts") or [])[-10:]

    earlier = [r for r in runs if r < run and os.path.isfile(os.path.join(analysis, r, "findings.json"))]
    if earlier:
        prev = earlier[-1]
        ps, pf = load(os.path.join(analysis, prev, "summary.json")), load(os.path.join(analysis, prev, "findings.json"))
        out["previousRun"] = {
            "date": prev, "headline": pf.get("headline"),
            "ratings": {k: v.get("rating") for k, v in (pf.get("areas") or {}).items()},
            "recommendations": pf.get("recommendations") or [], "goals": pf.get("goals"), "good": pf.get("good"),
            "last30": {k: v.get("last30") for k, v in (ps.get("stats") or {}).items()},
        }
    else:
        out["previousRun"] = None
    out["allRuns"] = runs
    out["guidelines"] = load(os.path.join(HERE, "..", "guidelines.json"))["guidelines"]

    lines = []
    emit(out, lines)
    text = "\n".join(lines) + "\n"
    with open(os.path.join(analysis, run, "digest.json"), "w", encoding="utf-8") as f:
        f.write(text)
    sys.stdout.write(text)


def emit(v, lines, depth=0, key=None, last=True):
    """Compact JSON that is still readable: the upper levels and lists of objects are broken into lines."""
    pad = " " * depth
    head = pad + (json.dumps(key) + ": " if key is not None else "")
    tail = "" if last else ","
    if isinstance(v, dict) and v and depth < 3 and key not in ("run", "context"):
        lines.append(head + "{")
        items = list(v.items())
        for i, (k, x) in enumerate(items):
            emit(x, lines, depth + 1, k, i == len(items) - 1)
        lines.append(pad + "}" + tail)
    elif isinstance(v, list) and v and isinstance(v[0], dict):
        lines.append(head + "[")
        for i, x in enumerate(v):
            lines.append(pad + " " + json.dumps(x, ensure_ascii=False, separators=(",", ":")) + ("" if i == len(v) - 1 else ","))
        lines.append(pad + "]" + tail)
    else:
        lines.append(head + json.dumps(v, ensure_ascii=False, separators=(",", ":")) + tail)


if __name__ == "__main__":
    main()
