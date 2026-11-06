#!/usr/bin/env python3
"""Health50 analysis skill: reduce the exported files to a compact summary.

Reads every Health50 file in a folder (full exports, exports of a limited period, month
files and the index file) line by line, counts every record once, and writes one small
JSON file with daily values, statistics and events. The exported records themselves stay
where they are. Only the summary is meant to be read by the AI assistant.

Python standard library only. Usage:

    python3 summarize.py --folder "/path/to/Health50 files"

The folder is remembered in ~/.health50/settings.json, so later runs need no argument.
The summary is written to <folder>/analysis/<date of today>/summary.json.
"""
import argparse
import bisect
import calendar
import collections
import datetime as dt
import json
import math
import os
import sys
import time

try:
    from zoneinfo import ZoneInfo
except ImportError:  # Python older than 3.9
    ZoneInfo = None

SETTINGS = os.path.expanduser("~/.health50/settings.json")
SECTIONS = {b"quantities", b"categories", b"workouts", b"correlations", b"electrocardiograms", b"heartbeatSeries",
            b"audiograms", b"statesOfMind", b"scoredAssessments", b"activitySummaries", b"sources", b"profile", b"period"}
Q = "HKQuantityTypeIdentifier"
C = "HKCategoryTypeIdentifier"

# Amounts that add up over a day. Several devices can record the same steps, so these are
# collected per quarter of an hour and per source, and one source is chosen per quarter.
CUMULATIVE = {
    Q + "StepCount": "steps",
    Q + "DistanceWalkingRunning": "distanceKm",
    Q + "FlightsClimbed": "flights",
    Q + "TimeInDaylight": "daylightMin",
}
# Values that are averaged per day: name, factor.
DAILY_MEAN = {
    Q + "RestingHeartRate": ("restingHR", 1),
    Q + "HeartRateVariabilitySDNN": ("hrv", 1),
    Q + "WalkingHeartRateAverage": ("walkingHR", 1),
    Q + "RespiratoryRate": ("respRate", 1),
    Q + "OxygenSaturation": ("spo2", 100),
    Q + "VO2Max": ("vo2max", 1),
    Q + "HeartRateRecoveryOneMinute": ("hrRecovery", 1),
    Q + "AppleSleepingWristTemperature": ("wristTempC", 1),
    Q + "BloodPressureSystolic": ("systolic", 1),
    Q + "BloodPressureDiastolic": ("diastolic", 1),
    Q + "BodyMass": ("weightKg", 1),
    Q + "BodyFatPercentage": ("bodyFatPct", 100),
    Q + "LeanBodyMass": ("leanKg", 1),
    Q + "BodyMassIndex": ("bmi", 1),
    Q + "Height": ("heightM", 1),
    Q + "WalkingSpeed": ("walkSpeedKmh", 3.6),
    Q + "WalkingStepLength": ("stepLengthCm", 100),
    Q + "WalkingDoubleSupportPercentage": ("doubleSupportPct", 100),
    Q + "WalkingAsymmetryPercentage": ("asymmetryPct", 100),
    Q + "AppleWalkingSteadiness": ("steadinessPct", 100),
    Q + "SixMinuteWalkTestDistance": ("sixMinWalkM", 1),
    Q + "StairAscentSpeed": ("stairUpMs", 1),
    Q + "StairDescentSpeed": ("stairDownMs", 1),
}
# Sound levels: averaged by sound energy and duration, not by plain mean.
SOUND = {Q + "HeadphoneAudioExposure": "headphoneDb", Q + "EnvironmentalAudioExposure": "envDb"}
SLEEP = C + "SleepAnalysis"
MINDFUL = C + "MindfulSession"
AUDIO_EVENT = C + "AudioExposureEvent"

WORKOUT_GROUPS = {
    "walking": "Walking", "hiking": "Walking",
    "running": "Running",
    "cycling": "Cycling",
    "traditionalStrengthTraining": "Strength", "functionalStrengthTraining": "Strength", "coreTraining": "Strength",
}


# ---------------------------------------------------------------- time

