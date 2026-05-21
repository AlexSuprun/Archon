# Integration Architecture

How the four parts (backend, frontend, cli, documentation) talk to each other and to external systems.

## Inter-Part Integration Matrix

| From → To | Mechanism | Notes |
|---|---|---|
| frontend → backend | REST `/api/*` + SSE `/api/stream/<convId>` | Types generated from `/api/openapi.json` |
| cli → backend | In-process (`@archon/core`, `@archon/workflows`); `serve` boots `@archon/server` | Never HTTP between them |
| backend (adapters) → backend (core) | Direct call to `handleMessage()` | Adapters call core; core never calls adapters back, it streams through `IPlatformAdapter` |
| documentation → any | None | Static site; no runtime coupling |

## Runtime Flow: Web Chat Message

```mermaid
sequenceDiagram
    autonumber
    participant Browser
    participant Hono as Hono /api
    participant Web as WebAdapter (server)
    participant Core as orchestrator
    participant Provider as IAgentProvider
    participant DB as IDatabase

    Browser->>Hono: POST /api/conversations/{id}/message
    Hono->>Core: handleMessage(convId, text)
    Core->>DB: load conversation + active session
    Core->>Provider: sendQuery(options, prompt)
    loop streaming
        Provider-->>Core: MessageChunk
        Core-->>Web: emit to platform
        Web-->>Browser: SSE event on /api/stream/{convId}
    end
    Core->>DB: persist final messages + token usage
```

## Runtime Flow: GitHub Issue Comment @archon

```mermaid
sequenceDiagram
    autonumber
    participant GH as GitHub
    participant Hono as POST /webhooks/github
    participant Adapter as GithubAdapter
    participant Core as orchestrator
    participant Iso as IsolationProvider
    participant WF as WorkflowExecutor

    GH->>Hono: issue_comment.created (signed)
    Hono->>Adapter: verify HMAC, parse @archon mention
    Adapter->>Core: handleMessage(convId='owner/repo#42', text)
    Core->>Iso: resolve or create worktree
    Iso-->>Core: working_path
    Core->>WF: executeWorkflow(name, deps, cwd=working_path)
    loop DAG layers
        WF->>WF: run node(s) concurrently
        WF-->>Adapter: stream chunks
        Adapter-->>GH: post comment(s)
    end
```

## Runtime Flow: CLI Workflow Run

```mermaid
sequenceDiagram
    autonumber
    participant User
    participant CLI as archon CLI
    participant Core as @archon/core
    participant Iso as @archon/isolation
    participant WF as @archon/workflows
    participant Provider as IAgentProvider

    User->>CLI: archon workflow run implement "..."
    CLI->>Core: build WorkflowDeps + CliAdapter
    CLI->>Iso: create worktree (unless --no-worktree)
    Iso-->>CLI: working_path
    CLI->>WF: executeWorkflow(name, deps, cwd=working_path)
    WF->>Provider: sendQuery per node
    Provider-->>CLI: chunks → stdout
    WF-->>CLI: WorkflowExecutionResult
```

## Data Flow: Workflow Run Resume

```mermaid
flowchart LR
    api["POST /api/workflows/runs/:id/resume"] --> hydrate["hydrateResumableRun()"]
    hydrate --> store["IWorkflowStore.getWorkflowRun + getCompletedDagNodeOutputs"]
    store --> exec["executeDagWorkflow(skipCompletedNodes=true)"]
    exec --> emit["WorkflowEventEmitter"]
    emit --> sse["SSE /api/stream/:convId"]
```

Completed nodes are skipped by reading the `completed_dag_node_outputs` cache (built from `remote_agent_workflow_events`). AI session context is **not** restored — the rerun starts fresh on each remaining node.

## External Integrations

| External | Protocol | Code path |
|---|---|---|
| Anthropic API | Claude Agent SDK (HTTP/stream) | `@archon/providers/claude/provider.ts` |
| OpenAI Codex | Codex SDK (HTTP/stream + native binary) | `@archon/providers/codex/provider.ts` |
| Pi (multi-LLM) | `@mariozechner/pi-coding-agent` → ~20 vendor APIs | `@archon/providers/community/pi/` |
| Slack | Bolt SDK (events polling, not webhooks) | `@archon/adapters/chat/slack/` |
| Telegram | Bot API (long polling, Grammy) | `@archon/adapters/chat/telegram/` |
| Discord | WebSocket (discord.js) | `@archon/adapters/community/chat/discord/` |
| GitHub | Webhooks + Octokit REST | `@archon/adapters/forge/github/` |
| GitLab | Webhooks + REST | `@archon/adapters/community/forge/gitlab/` |
| Gitea | Webhooks + REST | `@archon/adapters/community/forge/gitea/` |
| PostHog | HTTPS | `@archon/paths/telemetry.ts` (opt-in) |
| MCP servers | Per-server transports (stdio/HTTP) | `@archon/providers/mcp/config.ts` translates and forwards |
| Git remotes | HTTPS/SSH | `@archon/git` via `execFileAsync` |

## Authentication Surfaces

| Boundary | Auth mechanism |
|---|---|
| Slack/Telegram/Discord adapters | Per-adapter `*_ALLOWED_USER_IDS` env-var whitelist; silent rejection of others |
| GitHub/GitLab/Gitea webhooks | HMAC signature verification (raw body via `c.req.text()`) |
| Web UI | Trusted (single-developer tool); no built-in user auth — protect via reverse proxy / VPN |
| AI provider APIs | Environment variables (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, etc.); never logged |
| Git remotes | `GH_TOKEN`, `GITLAB_TOKEN`, `GITEA_TOKEN` + `*_URL` env vars used by clone resolver |

## Event Bus

`@archon/workflows/event-emitter.ts` provides a singleton emitter for workflow observability. Subscribers:

- `@archon/server/adapters/web/workflow-bridge.ts` forwards events into the SSE stream
- `@archon/cli` consumes events to render progress in terminal
- `@archon/core/db/workflow-events.ts` persists a lean subset to `remote_agent_workflow_events` for UI history queries
