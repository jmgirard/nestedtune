#!/usr/bin/env python3
"""Measure what this repository's GitHub Actions runs actually cost in machine time.

Two mechanisms waste runs, and this script measures both so a change to the
workflows can be judged against a recorded baseline rather than an impression:

  skipped    a default-branch commit that changed no packaged file -- it could
             not have broken the package, so the run it fires could not learn
             anything. Classified by the very `paths-ignore` list the workflows
             carry, read out of the workflow files rather than restated here,
             so the measurement cannot drift away from the thing it measures.

  superseded a run still executing when a later run on the same branch and
             workflow was created. Its answer is about a commit nobody is
             waiting on any more.

The two overlap -- a default-branch tracking commit can be both -- so they are
reported side by side and never summed.

Two things this script is careful about, because getting either wrong makes it
flatter the change it exists to measure:

  The commit list comes from `git log`, never from the runs those commits
  fired. A run-derived list goes blind exactly when the path filter starts
  working: a skipped commit fires no run, so it would silently leave the
  denominator and the filter's effect would read as zero.

  Cancelling a superseded run reclaims only the tail still to come when its
  successor was created, not the run's whole duration. Both are reported --
  `superseded` is what those runs cost, `reclaimed` is what cancelling them
  saves -- and only the second is a saving.

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

# What a path glob may contain. Anything else means the line was not understood,
# and the script refuses rather than guessing -- a mis-parsed glob matches
# nothing, which silently reclassifies every skipped commit as "run".
GLOB_CHARS = re.compile(r"^[A-Za-z0-9_.*/-]+$")


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


def repo_facts() -> dict:
    return gh_api("repos/{owner}/{repo}")


def parse_ignore_blocks(text: str, name: str) -> list[list[str]]:
    """Every `paths-ignore:` block in one workflow file, each kept separate.

    Kept separate on purpose: a file carries one block per trigger, and merging
    them here would hide the drift between triggers that duplicating the list
    invites. Parsed by hand rather than with a YAML library so the script keeps
    its no-dependency promise -- which means it must refuse anything it does not
    fully understand instead of quietly returning a wrong list.
    """
    blocks: list[list[str]] = []
    lines = text.splitlines()
    for index, line in enumerate(lines):
        header = re.match(r"^(\s*)paths-ignore:(.*)$", line)
        if not header:
            continue
        indent, trailing = header.group(1), header.group(2).strip()
        if trailing and not trailing.startswith("#"):
            sys.exit(
                f"{name}:{index + 1}: `paths-ignore` is written inline "
                f"({trailing!r}). This parser reads block sequences only, and "
                "reading the wrong list is worse than refusing to read one."
            )

        items: list[str] = []
        for follow in lines[index + 1:]:
            if not follow.strip() or follow.strip().startswith("#"):
                continue
            if len(follow) - len(follow.lstrip()) <= len(indent):
                break
            entry = follow.strip()
            if not entry.startswith("-"):
                break
            items.append(parse_glob(entry, name, index))

        if not items:
            sys.exit(f"{name}:{index + 1}: `paths-ignore` declares no entries")
        blocks.append(items)
    return blocks


def parse_glob(entry: str, name: str, line_no: int) -> str:
    """One `- 'glob'` list entry, with quotes and any trailing comment removed."""
    value = entry[1:].strip()
    if value[:1] in ("'", '"'):
        quote = value[0]
        end = value.find(quote, 1)
        if end == -1:
            sys.exit(f"{name}:{line_no + 1}: unterminated quote in {entry!r}")
        rest = value[end + 1:].strip()
        if rest and not rest.startswith("#"):
            sys.exit(f"{name}:{line_no + 1}: unexpected text after glob in {entry!r}")
        value = value[1:end]
    elif "#" in value:
        value = value.split("#", 1)[0].strip()

    # Checked before the character class, which would otherwise reject `!` with
    # the generic message and hide why a legal GitHub pattern is refused.
    if value.startswith("!"):
        sys.exit(f"{name}:{line_no + 1}: negated pattern {value!r} is not supported")
    if not GLOB_CHARS.match(value):
        sys.exit(f"{name}:{line_no + 1}: refusing to guess at glob {value!r}")
    return value


def read_paths_ignore() -> tuple[list[str], str]:
    """The `paths-ignore` globs the workflows declare, one list or an error.

    Every block in every workflow must declare the same list. Blocks are
    compared individually, so drift between two triggers of the SAME file is
    caught -- which is the drift the duplicated list actually invites, GitHub
    Actions having no YAML-anchor support to share one copy.
    """
    per_block: dict[str, tuple[str, ...]] = {}
    files = sorted(WORKFLOW_DIR.glob("*.yaml")) + sorted(WORKFLOW_DIR.glob("*.yml"))
    for path in files:
        for n, block in enumerate(parse_ignore_blocks(path.read_text(), path.name), 1):
            per_block[f"{path.name}#{n}"] = tuple(block)

    if not per_block:
        return sorted(FALLBACK_IGNORE), "fallback (no workflow declares paths-ignore)"

    if len(set(per_block.values())) > 1:
        detail = "\n".join(f"  {k}: {list(v)}" for k, v in sorted(per_block.items()))
        sys.exit(f"workflow `paths-ignore` blocks disagree:\n{detail}")

    sources = sorted({k.split("#")[0] for k in per_block})
    return list(next(iter(per_block.values()))), ", ".join(sources)


def matches_ignore(filename: str, globs: list[str]) -> bool:
    """True when a changed file is covered by the ignore list.

    `fnmatch` is close to GitHub's filter syntax but not identical: its `*`
    crosses `/` where GitHub's does not. Only `**`, `?` and literal segments are
    used by the globs this repo declares, and `parse_glob` refuses the negation
    patterns that would diverge further; a bare `*` segment would need this
    function rewritten before it could be trusted.
    """
    for glob in globs:
        if fnmatch.fnmatch(filename, glob):
            return True
        # `dir/**` must also cover `dir/file`; fnmatch reads the two stars as
        # requiring at least something after the slash.
        if glob.endswith("/**") and fnmatch.fnmatch(filename, glob[:-3] + "/*"):
            return True
    return False


def commit_files(sha: str) -> list[str]:
    """Files a commit changed, through a merge or a root commit alike.

    Two commits print nothing under the obvious invocation, and both would then
    look like a commit changing no packaged file -- indistinguishable from a
    tracking-only one, and wrong in the reassuring direction. A merge needs
    `--first-parent`; a root commit, having no parent to diff against, needs
    `--root`. This repo's own first commit is a root commit, so the second case
    is not hypothetical.
    """
    out = git("diff-tree", "--no-commit-id", "--name-only", "-r", "-m",
              "--first-parent", "--root", sha)
    files = [f for f in out.split("\n") if f]
    if not files:
        sys.exit(
            f"{sha[:9]}: git reports no changed files. Rather than classify a "
            "commit on no evidence, this refuses -- an empty file list has "
            "always meant the query was wrong, never that the commit was empty."
        )
    return files


def default_branch_commits(branch: str, since: str, until: str) -> list[str]:
    """Every commit on the default branch in the window, from git.

    Deliberately not derived from workflow runs: once `paths-ignore` is live a
    skipped commit fires no run, so a run-derived list would drop exactly the
    commits the filter is working on and report its effect as zero. Note the
    two clocks differ -- git filters on committer date, the run query on run
    creation -- which is immaterial for pushes but worth knowing.
    """
    out = git("log", branch, f"--since={since}", f"--until={until}", "--format=%H")
    return [line for line in out.split() if line]


def fetch_runs(since: dt.datetime, until: dt.datetime) -> list[dict]:
    """Completed runs created inside the window.

    Pages newest-first and stops once a page is entirely older than the window,
    so an old narrow window is not silently truncated by a page cap.
    """
    runs: list[dict] = []
    page = 1
    while True:
        batch = gh_api(
            f"repos/{{owner}}/{{repo}}/actions/runs?per_page=100&page={page}"
        )["workflow_runs"]
        runs += batch
        if len(batch) < 100 or all(parse_ts(r["created_at"]) < since for r in batch):
            break
        page += 1
        if page > 100:
            sys.exit("run history exceeded 100 pages; narrow the window")
    return [
        r
        for r in runs
        if r["status"] == "completed" and since <= parse_ts(r["created_at"]) < until
    ]


def fetch_jobs(runs: list[dict]) -> dict[int, list[dict]]:
    """Every job of every run, all attempts, paginated.

    `filter=all` matters: without it a re-run hides the original attempt's jobs,
    and their minutes vanish from the totals with nothing to show they existed.
    """
    def one(run_id: int) -> tuple[int, list[dict]]:
        jobs: list[dict] = []
        page = 1
        while True:
            batch = gh_api(
                f"repos/{{owner}}/{{repo}}/actions/runs/{run_id}/jobs"
                f"?per_page=100&filter=all&page={page}"
            ).get("jobs", [])
            jobs += batch
            if len(batch) < 100:
                return run_id, jobs
            page += 1

    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        return dict(pool.map(one, [r["id"] for r in runs]))


def run_minutes(run: dict, jobs: dict[int, list[dict]], after: dt.datetime | None = None) -> float:
    """Raw machine-minutes for a run, optionally only the part after a moment.

    Deliberately not GitHub's billing convention (each job rounded up to a whole
    minute, then multiplied by a per-platform rate). This repository is public,
    so those rates buy nothing; what is left is the machine time itself.

    With `after`, this returns the tail a cancellation would have reclaimed --
    what was still running when the superseding run was created.
    """
    total = 0.0
    for job in jobs.get(run["id"], []):
        started = parse_ts(job.get("started_at"))
        ended = parse_ts(job.get("completed_at"))
        if not (started and ended):
            continue
        if after is not None:
            started = max(started, after)
        total += max(0.0, (ended - started).total_seconds() / 60)
    return total


def superseded(runs: list[dict]) -> dict[int, dt.datetime]:
    """Run id -> when it was superseded, for runs a later run overtook.

    Only sees runs inside the window: one overtaken by a run created after
    `until`, or by one still in flight at capture, is not flagged, so both
    superseded figures are floors at the upper window edge.
    """
    by_key: dict[tuple[str, str], list[dict]] = {}
    for run in runs:
        by_key.setdefault((run["head_branch"], run["name"]), []).append(run)

    out: dict[int, dt.datetime] = {}
    for group in by_key.values():
        group.sort(key=lambda r: parse_ts(r["created_at"]))
        for index, run in enumerate(group):
            ended = parse_ts(run["updated_at"])
            overtaking = [
                parse_ts(later["created_at"])
                for later in group[index + 1:]
                if parse_ts(later["created_at"]) < ended
            ]
            if overtaking:
                out[run["id"]] = min(overtaking)
    return out


def measure(since_s: str, until_s: str) -> dict:
    since, until = parse_ts(since_s), parse_ts(until_s)
    globs, globs_source = read_paths_ignore()
    facts = repo_facts()
    branch = facts["default_branch"]

    runs = fetch_runs(since, until)
    jobs = fetch_jobs(runs)

    # Classify from git, so a commit the filter skips still appears even though
    # it fires no run; then attribute whatever runs each commit did fire.
    runs_by_sha: dict[str, list[dict]] = {}
    for run in runs:
        if run["event"] == "push" and run["head_branch"] == branch:
            runs_by_sha.setdefault(run["head_sha"], []).append(run)

    commits = []
    for sha in default_branch_commits(branch, since_s, until_s):
        files = commit_files(sha)
        packaged = sorted(f for f in files if not matches_ignore(f, globs))
        commits.append({
            "sha": sha[:9],
            "subject": git("log", "-1", "--format=%s", sha).strip(),
            "skipped": not packaged,
            "files": len(files),
            "packaged": packaged[:3],
            "runs": len(runs_by_sha.get(sha, [])),
        })

    skipped_shas = {
        sha for sha, c in zip(default_branch_commits(branch, since_s, until_s), commits)
        if c["skipped"]
    }
    skipped_runs = [r for sha in skipped_shas for r in runs_by_sha.get(sha, [])]
    sup = superseded(runs)
    sup_runs = [r for r in runs if r["id"] in sup]
    sup_off = [r for r in sup_runs if r["head_branch"] != branch]

    def block(rs: list[dict]) -> dict:
        return {"runs": len(rs), "minutes": round(sum(run_minutes(r, jobs) for r in rs))}

    def reclaimed(rs: list[dict]) -> int:
        return round(sum(run_minutes(r, jobs, after=sup[r["id"]]) for r in rs))

    # The union is over the same run objects the two rows are built from, so a
    # run counted here is always a run one of them counted.
    removed_ids = {r["id"] for r in skipped_runs} | {r["id"] for r in sup_off}
    removed_runs = [r for r in runs if r["id"] in removed_ids]

    return {
        "repo": facts["full_name"],
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
        "superseded": {**block(sup_runs), "reclaimed": reclaimed(sup_runs),
                       "off_default_branch": {**block(sup_off),
                                              "reclaimed": reclaimed(sup_off)}},
        "removed": {"runs": len(removed_runs),
                    "minutes": block(skipped_runs)["minutes"] + reclaimed(sup_off)},
        "commits": sorted(commits, key=lambda c: (c["skipped"], c["sha"])),
    }


def render(m: dict) -> str:
    sup, off = m["superseded"], m["superseded"]["off_default_branch"]
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
        "| category | runs | machine-min | reclaimable |",
        "|---|---|---|---|",
        f"| total | {m['total']['runs']} | {m['total']['minutes']} | — |",
        f"| on skipped commits | {m['skipped']['runs']} | {m['skipped']['minutes']} "
        f"| {m['skipped']['minutes']} |",
        f"| superseded (all) | {sup['runs']} | {sup['minutes']} | {sup['reclaimed']} |",
        f"| superseded off `{m['default_branch']}` | {off['runs']} | {off['minutes']} "
        f"| {off['reclaimed']} |",
        f"| **removed by the filter + off-branch cancel** | **{m['removed']['runs']}** "
        f"| — | **{m['removed']['minutes']}** |",
        "",
        f"Jobs in window: {m['total']['jobs']}.",
        "",
        "`machine-min` is what those runs cost; `reclaimable` is what removing "
        "them saves, and only the second is a saving. A skipped commit fires no "
        "run at all, so the two are equal for it. Cancelling a superseded run "
        "reclaims only the tail still to come when its successor was created — "
        "which is why the superseded rows differ. The two waste categories "
        "overlap (a tracking commit on the default branch can be both) and are "
        "never summed; the last row is their union, counted once.",
        "",
        f"## Default-branch commits ({m['skipped']['commits_skipped']} of "
        f"{m['skipped']['commits_total']} skipped)",
        "",
        "Enumerated from `git log`, not from the runs they fired — a commit the "
        "filter skips fires no run, and a run-derived list would lose it.",
        "",
        "| commit | verdict | files | runs | first packaged paths |",
        "|---|---|---|---|---|",
    ]
    for c in m["commits"]:
        verdict = "skipped" if c["skipped"] else "run"
        paths = ", ".join(f"`{p}`" for p in c["packaged"]) or "—"
        lines.append(
            f"| `{c['sha']}` {c['subject'][:40]} | {verdict} | {c['files']} "
            f"| {c['runs']} | {paths} |"
        )
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
