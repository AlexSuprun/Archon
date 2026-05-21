# Deployment Guide

Archon ships in several form factors. Pick one based on how you want to run the orchestrator.

```mermaid
flowchart TB
    Source["Source build<br/>(bun install + bun run dev/start)"] --> Local["Local laptop"]
    Source --> Server["VPS / cloud VM"]
    Binary["Compiled binary<br/>(scripts/build-binaries.sh)"] --> Local
    Binary --> Server
    Docker["Docker (Dockerfile + docker-compose.yml)"] --> Server
    Docker --> Cloud["Container hosting (Fly.io, Render, k8s, ...)"]
    Brew["Homebrew (homebrew/Formula)"] --> Local
```

Detailed user-facing deployment docs: `packages/docs-web/src/content/docs/deployment/` (local, docker, cloud, windows, e2e-testing).

## Infrastructure Requirements

| Component | Minimum |
|---|---|
| CPU | 1 vCPU (worktrees + AI streaming are lightweight; LLM calls are remote) |
| RAM | 512 MB for the server, plus headroom for `bun` test runs |
| Disk | A few GB for `~/.archon/` (workspaces, worktrees, artifacts, SQLite DB, logs) |
| Network | Outbound to AI provider APIs, GitHub/GitLab/Gitea, Slack/Telegram/Discord; inbound only if you expose webhooks/web UI |
| OS | macOS, Linux. Windows via WSL (see `deployment/windows.md` and `deployment/e2e-testing-wsl.md`). |

## Persistent State

Everything stateful is under `~/.archon/` (or `$ARCHON_HOME`):

```text
~/.archon/
├── archon.db                # SQLite (if DATABASE_URL is unset)
├── config.yaml              # User-level config
├── workspaces/<owner>/<repo>/
│   ├── source/              # Cloned repo or symlink to local path
│   ├── worktrees/           # One per workflow run
│   ├── artifacts/runs/<id>/ # $ARTIFACTS_DIR contents
│   └── logs/                # JSONL workflow logs
├── workflows/, commands/, scripts/   # User-global definitions
├── vendor/codex/            # User-placed Codex binary (binary builds)
└── web-dist/<version>/      # Web UI cache (archon serve, binary only)
```

In Docker, paths are remapped to `/.archon/`.

## Source Deployment (Bun)

```bash
git clone <repo>
cd archon
bun install
cp .env.example .env       # fill in tokens
bun run start              # Hono server (no web hot reload)
# or
bun run dev                # server + web with hot reload
```

For PostgreSQL:

```bash
docker-compose --profile with-db up -d postgres
# Set DATABASE_URL=postgresql://postgres:postgres@localhost:5432/remote_coding_agent in .env
psql $DATABASE_URL < migrations/000_combined.sql
```

## Docker

`docker-compose.yml` exposes the server. `Dockerfile` is a multi-stage build that produces the server binary.

Common overrides:

```bash
cp docker-compose.override.example.yml docker-compose.override.yml
# edit ports / volumes / env / Dockerfile.user
docker-compose up -d
```

`docker-entrypoint.sh` handles startup bootstrap (auth helper, migrations).

The optional `auth-service/` directory contains a small companion service used by binary distributions to coordinate OAuth flows.

## Compiled Binary

```bash
bun run build:binaries     # outputs platform-specific binaries via bun build --compile
bun run build:checksums    # SHA-256 manifests for releases
```

Distribution channels:

- GitHub Releases (manual upload)
- Homebrew formula at `homebrew/` (refers to release artifacts)

Binary specifics:

- **Bundled defaults:** workflows/commands/skill embedded at compile time via the `bundled-defaults.generated.ts` and `bundled-skill.ts` files. CI verifies they are not stale (`check:bundled`, `check:bundled-skill`).
- **Web UI dist:** downloaded by `archon serve` on first run from the matching GitHub Release. Cached under `~/.archon/web-dist/<version>/`.
- **Codex binary:** users must place it manually at `~/.archon/vendor/codex/codex`.
- **Claude binary:** resolved via `CLAUDE_BIN_PATH`, `assistants.claude.claudeBinaryPath`, or `~/.local/bin/claude`. Required in binary builds when not set in env.

## Reverse Proxy

For exposing the web UI or webhooks publicly, terminate TLS in a reverse proxy. `Caddyfile.example` is a working template.

```mermaid
flowchart LR
    Internet -->|TLS| Caddy
    Caddy -->|http| Archon["Archon server :3090"]
    GitHub -->|webhook| Caddy
```

## CI/CD

GitHub Actions only (no other CI provider configs in this repo). Workflows live under `.github/workflows/`:

- Validate / type-check / test on PR
- Bundled-defaults integrity check
- Docs deploy (`deploy-docs.yml`) for the Astro site

`bun run validate` mirrors what CI runs. Pre-commit hooks (`husky` + `lint-staged`) handle quick checks locally.

## Releases

`/release` skill (project-defined). It:

1. Compares `dev` vs `main`
2. Generates a CHANGELOG entry (Keep a Changelog format)
3. Bumps the root `package.json` `version` field (SemVer)
4. Opens a PR from `dev` → `main`

Variants:

```bash
/release          # patch
/release minor
/release major
```

`main` is the release branch; never merge feature work directly into `main`. `dev` is the working branch.

## Health and Updates

- `GET /api/health` — adapter + system status
- `GET /api/update-check` — pulls the latest GitHub release (binary builds only; 24h cache at `~/.archon/update-check.json`)

## Telemetry

PostHog is optional and opt-in (`@archon/paths/telemetry.ts`). No telemetry by default. Tokens are never logged; PII is never logged.
