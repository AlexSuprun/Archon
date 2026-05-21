# Project Overview

## Name and Purpose

**Archon** — a remote agentic coding platform. It lets a single developer control AI coding assistants (Claude Code SDK, Codex SDK, ~20 LLMs via Pi) from Slack, Telegram, Discord, GitHub, GitLab, Gitea, a CLI, and a web UI.

Workflow execution is the core abstraction: YAML files in `.archon/workflows/` define DAGs of nodes (`command:`, `prompt:`, `bash:`, `script:`, `loop:`, `approval:`) that run AI plus deterministic steps in isolated git worktrees.

## Executive Summary

- **Single-developer tool.** No multi-tenant complexity. State is local: SQLite by default, PostgreSQL optional.
- **Platform-agnostic.** Conversation interface unified across Slack/Telegram/GitHub/Discord/GitLab/Gitea/CLI/web through `IPlatformAdapter`.
- **Provider-agnostic AI.** `IAgentProvider` contract; built-in Claude and Codex providers, community Pi provider for ~20 LLM backends.
- **Workflow engine.** DAG executor with concurrency, retries, conditional execution, approval gates, loops, and per-node provider/model/tools/MCP/skills/hooks overrides.
- **Git as first-class citizen.** Worktree-per-run isolation, branch lifecycle commands, repo-aware port allocation.

## Tech Stack Summary

| Category | Technology |
|---|---|
| Runtime | Bun ≥ 1.3 |
| Language | TypeScript (strict) |
| HTTP server | Hono + `@hono/zod-openapi` |
| Database | SQLite (default, via `bun:sqlite`) or PostgreSQL (`pg`) |
| Schemas | Zod (re-exported via `@hono/zod-openapi`) |
| Logger | Pino |
| Frontend | React 19, Vite 6, Tailwind v4, shadcn/ui, Zustand, TanStack Query, React Router 7, XYFlow (DAG canvas) |
| Docs site | Astro 6 + Starlight |
| AI SDKs | `@anthropic-ai/claude-agent-sdk`, `@openai/codex-sdk`, `@mariozechner/pi-coding-agent` |
| Adapters | `@slack/bolt`, `grammy` (Telegram), `discord.js`, `@octokit/rest` |
| Testing | `bun test` with per-package isolation (mock.module is process-global) |

## Architecture Type

- **Repository:** monorepo (Bun workspaces, `packages/*`)
- **Pattern:** layered backend (HTTP → orchestrator → providers/workflow engine → storage) with platform adapters at the edge and React SPA + Astro docs site as separate frontends
- **Persistence:** dual-dialect (SQLite primary, PostgreSQL via adapter) behind `IDatabase`
- **AI conversations:** session-immutable with explicit transitions (`parent_session_id`, `transition_reason`)
- **Workflow runs:** DAG with topological execution, per-node sandboxing options, JSONL file logs + lean DB event log for the UI

## Repository Structure

Monorepo with 4 documentation parts (user-defined grouping):

| Part | Packages | Project type |
|---|---|---|
| backend | `packages/server`, `core`, `workflows`, `providers`, `adapters`, `isolation`, `git`, `paths` | backend |
| frontend | `packages/web` | web |
| cli | `packages/cli` | cli |
| documentation | `packages/docs-web` | web (static site) |

## Where Things Live

- Source: `packages/*/src/`
- Migrations: `migrations/` (PostgreSQL; SQLite auto-initializes from `core/db/adapters/sqlite.ts`)
- Bundled workflows/commands defaults: `.archon/workflows/defaults/`, `.archon/commands/defaults/` (embedded in binaries via `packages/workflows/src/defaults/bundled-defaults.generated.ts`)
- Example workflows: `examples/workflows/`
- User-facing docs site source: `packages/docs-web/src/content/docs/` (50+ MDX pages)
- Architectural narrative for contributors: [CLAUDE.md](../CLAUDE.md), [.claude/docs/architecture-deep-dive.md](../.claude/docs/architecture-deep-dive.md)

## Links

- [Architecture (master)](./architecture.md)
- [Source tree analysis](./source-tree-analysis.md)
- [Development guide](./development-guide.md)
- [Deployment guide](./deployment-guide.md)
- [API contracts](./api-contracts.md)
- [Data models](./data-models.md)
- [Integration architecture](./integration-architecture.md)
- [Component inventory (frontend)](./component-inventory.md)
- [Contribution guide](./contribution-guide.md)
