#!/usr/bin/env bash
# Regenerates the LIVE block in README.md from the public ubernutty-cluster repo.
#
# Everything here comes from the GitHub API. Nothing talks to the cluster, so
# there is no inbound path to expose and no credential beyond GITHUB_TOKEN.
set -euo pipefail

REPO="MechHead777/ubernutty-cluster"
README="${1:-README.md}"
START="<!-- LIVE:START -->"
END="<!-- LIVE:END -->"

# Flux version, read from the components manifest Flux itself writes.
#
# Decoded to a file first rather than piped straight into grep. `grep -m1`
# exits early, which SIGPIPEs the decoder, which pipefail then reports as a
# failed command substitution and silently blanks the version.
manifest=$(mktemp)
trap 'rm -f "$manifest"' EXIT

flux_version="unknown"
if gh api "repos/$REPO/contents/clusters/staging/flux-system/gotk-components.yaml" \
     --jq '.content' 2>/dev/null | base64 -d >"$manifest" 2>/dev/null; then
  # Flux writes "# Flux Version: vX.Y.Z" into the header. Fall back to the
  # version label on the resources if that header ever goes away.
  found=$(grep -oE '# Flux Version: v[0-9]+\.[0-9]+\.[0-9]+' "$manifest" | head -n1 | awk '{print $4}')
  if [[ -z "$found" ]]; then
    found=$(grep -oE 'app\.kubernetes\.io/version: v[0-9]+\.[0-9]+\.[0-9]+' "$manifest" | head -n1 | awk '{print $2}')
  fi
  flux_version="${found:-unknown}"
fi

# Last commit to the cluster repo. This is the last time infrastructure
# actually changed, because changing it any other way is not possible.
last_commit_date=$(gh api "repos/$REPO/commits?per_page=1" --jq '.[0].commit.committer.date') || last_commit_date=""
if [[ -n "$last_commit_date" ]]; then
  last_commit=$(date -u -d "$last_commit_date" '+%Y-%m-%d')
  days_ago=$(( ( $(date -u +%s) - $(date -u -d "$last_commit_date" +%s) ) / 86400 ))
else
  last_commit="unknown"
  days_ago=0
fi

# Renovate PRs, matched on branch prefix rather than author so a self-hosted
# Renovate keeps working regardless of which identity it commits under.
prs=$(gh pr list -R "$REPO" --state all --limit 100 --json state,mergedAt,headRefName 2>/dev/null || echo '[]')
cutoff=$(date -u -d '30 days ago' '+%Y-%m-%dT%H:%M:%SZ')

open_prs=$(jq -r --arg p 'renovate/' \
  '[.[] | select(.state == "OPEN" and (.headRefName | startswith($p)))] | length' <<<"$prs")
merged_30d=$(jq -r --arg p 'renovate/' --arg c "$cutoff" \
  '[.[] | select(.mergedAt != null and .mergedAt > $c and (.headRefName | startswith($p)))] | length' <<<"$prs")

app_count=$(gh api "repos/$REPO/contents/apps/base" --jq '[.[] | select(.type == "dir")] | length' 2>/dev/null || echo 0)

# Read naturally at zero. "0 open" is the healthy state, not a broken widget.
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

This table rebuilds itself daily from a GitHub Action. It reads the public
cluster repo, never the cluster, so there is nothing exposed to the internet
to make it work. The automation is the point.

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

# Swap the block in place. python handles the multi-line replace without
# tripping over regex metacharacters in the generated content.
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
