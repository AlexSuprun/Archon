# Archon — User Reference

A reference-style guide for **using** Archon to automate your SDLC. Not a contributor guide. No source-tree spelunking, no "how it's built" detours.

## Audience

- Expert with Claude Code and similar agent CLIs
- Already runs SDLC frameworks (e.g. BMAD, ai-dev-kit) — Archon plugs in alongside, not as a replacement
- Two work modes:
  1. **Work** — microservices, multirepo under `~/Documents/code/`, Jira + Bitbucket + CircleCI
  2. **Private** — single-repo per project on GitHub (Actions, Issues, PRs)

## Style

Reference-style, minimal worked examples. Each module is "look it up later," not a tutorial. Tables, decision trees, mermaid diagrams over prose.

## Phases

| # | Phase | What it answers |
|---|-------|-----------------|
| 1 | [Orientation](#phase-1--orientation) | What Archon does for you, vocabulary, which surface to use when |
| 2 | [Setup](#phase-2--setup) | Install, providers, register your repos, per-project env vars, verify |
| 3 | [Running workflows](#phase-3--running-workflows) | Invoke, watch, approve, resume, abandon, view artifacts |
| 4 | [Authoring workflows](#phase-4--authoring-workflows) | YAML you'll actually write — nodes, variables, gates, loops |
| 5 | [Agent capabilities per node](#phase-5--agent-capabilities-per-node) | Commands, skills, MCP, hooks, sub-agents — when to reach for each |
| 6 | [Worktrees & branches](#phase-6--worktrees--branches) | What Archon does to your code, parallel runs, cleanup |
| 7 | [GitHub integration](#phase-7--github-integration) | `@archon` mentions, webhook setup, gh CLI inside workflows |
| 8 | [SDLC patterns](#phase-8--sdlc-patterns) | Ticket→plan→implement, PR review, RCA/fix, multirepo + Jira/Bitbucket/CircleCI |

---

## Phase 1 — Orientation

| Module | Title | Focus |
|--------|-------|-------|
| 1.1 | What Archon gives you | Run AI workflows on your repos with isolation, approval gates, resumable state — across CLI, Web UI, and GitHub |
| 1.2 | Vocabulary | Codebase, conversation, session, workflow, run, event, isolation environment, worktree, command, skill — the words you'll see everywhere |
| 1.3 | Which surface for which job | Decision tree: CLI vs Web UI vs `@archon` on GitHub vs REST API; when each is right |

## Phase 2 — Setup

| Module | Title | Focus |
|--------|-------|-------|
| 2.1 | Install & verify | Install paths, `archon doctor`, where state lives (`~/.archon/`, repo `.archon/`) |
| 2.2 | Providers | Pick Claude / Codex / Pi; configure model, reasoning effort, web-search mode, binary paths; resolution chain (node → workflow → config) |
| 2.3 | Register your repos | Codebase registration (clone vs local path), what changes on disk, repos under `~/Documents/code/` vs single GitHub projects |
| 2.4 | Per-project env vars | `codebase_env_vars` via Web UI or `env:` in config; which node types receive them; secrets handling |
| 2.5 | Project vs home-scoped config | `.archon/config.yaml` (repo) vs `~/.archon/config.yaml` (home); when to use which; multirepo strategy |

## Phase 3 — Running workflows

| Module | Title | Focus |
|--------|-------|-------|
| 3.1 | Invoke from the CLI | `archon workflow run`, `--cwd`, `--branch`, `--no-worktree`, `--quiet`/`--verbose`, JSON mode for scripting |
| 3.2 | Use the Web UI | Start runs, stream output (SSE), watch DAG progress, browse artifacts, manage env vars |
| 3.3 | Approval gates | What pauses a run, how to approve / reject with feedback, where the feedback lands (`$LOOP_USER_INPUT`, `$REJECTION_REASON`) |
| 3.4 | Resume, abandon, cancel | Failed run recovery (skip-completed-nodes), abandoning non-terminal runs, why Archon won't auto-cancel for you |
| 3.5 | Logs & artifacts | `~/.archon/workspaces/.../logs/`, `$ARTIFACTS_DIR` per run, `/api/artifacts/:runId/*`, what each event type means |

## Phase 4 — Authoring workflows

| Module | Title | Focus |
|--------|-------|-------|
| 4.1 | Workflow file shape | Where workflows live (project / home / bundled), how Archon discovers them, validation (`archon validate workflows`) |
| 4.2 | Node types you'll actually use | `command`, `prompt`, `bash`, `script`, `loop`, `approval` — what each is for, with the smallest possible example |
| 4.3 | DAG wiring | `depends_on`, `trigger_rule` (all/any/none), `when` conditions, parallel layers — making nodes run in the right order |
| 4.4 | Variables & passing data between nodes | `$1`, `$ARGUMENTS`, `$nodeId.output`, `$ARTIFACTS_DIR`, `$WORKFLOW_ID`, `$BASE_BRANCH`, `$DOCS_DIR`, `$LOOP_*`, `$REJECTION_REASON` |
| 4.5 | Loops & structured output | Iterative `loop` nodes, completion signals, `fresh_context`, `output_format` for JSON handoff between nodes |

## Phase 5 — Agent capabilities per node

| Module | Title | Focus |
|--------|-------|-------|
| 5.1 | Commands & slash commands | Built-in `/workflow`, `/status`, `/reset`, `/init`, `/worktree`; project commands in `.archon/commands/`; home-scoped `~/.archon/commands/` |
| 5.2 | Skills, MCP, hooks, sub-agents | Per-node `skills` / `mcp` / `hooks` / `agents` (Claude-only) — when to reach for each, MCP env expansion, AgentDefinition wrapping |
| 5.3 | Tool restrictions & advanced options | `allowed_tools` / `denied_tools`, `effort` / `thinking`, `sandbox`, `maxBudgetUsd`, `fallbackModel`, `betas` |

## Phase 6 — Worktrees & branches

| Module | Title | Focus |
|--------|-------|-------|
| 6.1 | What Archon does to your code | Worktree-per-run by default, base branch auto-detect, `--no-worktree` opt-out, port allocation for parallel `bun dev` |
| 6.2 | Branch lifecycle | `archon complete <branch>`, `isolation cleanup --merged --include-closed`, what gets pushed / removed / left alone |
| 6.3 | Safe operation | `git clean -fd` ban, what to do when a worktree has uncommitted changes, recovering from interrupted runs |

## Phase 7 — GitHub integration

| Module | Title | Focus |
|--------|-------|-------|
| 7.1 | `@archon` mentions | Comments-only rule (descriptions ignored), supported events, webhook signature verification, conversation-id format (`owner/repo#N`) |
| 7.2 | Setting up the webhook | Creating the webhook, secret, allowed users, what events to enable, smoke-testing with `gh api` |
| 7.3 | gh CLI inside workflows | Reading issue/PR context, posting comments, opening PRs, fetching CI logs — patterns for `bash:` / `script:` nodes |

## Phase 8 — SDLC patterns

Reference patterns, not full implementations. Each shows the workflow shape, the data flow, and the integration touchpoints.

| Module | Title | Focus |
|--------|-------|-------|
| 8.1 | Ticket → plan → implement → PR | Pattern for both Jira (work) and GitHub Issues (private); fetch → plan → approval → implement loop → PR open |
| 8.2 | PR review & feedback loops | Review-on-PR workflow, responding to review comments, fixing CI failures (CircleCI for work, GitHub Actions for private) |
| 8.3 | Bug triage / RCA / fix | Triage → structured RCA artifact (`output_format`) → fix loop, with approval gate before merge |
| 8.4 | Multirepo (`~/Documents/code/`) bridging | Home-scoped workflows reused across services, per-repo `.archon/config.yaml` for codebase-specific env / model overrides, driving Archon from Bitbucket pipelines + CircleCI jobs (REST + CLI; no native adapter) |

---

## Companion files (after module phases)

- `glossary.md` — every term you'll see, with relationship diagrams
- `cheat-sheet.md` — one-page visual: surfaces, CLI reference, variable substitution table, node types lookup

## Out of scope

- Slack / Telegram / Discord (skipped per request)
- Source-code internals, contributing, package architecture
- Comparisons to other SDLC frameworks
- Beginner Claude Code / git tutorials
