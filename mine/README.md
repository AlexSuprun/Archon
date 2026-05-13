# mine/

Personal tooling for this fork. Not part of upstream Archon.

## scripts/

### `archon-sync.sh`

Sync fork from upstream and restart the local launchd-managed dev server.

Flow:
1. Stash dirty tree (incl. untracked); pop on exit.
2. Stop launchd job `com.archon.server` (frees ports + esbuild).
3. `git fetch upstream` → fast-forward local `dev` from `upstream/dev` → push to `origin`.
4. Merge `dev` into current branch (skipped if already on `dev`).
5. `bun install` + `bun --filter @archon/web build`.
6. Start launchd job → health probes on `:3090` and `:5173`.

Run: `./mine/scripts/archon-sync.sh`
