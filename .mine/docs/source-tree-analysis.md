# Source Tree Analysis

Monorepo using Bun workspaces (`packages/*`). Annotated tree with purpose of each critical folder.

```text
archon/
├── package.json                       # Root manifest, workspace orchestration scripts
├── tsconfig.json                      # Base TS config (strict)
├── bunfig.toml                        # Bun config
├── eslint.config.mjs                  # Flat ESLint config (max-warnings 0 in CI)
├── docker-compose.yml                 # Local Docker stack (server + optional postgres)
├── Dockerfile                         # Multi-stage build for the server binary
├── docker-entrypoint.sh               # Startup script (auth bootstrap, migrations)
├── Caddyfile.example                  # Reverse-proxy template
├── CLAUDE.md                          # Primary architectural narrative (load first for AI context)
├── README.md / CONTRIBUTING.md / SECURITY.md / CHANGELOG.md
│
├── migrations/                        # PostgreSQL DDL; 000_combined.sql + numbered 001..021
│
├── packages/                          # Bun workspaces — see per-part architecture docs
│   ├── paths/                         # (backend) Path resolution, Pino logger factory, dotenv loader, telemetry
│   ├── git/                           # (backend) Worktree/branch/repo wrappers around execFileAsync
│   ├── isolation/                     # (backend) Worktree-based isolation provider, resolver, error classifiers
│   ├── providers/                     # (backend) AI agent providers — Claude / Codex / Pi (community)
│   │   └── src/{claude,codex,community/pi}/
│   ├── workflows/                     # (backend) DAG executor, loader, router, schemas, bundled defaults
│   │   └── src/schemas/               # Zod schemas: dag-node, workflow, workflow-run, loop, hooks, retry
│   ├── core/                          # (backend) DB (SQLite+PG adapters), orchestrator, handlers, services, ops
│   │   └── src/db/adapters/{sqlite,postgres}.ts
│   ├── adapters/                      # (backend) Platform adapters: Slack/Telegram/GitHub + community Discord/GitLab/Gitea
│   ├── server/                        # (backend) Hono HTTP server, web SSE adapter, OpenAPI routes
│   │   └── src/routes/api.ts          # All REST routes (≈40 createRoute() entries)
│   ├── cli/                           # (cli) Command-line entry point: workflow / isolation / chat / serve / doctor
│   ├── web/                           # (frontend) React 19 SPA — chat, dashboard, workflow builder + execution view
│   │   └── src/{routes,components,stores,hooks,lib}/
│   └── docs-web/                      # (documentation) Astro + Starlight docs site
│       └── src/content/docs/{getting-started,guides,adapters,deployment,book,reference,contributing}/
│
├── .archon/                           # Repo-level Archon config + bundled defaults source
│   ├── workflows/defaults/            # Bundled default workflows (YAML)
│   ├── commands/defaults/             # Bundled default commands (markdown)
│   ├── maintainer-standup/            # Internal maintainer assist artifacts
│   └── config.yaml                    # Repo-specific config (assistant defaults etc.)
│
├── .claude/                           # Claude Code skills + agents config (project-level)
│   ├── skills/                        # Installed skills, including bmad-document-project
│   └── docs/                          # Contributor-facing architecture deep dives
│
├── examples/workflows/                # Standalone YAML examples
├── scripts/                           # Build/release/bundling scripts (generate-bundled-defaults.ts etc.)
├── deploy/                            # Deployment artifacts (compose overrides, etc.)
├── homebrew/                          # Homebrew formula for the CLI binary
├── auth-service/                      # OAuth helper service for binary distributions
└── _bmad/, _bmad-output/              # BMM workflow tooling (not part of product)
```

## Critical Folders by Part

### backend
- **Entry point:** `packages/server/src/index.ts` (Hono app boot, port allocation, route registration)
- **Routes:** `packages/server/src/routes/api.ts` (everything in one file by design)
- **Orchestration loop:** `packages/core/src/orchestrator/orchestrator-agent.ts` + `orchestrator.ts`
- **Workflow engine:** `packages/workflows/src/executor.ts` → `dag-executor.ts`
- **DB schema (source of truth):** `migrations/000_combined.sql` for PG; `packages/core/src/db/adapters/sqlite.ts` for SQLite bootstrap
- **Provider registry:** `packages/providers/src/registry.ts`

### frontend
- **Entry:** `packages/web/src/main.tsx` → `App.tsx` (React Router 7)
- **Pages:** `packages/web/src/routes/{ChatPage,DashboardPage,WorkflowsPage,WorkflowBuilderPage,WorkflowExecutionPage,SettingsPage}.tsx`
- **Generated API types:** `packages/web/src/lib/api.generated.d.ts` (from OpenAPI spec; regen via `bun --filter @archon/web generate:types`)
- **State:** `packages/web/src/stores/workflow-store.ts` (Zustand)
- **SSE transport:** `packages/web/src/hooks/useSSE.ts`, `useDashboardSSE.ts`

### cli
- **Entry:** `packages/cli/src/cli.ts` (clack/prompts-based)
- **Commands:** `packages/cli/src/commands/{workflow,isolation,chat,serve,setup,doctor,skill,validate,version,continue}.ts`

### documentation
- **Content:** `packages/docs-web/src/content/docs/` — Starlight collection
- **Config:** `packages/docs-web/astro.config.mjs` (sidebar, integrations)
- **Generated workflow JSON for marketplace:** `packages/docs-web/src/pages/workflows.json.ts`

## Entry Points (each part)

| Part | Entry | Run command |
|---|---|---|
| backend | `packages/server/src/index.ts` | `bun run dev:server` |
| frontend | `packages/web/src/main.tsx` | `bun run dev:web` |
| cli | `packages/cli/src/cli.ts` | `bun run cli <command>` |
| documentation | Astro auto | `bun run dev:docs` |

## Inter-Part Interfaces

- **frontend → backend:** REST under `/api/*` + SSE at `/api/stream/<conversationId>`. Types generated from `GET /api/openapi.json`.
- **cli → backend:** Direct imports of `@archon/server` (the `serve` command boots the same Hono app). Other CLI commands skip the server entirely and call `@archon/core` / `@archon/workflows` in-process.
- **adapters → core:** Adapters call `handleMessage` (`@archon/core`) inside their event handlers; no HTTP hop.
- **workflows ↔ core:** `@archon/workflows` defines `IWorkflowStore`; `@archon/core/workflows/store-adapter.ts` provides the implementation. Provider types come from `@archon/providers/types`.

See [integration-architecture.md](./integration-architecture.md) for data-flow details.
