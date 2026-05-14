#!/usr/bin/env bash
# Sync fork from upstream, merge into current branch, reinstall, rebuild web, restart launchd.
set -euo pipefail

REPO="/Users/alexsuprun/my-code/archon/archon"
UPSTREAM_REMOTE="upstream"
ORIGIN_REMOTE="origin"
SYNC_BRANCH="dev"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/com.archon.server.plist"
LAUNCHD_LABEL="com.archon.server"
SKILL_SRC="$REPO/.claude/skills/archon"
SKILL_DST="$HOME/.claude/skills/archon"

cd "$REPO"

CURRENT_BRANCH="$(git symbolic-ref --short HEAD)"
echo "==> Repo: $REPO"
echo "==> Current branch: $CURRENT_BRANCH"

STASHED=0
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  echo "==> Dirty tree — stashing (including untracked)"
  git stash push -u -m "archon-sync auto-stash $(date +%FT%T)"
  STASHED=1
fi

cleanup() {
  if [ "$STASHED" -eq 1 ]; then
    echo "==> Restoring stash"
    git stash pop || echo "!! stash pop had conflicts — resolve manually (git stash list)"
  fi
}
trap cleanup EXIT

echo "==> Fetching $UPSTREAM_REMOTE"
git fetch "$UPSTREAM_REMOTE" --prune

echo "==> Fast-forwarding $SYNC_BRANCH from $UPSTREAM_REMOTE/$SYNC_BRANCH"
git checkout "$SYNC_BRANCH"
git merge --ff-only "$UPSTREAM_REMOTE/$SYNC_BRANCH"

echo "==> Pushing $SYNC_BRANCH to $ORIGIN_REMOTE"
git push "$ORIGIN_REMOTE" "$SYNC_BRANCH"

echo "==> Returning to $CURRENT_BRANCH"
git checkout "$CURRENT_BRANCH"

if [ "$CURRENT_BRANCH" != "$SYNC_BRANCH" ]; then
  echo "==> Merging $SYNC_BRANCH into $CURRENT_BRANCH"
  git merge --no-edit "$SYNC_BRANCH"
fi

echo "==> Stopping launchd job $LAUNCHD_LABEL (free ports + esbuild)"
launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
sleep 2

echo "==> bun install"
bun install

echo "==> Building web dist"
bun --filter @archon/web build

if [ -d "$SKILL_SRC" ]; then
  echo "==> Syncing global Claude skill: $SKILL_DST"
  mkdir -p "$SKILL_DST"
  rsync -a --delete "$SKILL_SRC/" "$SKILL_DST/"
else
  echo "!! Skill source missing at $SKILL_SRC — skipping skill sync"
fi

echo "==> Starting launchd job $LAUNCHD_LABEL"
launchctl load "$LAUNCHD_PLIST"
sleep 5
launchctl list "$LAUNCHD_LABEL" | grep -E '"PID"|"LastExitStatus"' || true

echo "==> Health checks"
curl -s -o /dev/null -w "  3090: %{http_code}\n" http://localhost:3090/api/health || true
curl -s -o /dev/null -w "  5173: %{http_code}\n" http://localhost:5173/ || true

echo "==> Done"