class Clock:
    """Turns the UTC times of the files into seconds and into local calendar days."""

    def __init__(self, tz_name):
        self.name = tz_name or local_zone_name()
        self.zone = ZoneInfo(self.name) if (ZoneInfo and self.name) else None
        self._hour = {}
        self._off = {}

    def seconds(self, s):
        """'2026-11-05T05:58:12Z' (text or bytes) to seconds since 1970."""
        h = s[:13]
        e = self._hour.get(h)
        if e is None:
            e = self._hour[h] = calendar.timegm((int(s[0:4]), int(s[5:7]), int(s[8:10]), int(s[11:13]), 0, 0))
        return e + int(s[14:16]) * 60 + int(s[17:19])

    def offset(self, e):
        h = e // 3600
        o = self._off.get(h)
        if o is None:
            if self.zone:
                o = int(dt.datetime.fromtimestamp(h * 3600, self.zone).utcoffset().total_seconds())
            else:
                lt = time.localtime(h * 3600)
                o = calendar.timegm(lt) - h * 3600
            self._off[h] = o
        return o

    def day(self, e):
        """Local calendar day as a number of days since 1970-01-01."""
        return (e + self.offset(e)) // 86400

    def clock(self, e):
        """Local time of day in hours, 0 to 24."""
        return ((e + self.offset(e)) % 86400) / 3600.0


def local_zone_name():
    try:
        p = os.path.realpath("/etc/localtime")
        if "zoneinfo/" in p:
            return p.split("zoneinfo/", 1)[1]
    except OSError:
        pass
    return os.environ.get("TZ") or None


def date_of(day):
    return (dt.date(1970, 1, 1) + dt.timedelta(days=int(day))).isoformat()


# ---------------------------------------------------------------- folder and files

def resolve_folder(arg):
    if arg:
        folder = os.path.abspath(os.path.expanduser(arg))
        os.makedirs(os.path.dirname(SETTINGS), exist_ok=True)
        with open(SETTINGS, "w", encoding="utf-8") as f:
            json.dump({"folder": folder}, f, indent=2)
        return folder
    try:
        with open(SETTINGS, encoding="utf-8") as f:
            return json.load(f)["folder"]
    except (OSError, KeyError, ValueError):
        sys.exit("No folder given and none remembered. Run again with --folder <folder with the Health50 files>.")


def scan(folder):
    """Lists the Health50 files of the folder and reads their first line."""
    files = []
    for name in sorted(os.listdir(folder)):
        path = os.path.join(folder, name)
        if name.startswith(".") and name.endswith(".icloud"):
            files.append({"name": name[1:-7], "status": "not downloaded"})
            continue
        if not (name.startswith("health50-") and name.endswith(".json")) or not os.path.isfile(path):
            continue
        st = os.stat(path)
        info = {"name": name, "path": path, "bytes": st.st_size}
        # A file that a cloud service has not downloaded yet has a size but no content on this computer.
        if st.st_size > 0 and (getattr(st, "st_blocks", 1) == 0 or getattr(st, "st_flags", 0) & 0x40000000):
            info["status"] = "not downloaded"
            files.append(info)
            continue
        try:
            with open(path, "rb") as f:
                first = f.readline(1 << 20)
            head = json.loads(first.rstrip(b",\n") + b"}") if not first.rstrip().endswith(b"}") else json.loads(first)
            if head.get("format") != "health50":
                raise ValueError("no health50 format")
        except (OSError, ValueError):
            try:
                with open(path, "rb") as f:
                    head = json.load(f)
                if head.get("format") != "health50":
                    raise ValueError
            except (OSError, ValueError, MemoryError):
                info["status"] = "not a Health50 file"
                files.append(info)
                continue
        info.update(status="ok", kind=head.get("kind"), generatedAt=head.get("generatedAt", ""),
                    period=head.get("period") or {}, formatVersion=head.get("formatVersion"))
        if info["kind"] == "index":
            info["profile"] = head.get("profile")
        files.append(info)
    return files


def coverage(f):
    """The span of record start times a file can contain."""
    p, gen = f.get("period") or {}, f.get("generatedAt") or "9999"
    if f["kind"] == "month":
        return p.get("from", "0000"), min(p.get("to", gen), gen)
    if f["kind"] == "range":
        return p.get("from", "0000"), p.get("to", gen)
    return "0000", gen


def overlap_windows(files):
    """Time spans covered by more than one file. Only there a record can appear twice."""
    spans = [coverage(f) for f in files]
    wins = []
    for i in range(len(spans)):
        for j in range(i + 1, len(spans)):
            a, b = max(spans[i][0], spans[j][0]), min(spans[i][1], spans[j][1])
            if a <= b:
                wins.append((a, b))
    wins.sort()
    merged = []
    for a, b in wins:
        if merged and a <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], b))
        else:
            merged.append((a, b))
    return [w[0].encode() for w in merged], [w[1].encode() for w in merged]


