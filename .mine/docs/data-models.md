# Data Models

Database schema and workflow engine schemas.

## Database Schema

SQLite by default (`~/.archon/archon.db`, bootstrapped from `packages/core/src/db/adapters/sqlite.ts`). PostgreSQL via `DATABASE_URL` (DDL in `migrations/000_combined.sql`). The same `IDatabase` interface is used for both dialects.

Eight tables, all prefixed `remote_agent_`.

### Entity Relationship

```mermaid
erDiagram
    codebases ||--o{ codebase_env_vars : has
    codebases ||--o{ conversations : "hosts"
    codebases ||--o{ sessions : "scopes"
    codebases ||--o{ isolation_environments : "owns"
    codebases ||--o{ workflow_runs : "scopes"
    conversations ||--o{ sessions : "has active"
    conversations ||--o{ messages : "logs"
    conversations ||--o{ workflow_runs : "starts"
    conversations }o--|| isolation_environments : "currently uses"
    sessions ||--o{ sessions : "parent_session_id (audit)"
    workflow_runs ||--o{ workflow_events : "emits"
    workflow_runs }o--|| conversations : "parent_conversation_id"

    codebases {
        UUID id PK
        string name
        string repository_url
        string default_cwd
        string ai_assistant_type
        bool allow_env_keys
        jsonb commands
    }
    codebase_env_vars {
        UUID id PK
        UUID codebase_id FK
        string key
        text value
    }
    conversations {
        UUID id PK
        string platform_type
        string platform_conversation_id
        UUID codebase_id FK
        string cwd
        string ai_assistant_type
        UUID isolation_env_id FK
        string title
        bool hidden
        timestamp deleted_at
        timestamp last_activity_at
    }
    sessions {
        UUID id PK
        UUID conversation_id FK
        UUID codebase_id FK
        string ai_assistant_type
        string assistant_session_id
        bool active
        jsonb metadata
        UUID parent_session_id FK
        text transition_reason
        text ended_reason
    }
    isolation_environments {
        UUID id PK
        UUID codebase_id FK
        text workflow_type
        text workflow_id
        text provider
        text working_path
        text branch_name
        text status
        text created_by_platform
        jsonb metadata
    }
    workflow_runs {
        UUID id PK
        string workflow_name
        UUID conversation_id FK
        UUID codebase_id FK
        UUID parent_conversation_id FK
        int current_step_index
        string status
        text user_message
        jsonb metadata
        text working_path
        timestamp last_activity_at
    }
    workflow_events {
        UUID id PK
        UUID workflow_run_id FK
        string event_type
        int step_index
        string step_name
        jsonb data
    }
    messages {
        UUID id PK
        UUID conversation_id FK
        string role
        text content
        jsonb metadata
    }
```

### Key Invariants

- `(platform_type, platform_conversation_id)` is unique on `conversations`. Slack uses `thread_ts`, Telegram uses `chat_id`, GitHub uses `owner/repo#number`, Discord uses channel id, Web uses a user-provided string.
- Only **one** session per conversation is `active = true`. Enforced by a partial unique index (migration 011).
- Sessions are **immutable** after a transition — a new row is inserted with `parent_session_id` pointing to the prior row. `transition_reason` is one of `first-message`, `plan-to-execute`, `reset-requested`, `cwd-changed`, `conversation-closed`, etc.
- Only `status = 'active'` isolation environments enforce `(codebase_id, workflow_type, workflow_id)` uniqueness (partial unique index `unique_active_workflow`).
- `workflow_runs.status ∈ {pending, running, completed, failed, cancelled, paused}`. The runtime never autonomously flips a non-terminal run; it relies on explicit user action (`/workflow abandon`, `/workflow cancel`, `/workflow resume`).
- `codebases.commands` is JSONB mapping command name → relative path under the codebase.
- `codebase_env_vars` values are injected into Claude/Codex SDK options and into `bash:`/`script:` subprocess environments when the project is codebase-scoped.

### Cleanup Policy

`@archon/core/services/cleanup-service.ts` prunes only **terminal** rows:

- Workflow runs older than N days where `status` is terminal
- Isolation environments where status is `destroyed`
- Worktrees whose branches are merged into the default branch (CLI `--merged` flag)

Non-terminal rows are never touched by the runtime; users must abandon/cancel them.

## Workflow Engine Types

