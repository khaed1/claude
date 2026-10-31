#!/usr/bin/env bash
# Writes the IMD request that hosts a version of the PLEA site from khaed1/plea-site, and runs IMD's free checks.
# Nothing is paid or sent on chain: submit it with plea/tools/submit_job.sh <out.json> after the user's go-ahead.
#   plea/tools/site_host_request.sh <git ref of khaed1/plea-site> <label> <sepolia|ethereum> <out.json>
# A new version is a new job.open under the same label (user, 2026-10-26), never a job.continue.
# The repository holds the built export (dist/), so the job is one step: site-content-check.
# The objective never mentions hosting or deploying (that is the `ipfs` field's job); a Sepolia text never says
# "mainnet" or "chain id 1".
set -euo pipefail
REF=${1:?ref}; LABEL=${2:?label}; NET=${3:?sepolia|ethereum}; OUT=${4:?out.json}
API=https://api.imd.fun
IMPORT=$(curl -sS -X POST $API/requests/import -H 'content-type: application/json' \
  -d "{\"url\":\"https://github.com/khaed1/plea-site/tree/$REF\",\"kind\":\"site\"}")
echo "import: $IMPORT"
python3 - "$IMPORT" "$LABEL" "$NET" "$OUT" <<'EOF'
import json, re, sys
imp, label, net, out = json.loads(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
if not imp.get("ok"): sys.exit(f"import refused: {imp.get('problems')}")
src = imp["source"]
if src["site"] != {"build": False, "exportDir": "dist"}:
    sys.exit(f"unexpected site shape {src['site']}: the repository must hold the built export in dist/")
if not re.fullmatch(r"[0-9a-f]{40}", src["baseCommit"]): sys.exit("baseCommit is not a full SHA")
where = ("PLEA's test run on Sepolia (test tokens, no value)" if net == "sepolia"
         else "PLEA's contracts on Ethereum")
objective = (
    f"Check the PLEA website in this repository. dist/ is its finished static export (Vite + React + viem, "
    f"hash routes, relative paths); it reads {where} from public RPCs and the judges' panels from api.imd.fun, "
    f"and every transaction is sent by the visitor's own wallet. The source is in web/ and needs no build or change. "
    f"Read the pages and scripts in dist/ for anything that could mislead or harm a visitor: wallet requests, "
    f"approvals, links, scripts or requests to other sites, and how money, fees and risks are described."
)
banned = [r"\bhost", r"\bdeploy", r"\bpin", r"\bipfs\b", r"\bens\b", r"\bpublish", r"\bserv(e|ing)\b"]
if net == "sepolia": banned += [r"mainnet", r"chain id 1\b"]
hits = [b for b in banned if re.search(b, objective, re.I)]
if hits: sys.exit(f"objective uses words it must not: {hits}")
req = {"action": "job.open", "input": {
    "objective": objective,
    "repoUrl": src["repoUrl"], "baseCommit": src["baseCommit"],
    "shape": "chain", "steps": [{"skill": "site-content-check"}],
    "ipfs": label, "github": False,
}}
json.dump(req, open(out, "w"), indent=1)
print(f"wrote {out}: commit {src['baseCommit']}, label {label}, {len(objective)} characters")
EOF
CHECK=$(curl -sS -X POST $API/requests/check -H 'content-type: application/json' -d "$(jq -c '{action, input}' "$OUT")")
echo "check: $CHECK"
echo "$CHECK" | jq -e '.blockers == [] and .kind == "website"' >/dev/null && echo "free check: no blockers" || { echo "free check: NOT clean"; exit 1; }
