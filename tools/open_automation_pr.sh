#!/usr/bin/env bash
# Open/reuse a protected-branch PR, with a manual handoff for Actions policy.
set -euo pipefail
base="$1"
head="$2"
title="$3"
body="$4"
repo="${GH_REPO:-${GITHUB_REPOSITORY:?Set GH_REPO or GITHUB_REPOSITORY}}"
pr="$(gh pr list --repo "$repo" --base "$base" --head "$head" --state open --json url --jq '.[0].url // empty')"
if [[ -z "$pr" ]]; then
  error_file="$(mktemp)"
  trap 'rm -f "$error_file"' EXIT
  if pr="$(gh pr create --repo "$repo" --base "$base" --head "$head" \
      --title "$title" --body "$body" 2>"$error_file")"; then
    :
  elif grep -Fq 'GitHub Actions is not permitted to create or approve pull requests' "$error_file"; then
    pr="https://github.com/${repo}/compare/${base}...${head}?expand=1"
    echo "::warning::Actions cannot open PRs in this repository. Open the prepared PR: $pr"
  else
    cat "$error_file" >&2
    exit 1
  fi
fi
printf 'Review %s → %s: %s\n' "$head" "$base" "$pr"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  printf '### Review required\n\n[%s → %s](%s)\n\nMerge after required CI passes.\n' \
    "$head" "$base" "$pr" >> "$GITHUB_STEP_SUMMARY"
fi
# Events created by GITHUB_TOKEN do not trigger pull_request CI. Explicit
# dispatch also covers the manual-PR fallback. Use the workflow token because
# a release PAT need not have Actions permission.
GH_TOKEN="${GH_WORKFLOW_TOKEN:-${GH_TOKEN:?Set GH_TOKEN}}" \
  gh workflow run ci.yml --repo "$repo" --ref "$head"