Engine schemas live in `packages/workflows/src/schemas/`. All are Zod, imported from `@hono/zod-openapi`.

### Files

| File | Exports |
|---|---|
| `dag-node.ts` | `dagNodeSchema`, six variant schemas (Command/Prompt/Bash/Loop/Approval/Cancel), `triggerRuleSchema`, `TRIGGER_RULES`, Claude SDK option schemas (`effortLevelSchema`, `thinkingConfigSchema`, `sandboxSettingsSchema`) |
| `workflow.ts` | `workflowBaseSchema`, `workflowDefinitionSchema`, `WorkflowDefinition`, `WorkflowExecutionResult`, `WorkflowSource`, `WorkflowWithSource`, `WorkflowLoadError`, `WorkflowLoadResult`, `modelReasoningEffortSchema`, `webSearchModeSchema`, `workflowWorktreePolicySchema` |
| `workflow-run.ts` | Run lifecycle schemas: `workflowRunSchema`, `workflowRunStatusSchema`, `approvalContextSchema`, `WorkflowRun`, `WorkflowRunStatus` |
| `loop.ts` | `loopNodeConfigSchema` (max iterations, completion conditions) |
| `retry.ts` | `stepRetryConfigSchema` |
| `hooks.ts` | `workflowNodeHooksSchema`, `WORKFLOW_HOOK_EVENTS` |
| `index.ts` | Re-exports |

### DAG Node Variants

```mermaid
flowchart LR
    DagNode --> Command["command:<br/>named command file"]
    DagNode --> Prompt["prompt:<br/>inline AI prompt"]
    DagNode --> Bash["bash:<br/>shell script (stdout = $node.output)"]
    DagNode --> Script["script:<br/>bun/uv runtime"]
    DagNode --> Loop["loop:<br/>iterative AI until completion signal"]
    DagNode --> Approval["approval:<br/>human gate (capture_response optional)"]
    DagNode --> Cancel["cancel: (internal)"]
```

Variant selection is by **mutual exclusivity** of fields in a flat schema (no `type:` discriminant). The transform step in `dagNodeSchema` picks the concrete union arm.

### Trigger Rules (DAG joins)

```mermaid
flowchart LR
    all_success --> A["all parents succeeded"]
    one_success --> B["at least one parent succeeded"]
    none_failed_min_one_success --> C["no failures, at least one success"]
    all_done --> D["all parents reached terminal state"]
```

Source of truth: `triggerRuleSchema.options`; never duplicate as a plain array. The `@archon/web` package is the only exception (must re-derive locally because `api.generated.d.ts` is type-only).

### Substitution Variables (in prompts)

| Variable | Source |
|---|---|
| `$1`, `$2`, `$3`, `$ARGUMENTS` | Positional / full user args |
| `$<nodeId>.output` | Cleaned stdout / final assistant message from an upstream node |
| `$ARTIFACTS_DIR` | Pre-created per-run artifacts dir (`~/.archon/workspaces/<owner>/<repo>/artifacts/runs/<runId>/`) |
| `$WORKFLOW_ID` | Workflow run UUID |
| `$BASE_BRANCH` | Auto-detected base branch (or `worktree.baseBranch`) |
| `$DOCS_DIR` | `docs.path` from config (default `docs/`) |
| `$LOOP_USER_INPUT` | User's text on a resumed interactive loop (first iteration only) |
| `$REJECTION_REASON` | Reviewer's reason at an `on_reject` prompt |
| `$LOOP_PREV_OUTPUT` | Previous loop iteration output (empty on first iteration) |

## IWorkflowStore Interface

`packages/workflows/src/store.ts` — the contract `@archon/workflows` requires from `@archon/core`:

| Group | Methods |
|---|---|
| Run lifecycle | `createWorkflowRun`, `getWorkflowRun`, `findResumableRun`, `failOrphanedRuns`, `resumeWorkflowRun`, `updateWorkflowActivity`, `getWorkflowRunStatus`, `completeWorkflowRun`, `failWorkflowRun`, `pauseWorkflowRun`, `cancelWorkflowRun` |
| Events | `createWorkflowEvent`, `getCompletedDagNodeOutputs` |
| Codebase context | `getCodebaseEnvVars`, `getCodebase` |

`WORKFLOW_EVENT_TYPES` (exported from the same file) is the canonical list of `event_type` values stored in `remote_agent_workflow_events`.
