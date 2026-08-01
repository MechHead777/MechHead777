#!/usr/bin/env bash
#
# Rebuilds the LIVE block in README.md from the public ubernutty-cluster repo.
#
#   ./scripts/update-live.sh [README.md]
#
# Reads the GitHub API only, never the cluster. Needs GH_TOKEN and jq.
#
set -euo pipefail

REPO="MechHead777/ubernutty-cluster"
README="${1:-README.md}"
START="<!-- LIVE:START -->"
END="<!-- LIVE:END -->"

# Decode to a file, not a pipe: grep -m1 exits early and SIGPIPEs the decoder.
manifest=$(mktemp)
trap 'rm -f "$manifest"' EXIT

flux_version="unknown"
if gh api "repos/$REPO/contents/clusters/staging/flux-system/gotk-components.yaml" \
     --jq '.content' 2>/dev/null | base64 -d >"$manifest" 2>/dev/null; then
  found=$(grep -oE '# Flux Version: v[0-9]+\.[0-9]+\.[0-9]+' "$manifest" | head -n1 | awk '{print $4}')
  if [[ -z "$found" ]]; then
    found=$(grep -oE 'app\.kubernetes\.io/version: v[0-9]+\.[0-9]+\.[0-9]+' "$manifest" | head -n1 | awk '{print $2}')
  fi
  flux_version="${found:-unknown}"
fi

last_commit_date=$(gh api "repos/$REPO/commits?per_page=1" --jq '.[0].commit.committer.date') || last_commit_date=""
if [[ -n "$last_commit_date" ]]; then
  last_commit=$(date -u -d "$last_commit_date" '+%Y-%m-%d')
  days_ago=$(( ( $(date -u +%s) - $(date -u -d "$last_commit_date" +%s) ) / 86400 ))
else
  last_commit="unknown"
  days_ago=0
fi

# Matched on branch prefix, not author, so self-hosted Renovate still counts.
prs=$(gh pr list -R "$REPO" --state all --limit 100 --json state,mergedAt,headRefName 2>/dev/null || echo '[]')
cutoff=$(date -u -d '30 days ago' '+%Y-%m-%dT%H:%M:%SZ')

open_prs=$(jq -r --arg p 'renovate/' \
  '[.[] | select(.state == "OPEN" and (.headRefName | startswith($p)))] | length' <<<"$prs")
merged_30d=$(jq -r --arg p 'renovate/' --arg c "$cutoff" \
  '[.[] | select(.mergedAt != null and .mergedAt > $c and (.headRefName | startswith($p)))] | length' <<<"$prs")

app_count=$(gh api "repos/$REPO/contents/apps/base" --jq '[.[] | select(.type == "dir")] | length' 2>/dev/null || echo 0)

if [[ "$open_prs" == "0" ]]; then
  drift="none open"
else
  drift="$open_prs open"
fi

if (( days_ago == 0 )); then
  reconcile="$last_commit (today)"
elif (( days_ago == 1 )); then
  reconcile="$last_commit (1 day ago)"
else
  reconcile="$last_commit ($days_ago days ago)"
fi

block=$(cat <<EOF
$START
### Live cluster state

Rebuilt daily by a GitHub Action that reads the cluster repo, not the cluster.

| | |
|---|---|
| Flux | \`$flux_version\` |
| Last infrastructure change | $reconcile |
| Renovate dependency PRs | $drift, $merged_30d merged in the last 30 days |
| Apps under GitOps | $app_count |

<sub>Updated $(date -u '+%Y-%m-%d %H:%M UTC')</sub>
$END
EOF
)

BLOCK="$block" START="$START" END="$END" python3 - "$README" <<'PY'
import os, re, sys

path = sys.argv[1]
start, end = os.environ["START"], os.environ["END"]
block = os.environ["BLOCK"]

text = open(path, encoding="utf-8").read()
pattern = re.compile(re.escape(start) + ".*?" + re.escape(end), re.DOTALL)
if not pattern.search(text):
    sys.exit(f"markers {start} / {end} not found in {path}")

open(path, "w", encoding="utf-8").write(pattern.sub(lambda _: block, text, count=1))
PY

echo "flux=$flux_version last=$reconcile open=$open_prs merged30=$merged_30d apps=$app_count"