# ---------------------------------------------------------------- reading

class State:
    def __init__(self, clock):
        self.clock = clock
        self.cum = {name: {} for name in CUMULATIVE.values()}             # name -> quarter -> {source: amount}
        self.mean = {v[0]: {} for v in DAILY_MEAN.values()}               # name -> (day, source) -> [sum, n]
        self.sound = {name: {} for name in SOUND.values()}                # name -> day -> [energy x seconds, seconds]
        self.sleep = []                                                   # (start, end, value, source)
        self.mindful, self.audio_events = [], []
        self.workouts, self.ecgs, self.minds, self.assessments, self.pressure = [], [], [], [], []
        self.rings = {}                                                   # date -> (generatedAt, record)
        self.inventory = {}                                               # type -> [records, first, last]
        self.sources = {}                                                 # "file:key" -> source entry
        self.profile = None
        self.profile_at = ""
        self.seen = set()


def read_file(fi, info, st, win_a, win_b):
    clock, seen = st.clock, st.seen
    loads = json.loads
    seconds, day = clock.seconds, clock.day
    srckeys = {}

    def src(key):
        k = srckeys.get(key)
        if k is None:
            k = srckeys[key] = sys.intern("%d:%s" % (fi, key))
        return k

    records = duplicates = 0
    section = None
    mode = name = None
    factor = 1
    inv = None
    gen = info["generatedAt"]
    with open(info["path"], "rb") as f:
        f.readline()
        for raw in f:
            c = raw[0]
            if c == 123:  # a record: {
                rec = None
                if raw[43:54] == b'","start":"':
                    rid, start = raw[7:43], raw[54:74]
                else:
                    cut = raw.find(b',"route":[') if section == b"workouts" else -1
                    rec = loads(raw[:cut] + b"}" if cut > 0 else raw.rstrip(b",\n"))
                    if section == b"activitySummaries":
                        old = st.rings.get(rec["date"])
                        if old is None or old[0] < gen:
                            st.rings[rec["date"]] = (gen, rec)
                        records += 1
                        continue
                    rid, start = rec.get("id", "").encode(), rec.get("start", "").encode()
                if win_a:
                    i = bisect.bisect_right(win_a, start) - 1
                    if i >= 0 and start <= win_b[i]:
                        if rid in seen:
                            duplicates += 1
                            continue
                        seen.add(rid)
                records += 1
                if inv is None:
                    inv = st.inventory.setdefault(section.decode(), [0, start, start])
                inv[0] += 1
                if start < inv[1]:
                    inv[1] = start
                if start > inv[2]:
                    inv[2] = start
                if mode is None:
                    continue
                if rec is None:
                    if mode == "ecg":
                        cut = raw.find(b',"voltages":')
                        rec = loads(raw[:cut] + b"}" if cut > 0 else raw.rstrip(b",\n"))
                    else:
                        rec = loads(raw[:-2] if raw[-2:] == b",\n" else raw)
                s = seconds(start)
                if mode == "cum":
                    d = name.get(s // 900)
                    if d is None:
                        d = name[s // 900] = {}
                    k = src(rec["source"])
                    d[k] = d.get(k, 0) + rec["value"]
                elif mode == "mean":
                    k = (day(s), src(rec["source"]))
                    d = name.get(k)
                    if d is None:
                        name[k] = [rec["value"] * factor, 1]
                    else:
                        d[0] += rec["value"] * factor
                        d[1] += 1
                elif mode == "sound":
                    dur = max(1, seconds(rec["end"]) - s) if "end" in rec else 1
                    d = name.setdefault(day(s), [0.0, 0])
                    d[0] += 10 ** (rec["value"] / 10.0) * dur
                    d[1] += dur
                elif mode == "sleep":
                    st.sleep.append((s, seconds(rec.get("end", rec["start"])), rec.get("value", ""), src(rec["source"])))
                elif mode == "mindful":
                    st.mindful.append((s, (seconds(rec.get("end", rec["start"])) - s) / 60.0))
                elif mode == "audio":
                    st.audio_events.append((s, rec.get("value", "")))
                elif mode == "workout":
                    stats = rec.get("statistics") or {}
                    st.workouts.append({
                        "s": s, "e": seconds(rec.get("end", rec["start"])), "activity": rec.get("activity", "other"),
                        "min": rec.get("duration", 0) / 60.0, "src": src(rec["source"]),
                        "kcal": (stats.get(Q + "ActiveEnergyBurned") or {}).get("sum"),
                        "km": next((v.get("sum") for k, v in stats.items() if k.startswith(Q + "Distance") and v.get("unit") == "km"), None),
                        "hr": (stats.get(Q + "HeartRate") or {}).get("average"),
                    })
                elif mode == "ecg":
                    st.ecgs.append((s, rec.get("classification", ""), (rec.get("averageHeartRate") or {}).get("value"), rec.get("symptomsStatus", "")))
                elif mode == "mind":
                    st.minds.append((s, rec.get("kind", ""), rec.get("valence"), rec.get("valenceClassification", "")))
                elif mode == "assessment":
                    st.assessments.append((s, rec.get("type", ""), rec.get("score"), rec.get("risk", "")))
                elif mode == "correlation" and rec.get("type", "").endswith("BloodPressure"):
                    v = {m.get("type", ""): m.get("value") for m in rec.get("samples", [])}
                    st.pressure.append((s, v.get(Q + "BloodPressureSystolic"), v.get(Q + "BloodPressureDiastolic")))
            elif c == 34:  # a key: "
                key = raw[1:raw.index(b'"', 1)]
                if key in SECTIONS:
                    section, mode, inv = key, None, None
                    if key == b"profile":
                        try:
                            p = loads(b"{" + raw.rstrip(b",\n") + b"}")["profile"]
                            if gen >= st.profile_at:
                                st.profile, st.profile_at = p, gen
                        except ValueError:
                            pass
                    else:
                        mode = {b"workouts": "workout", b"electrocardiograms": "ecg", b"statesOfMind": "mind",
                                b"scoredAssessments": "assessment", b"correlations": "correlation"}.get(key)
                elif section in (b"quantities", b"categories"):
                    t = key.decode()
                    inv = st.inventory.setdefault(t, [0, b"9", b""])
                    if t in CUMULATIVE:
                        mode, name = "cum", st.cum[CUMULATIVE[t]]
                    elif t in DAILY_MEAN:
                        mode, name, factor = "mean", st.mean[DAILY_MEAN[t][0]], DAILY_MEAN[t][1]
                    elif t in SOUND:
                        mode, name = "sound", st.sound[SOUND[t]]
                    else:
                        mode = {SLEEP: "sleep", MINDFUL: "mindful", AUDIO_EVENT: "audio"}.get(t)
                elif section == b"sources":
                    try:
                        for k, v in loads(b"{" + raw.rstrip(b",\n") + b"}").items():
                            st.sources[src(k)] = v
                    except ValueError:
                        pass
    return records, duplicates


# ---------------------------------------------------------------- sources

def kind_of(source):
    """Groups the many source entries (one per device and software version) into a few kinds."""
    bundle, device, name = source.get("bundleId", ""), source.get("device", ""), source.get("name", "")
    if bundle.startswith("com.apple.health"):
        return "watch" if device.startswith("Watch") or "watch" in name.lower() else "phone"
    return bundle or name or "unknown"


def rank(kind):
    return {"watch": 0, "phone": 1}.get(kind, 2), kind


# ---------------------------------------------------------------- building the summary

def mean(values):
    values = [v for v in values if v is not None]
    return sum(values) / len(values) if values else None


def rnd(v, digits=2):
    if v is None:
        return None
    r = round(v, digits)
    return int(r) if r == int(r) else r


def build(st, files, days):
    clock = st.clock
    kinds = {k: kind_of(v) for k, v in st.sources.items()}
    kind_names = {}
    for k, v in st.sources.items():
        kind_names.setdefault(kinds[k], {"watch": "Apple Watch", "phone": "iPhone"}.get(kinds[k], v.get("name", kinds[k])))
    newest = max(f["generatedAt"] for f in files)
    end = clock.day(clock.seconds(newest)) - 1          # the last complete day
    start = end - days + 1
    notes = {"days": "calendar days are counted in the time zone " + (clock.name or "of this computer")}
    daily = {}                                          # name -> {day: value}, whole history

    # amounts: per quarter of an hour the watch counts first, then the phone, then other apps
    for name, quarters in st.cum.items():
        out, used = collections.defaultdict(float), collections.Counter()
        for q, by_src in quarters.items():
            by_kind = {}
            for s, v in by_src.items():
                k = kinds.get(s, "unknown")
                by_kind[k] = by_kind.get(k, 0) + v
            best = min(by_kind, key=rank)
            d = clock.day(q * 900)
            out[d] += by_kind[best]
            if d >= start:
                used[best] += 1
        if out:
            daily[name] = dict(out)
            notes[name] = "per quarter of an hour one source is counted: " + ", ".join(
                "%s %d%%" % (kind_names.get(k, k), round(100 * n / sum(used.values()))) for k, n in used.most_common()) if used else ""

    # daily means: the source with the most days in the period is used, others fill its gaps
    for name, cells in st.mean.items():
        by_day, days_of = collections.defaultdict(dict), collections.Counter()
        for (d, s), (total, n) in cells.items():
            k = kinds.get(s, "unknown")
            a = by_day[d].setdefault(k, [0.0, 0])
            a[0] += total
            a[1] += n
        for d, ks in by_day.items():
            if d >= start:
                for k in ks:
                    days_of[k] += 1
        if not by_day:
            continue
        main = days_of.most_common(1)[0][0] if days_of else None
        out = {}
        for d, ks in by_day.items():
            a = ks.get(main) or max(ks.values(), key=lambda x: x[1])
            out[d] = a[0] / a[1]
        daily[name] = out
        if len(days_of) > 1:
            notes[name] = "main source: %s; also present: %s" % (kind_names.get(main, main), ", ".join(kind_names.get(k, k) for k in days_of if k != main))

    for name, cells in st.sound.items():
        if cells:
            daily[name] = {d: 10 * math.log10(e / secs) for d, (e, secs) in cells.items() if secs}
            daily[name.replace("Db", "Min")] = {d: secs / 60.0 for d, (e, secs) in cells.items()}

    # the activity rings are Apple's own daily totals
    for date, (_, rec) in st.rings.items():
        try:
            d = (dt.date.fromisoformat(date) - dt.date(1970, 1, 1)).days
        except ValueError:
            continue
        if d < 16000:   # before 2014: empty entries
            continue
        for key, name in (("activeEnergy", "activeKcal"), ("exerciseTime", "exerciseMin"), ("standHours", "standHours")):
            v = (rec.get(key) or {}).get("value")
            if v is not None:
                daily.setdefault(name, {})[d] = v

    sleep, sleep_note, travel = build_sleep(st, kinds, kind_names, start, end)
    daily.update(sleep)
    if sleep_note:
        notes["sleep"] = sleep_note

    # workouts: the same training recorded by two devices counts once
    kept, by_day = [], collections.defaultdict(list)
    for w in sorted(st.workouts, key=lambda w: (rank(kinds.get(w["src"], "unknown")), w["s"])):
        d = w["s"] // 86400
        dup = False
        for other in by_day[d - 1] + by_day[d] + by_day[d + 1]:
            common = min(w["e"], other["e"]) - max(w["s"], other["s"])
            if common > 0.5 * min(w["e"] - w["s"], other["e"] - other["s"]) and kinds.get(other["src"]) != kinds.get(w["src"]):
                dup = True
                break
        if not dup:
            kept.append(w)
            by_day[d].append(w)
    kept.sort(key=lambda w: w["s"])
    groups = sorted({WORKOUT_GROUPS.get(w["activity"], "Other") for w in kept})
    for w in kept:
        d, g = clock.day(w["s"]), WORKOUT_GROUPS.get(w["activity"], "Other")
        for name, v in (("workoutMin", w["min"]), ("workouts", 1), ("workoutMin" + g, w["min"]), ("workouts" + g, 1)):
            daily.setdefault(name, {})[d] = daily.get(name, {}).get(d, 0) + v
    if len(kept) < len(st.workouts):
        notes["workouts"] = "%d of %d workouts were recorded by two sources and are counted once" % (len(st.workouts) - len(kept), len(st.workouts))

    # ---- statistics
    def window(name, a, b):
        src = daily.get(name) or {}
        return [src[d] for d in range(a, b + 1) if d in src]

    additive = {"workoutMin", "workouts"} | {p + g for p in ("workoutMin", "workouts") for g in groups}
    stats, history, series = {}, {}, {}
    for name, src in sorted(daily.items()):
        if not src:
            continue
        year = window(name, start, end)
        add = name in additive

        def avg(a, b, need=1):
            v = window(name, a, b)
            if add:      # days without a workout are days with zero
                return sum(v) / (b - a + 1) if (v or year) else None
            return sum(v) / len(v) if len(v) >= need else None

        s = {
            "last30": avg(end - 29, end), "prev30": avg(end - 59, end - 30), "yearAgo30": avg(end - 394, end - 365),
            "last90": avg(end - 89, end), "year": avg(start, end), "prevYear": avg(start - days, start - 1),
            "daysWithData": len(year), "daysLast30": len(window(name, end - 29, end)),
            "first": date_of(min(src)), "last": date_of(max(src)),
        }
        if year:
            srt = sorted(year)
            s.update(min=srt[0], max=srt[-1], p10=srt[int(len(srt) * .1)], p90=srt[int(len(srt) * .9)], median=srt[len(srt) // 2])
            m30 = window(name, end - 29, end)
            if len(m30) > 2:
                s["sdLast30"] = (sum((v - sum(m30) / len(m30)) ** 2 for v in m30) / (len(m30) - 1)) ** .5
            s["sdYear"] = (sum((v - sum(year) / len(year)) ** 2 for v in year) / max(1, len(year) - 1)) ** .5
        stats[name] = {k: (rnd(v) if isinstance(v, float) else v) for k, v in s.items()}
        per_year = collections.defaultdict(list)
        for d, v in src.items():
            per_year[date_of(d)[:4]].append(v)
        # per calendar year: the mean of the daily values, or the total for workout counts and minutes
        history[name] = {y: rnd(sum(v) if add else sum(v) / len(v)) for y, v in sorted(per_year.items())}
        if year:
            series[name] = [rnd(src.get(d), 2) if d in src else None for d in range(start, end + 1)]

    # weeks from Monday to Sunday, the last 52 complete ones
    last_sunday = end - ((dt.date(1970, 1, 1) + dt.timedelta(days=end)).weekday() + 1) % 7
    weekly = {}
    for name in ("exerciseMin", "workoutMin", "workouts", "workoutsStrength"):
        src = daily.get(name)
        if src:
            weekly[name] = [rnd(sum(src.get(d, 0) for d in range(last_sunday - 7 * k - 6, last_sunday - 7 * k + 1))) for k in range(51, -1, -1)]
    if "exerciseMin" in weekly:
        w = weekly["exerciseMin"]
        stats["exerciseMin"].update(weekLast12=rnd(mean(w[-12:])), weekYear=rnd(mean(w)), weeksWith150=sum(1 for v in w if v >= 150), weeksCounted=len(w))
    for name in ("workouts", "workoutsStrength", "workoutMin"):
        if name in weekly:
            stats[name].update(weekLast12=rnd(mean(weekly[name][-12:])), weekYear=rnd(mean(weekly[name])))

    def in_period(s):
        return start <= clock.day(s) <= end + 1

    profile = dict(st.profile or next((f["profile"] for f in files if f.get("profile")), None) or {})
    if profile.get("dateOfBirth"):
        try:
            born, today = dt.date.fromisoformat(profile["dateOfBirth"][:10]), dt.date.fromisoformat(date_of(end))
            profile["age"] = today.year - born.year - ((today.month, today.day) < (born.month, born.day))
        except ValueError:
            pass
    if "heightM" in daily:
        profile["heightM"] = rnd(daily["heightM"][max(daily["heightM"])])

    return {
        "format": "health50-summary", "formatVersion": 1,
        "generatedAt": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "timezone": clock.name or "computer setting",
        "dataUntil": newest,
        "period": {"from": date_of(start), "to": date_of(end), "days": days},
        "profile": profile,
        "notes": notes,
        "travel": travel,
        "stats": stats,
        "weekly": weekly,
        "history": history,
        "events": {
            "electrocardiograms": [{"date": date_of(clock.day(s)), "classification": c, "averageHeartRate": rnd(hr, 0), "symptoms": sym} for s, c, hr, sym in sorted(st.ecgs)],
            "audioExposureEvents": {"all": len(st.audio_events), "inPeriod": sum(1 for s, _ in st.audio_events if in_period(s)),
                                    "dates": [date_of(clock.day(s)) for s, _ in sorted(st.audio_events) if in_period(s)]},
            "mindfulSessions": {"all": len(st.mindful), "inPeriod": sum(1 for s, _ in st.mindful if in_period(s)),
                                "last": date_of(clock.day(max(s for s, _ in st.mindful))) if st.mindful else None},
            "statesOfMind": {"all": len(st.minds), "inPeriod": sum(1 for m in st.minds if in_period(m[0])),
                             "first": date_of(clock.day(min(m[0] for m in st.minds))) if st.minds else None,
                             "last": date_of(clock.day(max(m[0] for m in st.minds))) if st.minds else None},
            "scoredAssessments": [{"date": date_of(clock.day(s)), "type": t.replace("HKScoredAssessmentTypeIdentifier", ""), "score": sc, "risk": r} for s, t, sc, r in sorted(st.assessments)],
            "bloodPressure": [{"date": date_of(clock.day(s)), "systolic": rnd(a, 0), "diastolic": rnd(b, 0)} for s, a, b in sorted(st.pressure) if in_period(s)],
        },
        "workoutGroups": groups,
        "workouts": [{"date": date_of(clock.day(w["s"])), "activity": w["activity"], "group": WORKOUT_GROUPS.get(w["activity"], "Other"),
                      "min": rnd(w["min"], 0), "kcal": rnd(w["kcal"], 0), "km": rnd(w["km"], 1), "hr": rnd(w["hr"], 0)} for w in kept if in_period(w["s"])],
        "inventory": {t: {"records": v[0], "first": v[1].decode()[:10], "last": v[2].decode()[:10]} for t, v in sorted(st.inventory.items()) if v[0]},
        "series": series,
    }


def build_sleep(st, kinds, kind_names, start, end):
    """One main sleep per night and per source, then one source per night.

    The files hold no time zone for most sleep records. So a night is not cut at a fixed
    time of day: records that follow each other form one sleep, and that sleep belongs to
    the evening it started on. Nights slept in a far time zone are recognised by their
    shifted hours; their bed and wake times are left out because the local time is unknown.
    """
    clock = st.clock
    by_kind = collections.defaultdict(list)
    for s, e, value, source in st.sleep:
        if e > s and value.startswith("asleep"):
            by_kind[kinds.get(source, "unknown")].append((s, e, value))

    def union(items):
        total, edge = 0, 0
        for s, e, _ in items:
            if e > edge:
                total += e - max(s, edge)
                edge = e
        return total

    nights = collections.defaultdict(dict)        # night -> kind -> main sleep
    for kind, items in by_kind.items():
        items.sort()
        blocks, cur, edge = [], [items[0]], items[0][1]
        for it in items[1:]:
            if it[0] - edge <= 5400:              # awake for up to 90 minutes: still the same sleep
                cur.append(it)
            else:
                blocks.append(cur)
                cur = [it]
            edge = max(edge, it[1])
        blocks.append(cur)
        naps = collections.Counter()
        for block in blocks:
            asleep, bed, wake = union(block), block[0][0], max(it[1] for it in block)
            night = (bed + clock.offset(bed) - 12 * 3600) // 86400
            old = nights[night].get(kind)
            if old and old["asleep"] >= asleep:
                naps[night] += asleep
                continue
            if old:
                naps[night] += old["asleep"]
            stage = collections.Counter()
            for s, e, v in block:
                stage[v] += e - s
            nights[night][kind] = {"asleep": asleep, "bed": bed, "wake": wake, "stage": stage}
        for night, secs in naps.items():
            if kind in nights[night]:
                nights[night][kind]["nap"] = secs
    for night in list(nights):
        nights[night] = {k: v for k, v in nights[night].items() if v["asleep"] >= 2 * 3600}
        if not nights[night]:
            del nights[night]
    count = collections.Counter(k for n, ks in nights.items() if start <= n <= end for k in ks)
    if not count:
        count = collections.Counter(k for ks in nights.values() for k in ks)
    if not count:
        return {}, "", []
    main_kind = count.most_common(1)[0][0]
    picked, filled = {}, 0
    for night, ks in nights.items():
        if main_kind in ks:
            picked[night] = ks[main_kind]
        else:
            picked[night] = max(ks.values(), key=lambda x: x["asleep"])
            filled += start <= night <= end

    # nights in a far time zone: the middle of the sleep is more than 3 hours away from the usual one
    def middle(v):
        return (clock.clock((v["bed"] + v["wake"]) // 2) - 12) % 24
    recent = sorted(middle(v) for n, v in picked.items() if n > end - 730)
    usual = recent[len(recent) // 2] if recent else 15.5
    shift = {n: ((middle(v) - usual + 12) % 24) - 12 for n, v in picked.items()}
    away = {n for n, d in shift.items() if abs(d) > 3 and any(abs(shift.get(m, 0)) > 3 and shift[m] * d > 0 for m in (n - 2, n - 1, n + 1, n + 2))}

    out = collections.defaultdict(dict)
    for night, v in picked.items():
        asleep, stage = v["asleep"], v["stage"]
        scale = asleep / sum(stage.values())          # in case two records cover the same minutes
        out["sleepH"][night] = asleep / 3600.0
        out["awakeH"][night] = max(0, v["wake"] - v["bed"] - asleep) / 3600.0
        for key, name in (("asleepDeep", "deepH"), ("asleepREM", "remH"), ("asleepCore", "coreH")):
            if stage[key]:
                out[name][night] = stage[key] * scale / 3600.0
        if v.get("nap"):
            out["napH"][night] = v["nap"] / 3600.0
        if night not in away:
            bed = clock.clock(v["bed"])
            out["bedClock"][night] = bed + (24 if bed < 12 else 0)      # 23.5 is 23:30, 24.5 is 00:30
            out["wakeClock"][night] = clock.clock(v["wake"])
    spans, run = [], []
    for night in sorted(n for n in away if start <= n <= end):
        if run and night - run[-1] > 3:
            spans.append(run)
            run = []
        run.append(night)
    if run:
        spans.append(run)
    travel = [{"from": date_of(r[0]), "to": date_of(r[-1]), "nights": len(r), "hoursShifted": rnd(mean([shift[n] for n in r]), 0)} for r in spans]
    note = "main source: %s (%d nights in the period)" % (kind_names.get(main_kind, main_kind), count[main_kind])
    others = [k for k in count if k != main_kind]
    if others and filled:
        note += "; %s fills %d nights the main source did not record" % (", ".join(kind_names.get(k, k) for k in others), filled)
    if travel:
        note += "; %d nights were slept in a far time zone, their bed and wake times are left out" % sum(x["nights"] for x in travel)
    return dict(out), note, travel


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description="Reduce Health50 export files to a compact summary.")
    ap.add_argument("--folder", help="folder with the Health50 files (remembered for later runs)")
    ap.add_argument("--out", help="where to write the summary (default: <folder>/analysis/<today>/summary.json)")
    ap.add_argument("--timezone", help="time zone for calendar days, for example Europe/London (default: this computer's)")
    ap.add_argument("--days", type=int, default=365, help="length of the analysed period in days (default: 365)")
    args = ap.parse_args()

    folder = resolve_folder(args.folder)
    if not os.path.isdir(folder):
        sys.exit("The folder does not exist: " + folder)
    files = scan(folder)
    usable = [f for f in files if f["status"] == "ok" and f["kind"] != "index"]
    for f in files:
        if f["status"] != "ok":
            print("! %s: %s" % (f["name"], f["status"]))
    if not usable:
        sys.exit("No readable Health50 export in " + folder)

    usable.sort(key=lambda f: f["generatedAt"], reverse=True)
    usable.sort(key=lambda f: f["kind"] != "month")           # month files first, then the newest file first
    win_a, win_b = overlap_windows(usable)
    st = State(Clock(args.timezone))
    for fi, f in enumerate(usable):
        t0 = time.time()
        f["records"], f["duplicates"] = read_file(fi, f, st, win_a, win_b)
        print("read %s: %s records, %s already counted, %.0f s" % (f["name"], format(f["records"], ","), format(f["duplicates"], ","), time.time() - t0))

    summary = build(st, files, args.days)
    summary["files"] = [{k: f.get(k) for k in ("name", "status", "kind", "generatedAt", "bytes", "records", "duplicates") if f.get(k) is not None} for f in files]
    out = args.out or os.path.join(folder, "analysis", dt.date.today().isoformat(), "summary.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, separators=(",", ":"))
    print("period %s to %s, time zone %s" % (summary["period"]["from"], summary["period"]["to"], summary["timezone"]))
    print("summary written: %s (%s bytes)" % (out, format(os.path.getsize(out), ",")))


if __name__ == "__main__":
    main()
