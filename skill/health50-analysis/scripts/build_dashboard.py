#!/usr/bin/env python3
"""Health50 analysis skill: build the dashboards of all runs.

Every run is a folder <folder>/analysis/<date> with summary.json (written by summarize.py)
and findings.json (written by the AI assistant). This script fills the page template for
every run, links the runs to each other, and writes analysis/index.html, which opens the
latest run. The pages need no internet connection.

Python standard library only. Usage:

    python3 build_dashboard.py [--folder "/path/to/Health50 files"]
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SETTINGS = os.path.expanduser("~/.health50/settings.json")
KEEP = ("period", "timezone", "dataUntil", "stats", "weekly", "series", "workouts", "workoutGroups", "events", "travel", "notes", "files")


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def main():
    ap = argparse.ArgumentParser(description="Build the Health50 dashboards of all runs.")
    ap.add_argument("--folder", help="folder with the Health50 files (default: the remembered one)")
    args = ap.parse_args()
    folder = args.folder or load(SETTINGS)["folder"]
    analysis = os.path.join(folder, "analysis")
    runs = sorted(d for d in os.listdir(analysis)
                  if os.path.isfile(os.path.join(analysis, d, "summary.json")) and os.path.isfile(os.path.join(analysis, d, "findings.json")))
    if not runs:
        sys.exit("No run with summary.json and findings.json in " + analysis)
    with open(os.path.join(HERE, "..", "assets", "dashboard-template.html"), encoding="utf-8") as f:
        template = f.read()
    guidelines = load(os.path.join(HERE, "..", "guidelines.json"))["guidelines"]
    links = [{"date": r, "href": "../%s/dashboard.html" % r} for r in runs]
    before = None
    for run in runs:
        summary, findings = load(os.path.join(analysis, run, "summary.json")), load(os.path.join(analysis, run, "findings.json"))
        data = {
            "run": {"date": run}, "runs": links, "guidelines": guidelines,
            "summary": {k: summary[k] for k in KEEP if k in summary}, "findings": findings,
            "previous": {"date": before[0], "stats": before[1]["stats"]} if before else None,
            "previousFindings": before[2] if before else None,
        }
        text = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
        page = template.replace("/*DATA*/null", text, 1).replace("<title>Health50 analysis</title>", "<title>Health50 analysis %s</title>" % run, 1)
        out = os.path.join(analysis, run, "dashboard.html")
        with open(out, "w", encoding="utf-8") as f:
            f.write(page)
        print("dashboard written: %s (%s bytes)" % (out, format(len(page.encode("utf-8")), ",")))
        before = (run, summary, findings)
    with open(os.path.join(analysis, "index.html"), "w", encoding="utf-8") as f:
        f.write('<!doctype html>\n<meta charset="utf-8">\n<title>Health50 analysis</title>\n'
                '<meta http-equiv="refresh" content="0; url=%s/dashboard.html">\n'
                '<p><a href="%s/dashboard.html">Open the latest analysis (%s)</a></p>\n' % (runs[-1], runs[-1], runs[-1]))


if __name__ == "__main__":
    main()
