#!/usr/bin/env python3
"""Measure what this repository's GitHub Actions runs actually cost in machine time.

Two mechanisms waste runs, and this script measures both so a change to the
workflows can be judged against a recorded baseline rather than an impression:

  skipped    a run fired by a default-branch commit that changed no packaged
             file -- the commit could not have broken the package, so the run
             could not have learned anything. Classified by the very
             `paths-ignore` list the workflows carry, read out of the workflow
             file rather than restated here, so the measurement cannot drift
             away from the thing it measures.

  superseded a run still executing when a later run on the same branch and
             workflow was created. Its answer is about a commit nobody is
             waiting on any more.

The two overlap -- a default-branch tracking commit can be both -- so they are
reported side by side and never summed.

Auth comes from `gh`, which the script shells out to; there is no token
handling and no third-party dependency.

Usage:
    .github/ci-usage.py                     # the recorded baseline window
    .github/ci-usage.py --since 2026-08-01T00:00:00Z --until 2026-09-01T00:00:00Z
    .github/ci-usage.py --format json

Note that GitHub retains workflow runs for 90 days by default, so a window
older than that returns nothing however correct the query is.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import fnmatch
import json
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
WORKFLOW_DIR = REPO_ROOT / ".github" / "workflows"

# The window the milestone baseline was measured over. Bounded below the first
# run and above a run that was still in flight at capture time -- an in-flight
# run contributes its jobs but only part of its minutes, so including one makes
# the totals irreproducible the moment it finishes.
BASELINE_SINCE = "2026-07-26T00:00:00Z"
BASELINE_UNTIL = "2026-07-27T07:00:00Z"

# A commit touching only these is a commit the package cannot notice. Used only
# when no workflow declares a `paths-ignore` list; the workflows are the
# authority whenever they have one.
FALLBACK_IGNORE = ["cairn/**", "CLAUDE.md", ".claude/**"]


def parse_ts(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))


def gh_api(path: str) -> dict:
    result = subprocess.run(
        ["gh", "api", path], capture_output=True, text=True, check=False
    )
    if result.returncode != 0:
        sys.exit(f"gh api {path} failed: {result.stderr.strip()}")
    return json.loads(result.stdout)


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args], capture_output=True, text=True, cwd=REPO_ROOT, check=False
    )
    if result.returncode != 0:
        sys.exit(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout


def current_repo() -> str:
    return gh_api("repos/{owner}/{repo}")["full_name"]


def default_branch() -> str:
    return gh_api("repos/{owner}/{repo}")["default_branch"]


def read_paths_ignore() -> tuple[list[str], str]:
    """Read the `paths-ignore` globs the workflows declare.

    Parsed with a regex rather than a YAML library so the script keeps its
    no-dependency promise. Every workflow that declares a list must declare the
    same one -- two workflows disagreeing about what is ignorable is a bug this
    surfaces rather than averages over.
    """
    found: dict[str, list[str]] = {}
    for path in sorted(WORKFLOW_DIR.glob("*.yaml")) + sorted(
        WORKFLOW_DIR.glob("*.yml")
    ):
        globs: list[str] = []
        for block in re.findall(
            r"^\s*paths-ignore:\s*\n((?:\s*-\s*.+\n)+)", path.read_text(), re.MULTILINE
        ):
            globs += [
                line.strip().lstrip("-").strip().strip("'\"")
                for line in block.splitlines()
                if line.strip()
            ]
        if globs:
            found[path.name] = sorted(set(globs))

    if not found:
        return sorted(FALLBACK_IGNORE), "fallback (no workflow declares paths-ignore)"
    distinct = {tuple(v) for v in found.values()}
    if len(distinct) > 1:
        sys.exit(f"workflows declare conflicting paths-ignore lists: {found}")
    return list(next(iter(distinct))), ", ".join(sorted(found))


def matches_ignore(filename: str, globs: list[str]) -> bool:
    """True when a changed file is covered by the ignore list.

    GitHub's `**` crosses directory separators, which `fnmatch` already does,
    but a bare `dir/**` must also cover `dir/file` -- fnmatch reads the two
    stars as requiring something after the slash. Both forms are tested.
    """
    for glob in globs:
        if fnmatch.fnmatch(filename, glob):
            return True
        if glob.endswith("/**") and fnmatch.fnmatch(filename, glob[:-3] + "/*"):
            return True
    return False


def commit_is_skipped(sha: str, globs: list[str]) -> tuple[bool, list[str]]:
    files = [f for f in git("show", "--name-only", "--format=", sha).split("\n") if f]
    if not files:
        return False, []
    return all(matches_ignore(f, globs) for f in files), files


def fetch_runs(since: dt.datetime, until: dt.datetime) -> list[dict]:
    runs: list[dict] = []
    for page in range(1, 21):
        batch = gh_api(
            f"repos/{{owner}}/{{repo}}/actions/runs?per_page=100&page={page}"
        )["workflow_runs"]
        runs += batch
        if len(batch) < 100:
            break
    return [
        r
        for r in runs
        if r["status"] == "completed" and since <= parse_ts(r["created_at"]) < until
    ]


def fetch_jobs(runs: list[dict]) -> dict[int, list[dict]]:
    def one(run_id: int) -> tuple[int, list[dict]]:
        return run_id, gh_api(
            f"repos/{{owner}}/{{repo}}/actions/runs/{run_id}/jobs?per_page=100"
        ).get("jobs", [])

    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        return dict(pool.map(one, [r["id"] for r in runs]))


def run_minutes(run: dict, jobs: dict[int, list[dict]]) -> float:
    """Raw machine-minutes: per-job wall clock, summed.

    Deliberately not GitHub's billing convention (each job rounded up to a whole
    minute, then multiplied by a per-platform rate). This repository is public,
    so those rates buy nothing; what is left is the machine time itself.
    """
    total = 0.0
    for job in jobs.get(run["id"], []):
        started, ended = parse_ts(job.get("started_at")), parse_ts(job.get("completed_at"))
        if started and ended:
            total += (ended - started).total_seconds() / 60
    return total


def superseded(runs: list[dict]) -> set[int]:
    """Runs still executing when a later run on the same branch+workflow began."""
    by_key: dict[tuple[str, str], list[dict]] = {}
    for run in runs:
        by_key.setdefault((run["head_branch"], run["name"]), []).append(run)

    out: set[int] = set()
    for group in by_key.values():
        group.sort(key=lambda r: parse_ts(r["created_at"]))
        for index, run in enumerate(group):
            ended = parse_ts(run["updated_at"])
            if any(parse_ts(later["created_at"]) < ended for later in group[index + 1:]):
                out.add(run["id"])
    return out


def measure(since_s: str, until_s: str) -> dict:
    since, until = parse_ts(since_s), parse_ts(until_s)
    globs, globs_source = read_paths_ignore()
    branch = default_branch()

    runs = fetch_runs(since, until)
    jobs = fetch_jobs(runs)

    # Classify each distinct default-branch commit once, then attribute every
    # run that commit fired to its verdict.
    commits: dict[str, dict] = {}
    for run in runs:
        if run["event"] == "push" and run["head_branch"] == branch:
            sha = run["head_sha"]
            if sha not in commits:
                skipped, files = commit_is_skipped(sha, globs)
                commits[sha] = {
                    "sha": sha[:9],
                    "subject": git("log", "-1", "--format=%s", sha).strip(),
                    "skipped": skipped,
                    "files": len(files),
                    "packaged": sorted(f for f in files if not matches_ignore(f, globs))[:3],
                }

    skipped_shas = {s for s, c in commits.items() if c["skipped"]}
    skipped_runs = [r for r in runs if r["head_sha"] in skipped_shas and r["event"] == "push"
                    and r["head_branch"] == branch]
    sup_ids = superseded(runs)
    sup_runs = [r for r in runs if r["id"] in sup_ids]
    sup_off = [r for r in sup_runs if r["head_branch"] != branch]

    def block(rs: list[dict]) -> dict:
        return {"runs": len(rs), "minutes": round(sum(run_minutes(r, jobs) for r in rs))}

    return {
        "repo": current_repo(),
        "window": {"since": since_s, "until": until_s, "status": "completed"},
        "default_branch": branch,
        "paths_ignore": {"globs": globs, "source": globs_source},
        "total": {
            "runs": len(runs),
            "jobs": sum(len(jobs.get(r["id"], [])) for r in runs),
            "minutes": round(sum(run_minutes(r, jobs) for r in runs)),
        },
        "skipped": {**block(skipped_runs),
                    "commits_skipped": len(skipped_shas),
                    "commits_total": len(commits)},
        "superseded": {**block(sup_runs), "off_default_branch": block(sup_off)},
        "removed": block([r for r in runs
                          if r["head_sha"] in skipped_shas or r["id"] in {x["id"] for x in sup_off}]),
        "commits": sorted(commits.values(), key=lambda c: (c["skipped"], c["sha"])),
    }


def render(m: dict) -> str:
    lines = [
        f"# CI usage — {m['repo']}",
        "",
        f"Window `[{m['window']['since']}, {m['window']['until']})`, "
        f"runs with status `{m['window']['status']}`. "
        f"Default branch `{m['default_branch']}`.",
        "",
        f"Path filter read from {m['paths_ignore']['source']}: "
        + ", ".join(f"`{g}`" for g in m["paths_ignore"]["globs"]),
        "",
        "| category | runs | machine-min |",
        "|---|---|---|",
        f"| total | {m['total']['runs']} | {m['total']['minutes']} |",
        f"| on skipped commits | {m['skipped']['runs']} | {m['skipped']['minutes']} |",
        f"| superseded (all) | {m['superseded']['runs']} | {m['superseded']['minutes']} |",
        f"| superseded off `{m['default_branch']}` | {m['superseded']['off_default_branch']['runs']} "
        f"| {m['superseded']['off_default_branch']['minutes']} |",
        f"| **removed by the filter + off-branch cancel** | **{m['removed']['runs']}** "
        f"| **{m['removed']['minutes']}** |",
        "",
        f"Jobs in window: {m['total']['jobs']}. The two waste categories overlap "
        "(a tracking commit on the default branch can be both) and are never summed; "
        "the last row is their union, counted once.",
        "",
        f"## Default-branch commits ({m['skipped']['commits_skipped']} of "
        f"{m['skipped']['commits_total']} skipped)",
        "",
        "| commit | verdict | files | first packaged paths |",
        "|---|---|---|---|",
    ]
    for c in m["commits"]:
        verdict = "skipped" if c["skipped"] else "run"
        paths = ", ".join(f"`{p}`" for p in c["packaged"]) or "—"
        lines.append(f"| `{c['sha']}` {c['subject'][:44]} | {verdict} | {c['files']} | {paths} |")
    return "\n".join(lines) + "\n"


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--since", default=BASELINE_SINCE)
    ap.add_argument("--until", default=BASELINE_UNTIL)
    ap.add_argument("--format", choices=("text", "json"), default="text")
    args = ap.parse_args()

    measured = measure(args.since, args.until)
    if args.format == "json":
        print(json.dumps(measured, indent=2))
    else:
        print(render(measured), end="")


if __name__ == "__main__":
    main()
