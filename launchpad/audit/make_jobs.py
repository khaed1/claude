#!/usr/bin/env python3
"""Builds one round of the swarm audit (see README.md): four IMD audit jobs, one per area.

  python3 make_jobs.py round <n> [--commit <sha>] [--check]

Each job uses IMD's native audit template (four specialists + a judge, 0.5 IMD). Writes rounds/<n>/:
  manifest.json          every in-scope file with its sha256 and lines at the commit
  <ID>.objective.txt     the text to paste into the explorer's Audit form (or the API objective)
  <ID>.request.json      {action, input} for POST https://api.imd.fun/requests/quote (add a requestKey)
--check runs IMD's free POST /requests/check on each job (no token, no payment) and prints any blockers.
Standard library only.
"""
import hashlib
import json
import subprocess
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
LAUNCHPAD = HERE.parent
JOBS = HERE / "jobs"
REPO = "https://github.com/khaed1/claude"
API = "https://api.imd.fun"
AUDITORS = ["A1-core", "A2-market", "A3-staking", "A4-governance"]
MAX_OBJECTIVE_CHARS = 8000  # IMD job body limit (docs, Oct 2026)


def git(*args):
    return subprocess.run(["git", "-C", str(LAUNCHPAD), *args], check=True, capture_output=True, text=True).stdout


def in_scope(commit):
    """Every file the audit covers: all contracts, the deploy script and the fork generators."""
    files = git("ls-tree", "-r", "--name-only", commit, "--", "contracts/src", "contracts/upstream", "contracts/script").split()
    return sorted(f for f in files if f.endswith((".sol", ".py")))


def manifest(commit):
    out = []
    for path in in_scope(commit):
        data = subprocess.run(["git", "-C", str(LAUNCHPAD), "show", f"{commit}:launchpad/{path}"],
                              check=True, capture_output=True).stdout
        out.append({"path": path, "sha256": hashlib.sha256(data).hexdigest(), "lines": data.count(b"\n")})
    return out


def parse_area(name):
    """Area template: 'ID:', 'TITLE:', 'FILES:' (one per line, relative to launchpad/) and 'FOCUS:' (the rest)."""
    head, focus = (JOBS / f"{name}.md").read_text().split("FOCUS:\n", 1)
    lines = head.splitlines()
    ident = lines[0].split(":", 1)[1].strip()
    title = lines[1].split(":", 1)[1].strip()
    files = [l.strip() for l in lines[lines.index("FILES:") + 1:] if l.strip()]
    return ident, title, files, focus.strip()


def fill(template, values):
    for k, v in values.items():
        template = template.replace("{{" + k + "}}", v)
    if "{{" in template:
        sys.exit(f"unfilled placeholder: {template[template.index('{{'):][:40]}")
    return template


def check_commit(commit):
    full = git("rev-parse", "--verify", f"{commit}^{{commit}}").strip()
    if not git("branch", "-r", "--contains", full).strip():
        sys.exit(f"{full[:7]} is not on any remote branch: push it first (the swarm reads it from GitHub)")
    for f in ("audit/THREAT-MODEL.md", "audit/FINDINGS.md"):
        if subprocess.run(["git", "-C", str(LAUNCHPAD), "cat-file", "-e", f"{full}:launchpad/{f}"]).returncode:
            sys.exit(f"{full[:7]} has no launchpad/{f}: the jobs tell the auditors to read it")
    return full


def imd_check(body):
    req = urllib.request.Request(f"{API}/requests/check", data=json.dumps(body).encode(),
                                 headers={"content-type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=120) as r:
        res = json.load(r)
    steps = [p.get("skill") for p in res.get("plan", [])]
    return res.get("blockers", []), steps


def cmd_round(n, commit, check):
    commit = check_commit(commit)
    out_dir = HERE / "rounds" / str(n)
    out_dir.mkdir(parents=True, exist_ok=True)
    scope = manifest(commit)
    covered = set()
    common = (JOBS / "_common.md").read_text()
    print(f"round {n} at {commit[:7]}: {len(scope)} files, {sum(f['lines'] for f in scope)} lines in scope")
    print(f"repository address for the Audit form: {REPO}/tree/{commit}")
    for name in AUDITORS:
        ident, title, files, focus = parse_area(name)
        for f in files:
            git("cat-file", "-e", f"{commit}:launchpad/{f}")  # fails if the path is wrong
        covered |= set(files)
        objective = fill(common, {
            "ROUND": str(n), "ID": ident, "TITLE": title,
            "FILES": "\n".join(f"- launchpad/{f}" for f in files), "FOCUS": focus,
        })
        if len(objective) > MAX_OBJECTIVE_CHARS:
            sys.exit(f"{ident}: objective is {len(objective)} characters, limit {MAX_OBJECTIVE_CHARS}")
        body = {"action": "job.open", "input": {
            "objective": objective, "template": "audit", "repoUrl": f"{REPO}.git", "baseCommit": commit}}
        (out_dir / f"{ident}.objective.txt").write_text(objective)
        (out_dir / f"{ident}.request.json").write_text(json.dumps(body, indent=2) + "\n")
        line = f"  {ident}: {len(objective)} characters"
        if check:
            blockers, steps = imd_check(body)
            line += f"; check: {len(steps)} steps ({', '.join(sorted(set(steps)))}), blockers: {blockers or 'none'}"
            if blockers:
                print(line)
                sys.exit(f"{ident}: IMD check reported blockers")
        print(line)
    missing = sorted({f["path"] for f in scope} - covered)
    if missing:
        sys.exit(f"in scope but in no area's FILES: {', '.join(missing)}")
    (out_dir / "manifest.json").write_text(json.dumps(
        {"round": n, "commit": commit, "repo": REPO, "files": scope}, indent=2) + "\n")
    print(f"wrote {out_dir.relative_to(LAUNCHPAD)}/")


def main(argv):
    if len(argv) >= 2 and argv[0] == "round":
        commit = argv[argv.index("--commit") + 1] if "--commit" in argv else "HEAD"
        cmd_round(int(argv[1]), commit, "--check" in argv)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
