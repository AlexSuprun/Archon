# Archon — Project Documentation Index

> Primary AI-context entry point. Start here when loading the project into Claude/Codex/Pi context.

**Generated:** 2026-05-21
**Mode:** initial_scan (deep)
**Repository type:** monorepo (Bun workspaces)
**Parts:** 4 — backend / frontend / cli / documentation

## Project Overview

- **Name:** Archon
- **Purpose:** Remote agentic coding platform — control AI coding assistants (Claude / Codex / Pi) from Slack, Telegram, Discord, GitHub, GitLab, Gitea, CLI, and a Web UI.
- **Audience:** single-developer power users of AI coding tools.
- **Primary language:** TypeScript (strict) on Bun ≥ 1.3
- **Architecture:** layered hexagonal backend + React 19 SPA + Astro/Starlight docs site
- **Persistence:** SQLite default, PostgreSQL optional

## Quick Reference

| Concern | Tech / Location |
|---|---|
| Runtime | Bun ≥ 1.3 |
| HTTP | Hono + `@hono/zod-openapi` |
| DB | SQLite (default) / PostgreSQL via `IDatabase` adapter |
| AI providers | Claude Agent SDK, Codex SDK, Pi (community, ~20 LLMs) |
| Frontend | React 19 + Vite 6 + Tailwind v4 + Zustand + TanStack Query + XYFlow |
| Docs | Astro 6 + Starlight |
| Workflow engine | DAG nodes — command / prompt / bash / script / loop / approval |
| Isolation | Git worktrees, one per run by default |
| Tests | `bun test`, per-package isolated invocations |
| CI gate | `bun run validate` (six checks) |

### Parts

| Part | Packages | Architecture doc |
|---|---|---|
| backend | server, core, workflows, providers, adapters, isolation, git, paths | [architecture-backend.md](./architecture-backend.md) |
| frontend | web | [architecture-frontend.md](./architecture-frontend.md) |
| cli | cli | [architecture-cli.md](./architecture-cli.md) |
| documentation | docs-web | [architecture-documentation.md](./architecture-documentation.md) |

## Generated Documentation

- [Project Overview](./project-overview.md)
- [Architecture (master)](./architecture.md)
- [Architecture — Backend](./architecture-backend.md)
- [Architecture — Frontend](./architecture-frontend.md)
- [Architecture — CLI](./architecture-cli.md)
- [Architecture — Documentation](./architecture-documentation.md)
- [Integration Architecture](./integration-architecture.md)
- [Source Tree Analysis](./source-tree-analysis.md)
- [Component Inventory (frontend)](./component-inventory.md)
- [API Contracts](./api-contracts.md)
- [Data Models](./data-models.md)
- [Development Guide](./development-guide.md)
- [Deployment Guide](./deployment-guide.md)
- [Contribution Guide](./contribution-guide.md)

## Existing Documentation (already in repo)

- [README.md](../README.md) — user-facing introduction
- [CLAUDE.md](../CLAUDE.md) — 46 KB contributor + AI handbook (load this whenever you need detailed context)
- [CONTRIBUTING.md](../CONTRIBUTING.md) — contribution rules
- [SECURITY.md](../SECURITY.md) — vulnerability reporting
- [CHANGELOG.md](../CHANGELOG.md) — Keep a Changelog format
- [.claude/docs/architecture-deep-dive.md](../.claude/docs/architecture-deep-dive.md) — contributor architecture deep dive
- [examples/workflows/README.md](../examples/workflows/README.md) — workflow examples
- [.archon/maintainer-standup/README.md](../.archon/maintainer-standup/README.md) — maintainer assist tooling
- Full user-facing docs site under [packages/docs-web/src/content/docs/](../packages/docs-web/src/content/docs/) — 50+ MDX pages including:
  - Getting started: overview, quick-start, installation, configuration, concepts, ai-assistants
  - Guides: authoring-workflows, authoring-commands, approval/loop/script nodes, hooks, skills, mcp-servers, global-workflows, remotion-workflow
  - Adapters: slack, telegram, github, web
  - Deployment: local, docker, cloud, windows, e2e-testing
  - Reference: architecture, api, cli
  - Book: curated narrative onboarding path
  - Contributing: new-developer-guide, cli-internals, adding-a-community-provider, releasing, dx-quirks

## Getting Started

```bash
bun install
cp .env.example .env       # fill in tokens you need
bun run dev                # server + web UI with hot reload
```

CLI:

```bash
bun run cli workflow list
bun run cli workflow run assist "What does the orchestrator do?"
bun run cli doctor
```

Pre-PR:

```bash
bun run validate
```

## Next Steps for AI Agents

1. **For broad questions:** read `CLAUDE.md` (it has the most context).
2. **For workflow YAML authoring:** read `packages/docs-web/src/content/docs/guides/authoring-workflows.md`.
3. **For backend changes:** start from [architecture-backend.md](./architecture-backend.md) and follow links into the relevant package's source.
4. **For API changes:** edit `packages/server/src/routes/api.ts` (the canonical route file) + the matching `routes/schemas/*.schemas.ts`; regen frontend types with `bun --filter @archon/web generate:types`.
5. **For DB migrations:** add to `migrations/`, update `migrations/000_combined.sql`, and update SQLite bootstrap in `packages/core/src/db/adapters/sqlite.ts`.
6. **For new providers:** see `packages/docs-web/src/content/docs/contributing/adding-a-community-provider.md`.
