#!/usr/bin/env python3
"""Builds the swarm audit jobs for one round (see README.md).

  python3 make_jobs.py round <n> [--commit <sha>]     # 4 auditor jobs + scope manifest
  python3 make_jobs.py judge <n> <url-A1> <url-A2> <url-A3> <url-A4>   # judge job

Writes rounds/<n>/: manifest.json (every in-scope file with its sha256 and lines at the commit),
<ID>.objective.md (the text the job gets) and <ID>.request.json (body for POST /requests/quote).
Standard library only. Run from anywhere inside the repo.
"""
import hashlib
import json
import subprocess
import sys
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
LAUNCHPAD = HERE.parent
JOBS = HERE / "jobs"
REPO_URL = "https://github.com/khaed1/claude"
RAW_URL = "https://raw.githubusercontent.com/khaed1/claude"
AUDITORS = ["A1-core", "A2-market", "A3-staking", "A4-governance"]
# Observed on api.imd.fun (Oct 2026): an 8,000-character objective is accepted, 20,000 is "request_too_large".
MAX_OBJECTIVE_BYTES = 7500
# The job planner needs between 1 and 16 allowed paths.
MAX_PATHS = 16


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


def parse_auditor(name):
    """Auditor template: 'ID:', 'TITLE:', 'FILES:' (one per line) and 'FOCUS:' (rest of the file)."""
    text = (JOBS / f"{name}.md").read_text()
    head, focus = text.split("FOCUS:\n", 1)
    lines = head.splitlines()
    ident = lines[0].split(":", 1)[1].strip()
    title = lines[1].split(":", 1)[1].strip()
    files = [l.strip() for l in lines[lines.index("FILES:") + 1:] if l.strip()]
    return ident, title, files, focus.strip()


def fill(template, values):
    for k, v in values.items():
        template = template.replace("{{" + k + "}}", v)
    if "{{" in template:
        sys.exit(f"unfilled placeholder in template: {template[template.index('{{'):][:40]}")
    return template


def write_job(out_dir, ident, objective):
    size = len(objective.encode())
    if size > MAX_OBJECTIVE_BYTES:
        sys.exit(f"{ident}: objective is {size} bytes, limit {MAX_OBJECTIVE_BYTES}; shorten its template")
    (out_dir / f"{ident}.objective.md").write_text(objective)
    body = {"action": "job.open", "input": {"objective": objective}, "requestKey": str(uuid.uuid4())}
    (out_dir / f"{ident}.request.json").write_text(json.dumps(body, indent=2) + "\n")
    print(f"  {ident}: {size} bytes")


def check_commit(commit):
    full = git("rev-parse", "--verify", f"{commit}^{{commit}}").strip()
    if not git("branch", "-r", "--contains", full).strip():
        sys.exit(f"{full[:7]} is not on any remote branch: push it first (auditors read it from GitHub)")
    for f in ("audit/THREAT-MODEL.md", "audit/FINDINGS.md"):
        if subprocess.run(["git", "-C", str(LAUNCHPAD), "cat-file", "-e", f"{full}:launchpad/{f}"]).returncode:
            sys.exit(f"{full[:7]} has no launchpad/{f}: the jobs tell auditors to read it at that commit")
    return full


def cmd_round(n, commit):
    commit = check_commit(commit)
    out_dir = HERE / "rounds" / str(n)
    out_dir.mkdir(parents=True, exist_ok=True)
    scope = manifest(commit)
    scope_paths = {f["path"] for f in scope}
    covered = set()
    common = (JOBS / "_common.md").read_text()
    print(f"round {n} at {commit[:7]}: {len(scope)} files, {sum(f['lines'] for f in scope)} lines in scope")
    for name in AUDITORS:
        ident, title, files, focus = parse_auditor(name)
        if not 1 <= len(files) + 1 <= MAX_PATHS:
            sys.exit(f"{ident}: {len(files)} files; the planner takes at most {MAX_PATHS} paths")
        for f in files:
            git("cat-file", "-e", f"{commit}:launchpad/{f}")  # fails if the path is wrong
        covered |= set(files)
        objective = fill(common, {
            "ROUND": str(n), "ID": ident, "COMMIT": commit, "COMMIT_SHORT": commit[:7],
            "RAW": f"{RAW_URL}/{commit}/launchpad", "OUT": f"{ident}-round{n}.md",
            "FILES": "\n".join(f"- {f}" for f in files),
            "FOCUS": f"AREA: {title}\n{focus}",
        })
        write_job(out_dir, ident, objective)
    missing = sorted(scope_paths - covered)
    if missing:
        sys.exit(f"in scope but in no auditor's FILES: {', '.join(missing)}")
    (out_dir / "manifest.json").write_text(json.dumps(
        {"round": n, "commit": commit, "repo": REPO_URL, "files": scope}, indent=2) + "\n")
    print(f"wrote {out_dir.relative_to(LAUNCHPAD)}/")


def cmd_judge(n, reports):
    out_dir = HERE / "rounds" / str(n)
    meta = json.loads((out_dir / "manifest.json").read_text())
    commit = meta["commit"]
    if len(reports) != len(AUDITORS):
        sys.exit(f"give {len(AUDITORS)} report links (A1..A4), got {len(reports)}")
    objective = fill((JOBS / "judge.md").read_text(), {
        "ROUND": str(n), "COMMIT": commit, "COMMIT_SHORT": commit[:7],
        "RAW": f"{RAW_URL}/{commit}/launchpad", "OUT": f"judge-round{n}.md",
        "REPORTS": "\n".join(f"- A{i + 1}: {u}" for i, u in enumerate(reports)),
    })
    write_job(out_dir, "judge", objective)


def main(argv):
    if len(argv) >= 2 and argv[0] == "round":
        commit = argv[argv.index("--commit") + 1] if "--commit" in argv else "HEAD"
        cmd_round(int(argv[1]), commit)
    elif len(argv) >= 2 and argv[0] == "judge":
        cmd_judge(int(argv[1]), argv[2:])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
