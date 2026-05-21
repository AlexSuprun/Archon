---
project_name: 'Archon (Remote Agentic Coding Platform)'
user_name: 'Alex Suprun'
date: '2026-05-21'
sections_completed:
  - technology_stack
  - language_rules
  - framework_rules
  - testing_rules
  - code_quality
  - workflow_rules
  - package_boundaries
  - anti_patterns
status: 'complete'
rule_count: 70
optimized_for_llm: true
existing_patterns_found: 8
---

# Project Context for AI Agents

_Complement to CLAUDE.md. Captures tactical, easy-to-miss rules. Do not duplicate CLAUDE.md content unless restated here for emphasis. Read CLAUDE.md first._

---

## Technology Stack & Versions

- Bun ^1.3 (runtime + bundler + test runner; replaces Node — `@types/node` is for type compat only)
- TypeScript ^5.3 (strict mode enforced repo-wide)
- Hono + `@hono/zod-openapi` (server). Import `z` from `@hono/zod-openapi`, never from `zod`
- Zod (validation) — schemas only via `@hono/zod-openapi` re-export
- React + Vite + Tailwind v4 + shadcn/ui + Zustand (`@archon/web`)
- AI SDKs: `@anthropic-ai/claude-agent-sdk`, `@openai/codex-sdk`, `@mariozechner/pi-coding-agent`
- Pino (logging via `@archon/paths` `createLogger`)
- ESLint 9 + Prettier 3 (CI: `--max-warnings 0`)
- DB: SQLite default (`~/.archon/archon.db`); PostgreSQL when `DATABASE_URL` set
- Package version source of truth: root `package.json` `version` field only
- Lockfile: `bun.lock` — never edit `package-lock.json` or `yarn.lock`

## Critical Implementation Rules

### Language-Specific Rules (TypeScript)

- Strict TS. No `any` without inline justification comment naming the SDK or post-validation reason
- Use `import type` for type-only imports
- Use specific named imports for values; never `import * as` for `@archon/core` (allowed only for submodules like `@archon/core/db/conversations`, `@archon/git`)
- Derive types with `z.infer<typeof schema>`. Never write parallel hand-crafted interfaces
- Import SDK types directly (`Options` from `@anthropic-ai/claude-agent-sdk`); never duplicate or cast to `as any`
- Schema naming: camelCase with descriptive suffix (`workflowRunSchema`, `errorSchema`)
- Engine schemas in `packages/workflows/src/schemas/<concern>.ts`; `index.ts` re-exports
- Route schemas in `packages/server/src/routes/schemas/<domain>.schemas.ts`
- Derive enums from schema `.options` — never duplicate as plain arrays. Exception: `@archon/web` must use a local constant (api.generated.d.ts is type-only)

### Framework-Specific Rules

- **Hono routes**: every new/modified route uses `registerOpenApiRoute(createRoute({...}), handler)`. Raw `app.get/.post` is forbidden for API routes
- **Webhooks**: use `c.req.text()` to get raw body for HMAC verification (GitHub: `X-Hub-Signature-256`). Return 200 immediately, process async
- **Adapters**: authorization happens INSIDE the adapter, not at handler boundary. Silent rejection for unauthorized; log masked user IDs
- **React (`@archon/web`)**: state in Zustand stores under `src/stores/`; SSE via `useSSE` hook
- **Pi provider** registered with `builtIn: false` (community). New community providers under `packages/providers/src/community/<id>/`
- **AI streaming**: `for await (const event of events) { await platform.send(event) }`. Never buffer full response
- **Provider/model resolution chain**: `node.provider ?? workflow.provider ?? config.assistant`. Model never picks provider. Provider id is validated at YAML load; model string is forwarded verbatim to the SDK
- **Workflow YAML**: variable substitution tokens — `$1`, `$ARGUMENTS`, `$ARTIFACTS_DIR`, `$WORKFLOW_ID`, `$BASE_BRANCH`, `$DOCS_DIR`, `$LOOP_USER_INPUT`, `$REJECTION_REASON`, `$LOOP_PREV_OUTPUT`, `$nodeId.output`

### Testing Rules

- Never run `bun test` from repo root — causes ~135 `mock.module()` pollution failures. Always `bun run test` (uses `bun --filter '*' --parallel test`)
- `mock.module()` is process-global and irreversible. `mock.restore()` does NOT undo it (bun#7823)
- Do NOT add `afterAll(() => mock.restore())` for `mock.module()` cleanup — no effect, misleading
- Use `spyOn()` for internal modules other tests import directly. `spy.mockRestore()` works for spies
- When adding a test file with `mock.module()`, ensure its `package.json` test script runs it in a SEPARATE `bun test` invocation from any conflicting file
- Existing splits: `@archon/core` 7 batches, `@archon/workflows` 5, `@archon/adapters` 3, `@archon/isolation` 3
- Tests co-located: `foo.ts` ↔ `foo.test.ts`
- Integration tests: use real SQLite ephemeral file or PG test database — do NOT mock the DB layer
- Tests must be deterministic. No flaky timing or network without guardrails

### Code Quality & Style Rules

- ESLint zero-warnings policy. `// eslint-disable-next-line` only for: (1) wrong SDK types — name the SDK in the comment, or (2) post-validation assertion — explain the validation
- Never bulk-disable at file level (`/* eslint-disable */`)
- Default: write no comments. Add comments ONLY when the WHY is non-obvious (hidden constraint, subtle invariant, bug workaround)
- Never explain WHAT — well-named identifiers do that. No multi-paragraph docstrings
- Never reference task/fix/caller in comments ("used by X", "added for Y") — belongs in PR description
- Token masking required: `token.slice(0, 8) + '...'`. Never log raw tokens, message content, or PII
- Logging event names: `{domain}.{action}_{state}` (e.g. `session.create_started`, `workflow.step_failed`). Pair `_started` with `_completed`/`_failed`
- Bundled defaults: after editing `.archon/workflows/defaults/` or `.archon/commands/defaults/`, run `bun run generate:bundled`. CI's `check:bundled` and `check:bundled-skill` fail loudly if stale

### Development Workflow Rules

- `main` is release branch — never commit directly. `dev` is the working branch. Feature branches off `dev`, merge back into `dev`
- Pre-PR: `bun run validate` (6 checks: check:bundled, check:bundled-skill, type-check, lint --max-warnings 0, format:check, test). All must pass
- PR template at `.github/PULL_REQUEST_TEMPLATE.md` — fill every section. When using `gh pr create`, pass body via HEREDOC; GitHub only auto-applies template through web UI
- Link issue with `Closes #<n>` / `Fixes` / `Resolves` in PR body
- Releases via `/release` skill (patch default, `/release minor`, `/release major`). Skill compares dev→main, generates CHANGELOG, bumps version, opens PR to main
- Frontend API types: server must be running, then `bun --filter @archon/web generate:types`. Output `api.generated.d.ts` is checked in
- Worktree self-testing: `bun dev &` auto-allocates port (3190-4089 hash of path); kill with `pkill -f "bun.*dev"`

### Package Boundary Rules

- `@archon/web` MUST NOT import from `@archon/workflows`. Use re-exports in `src/lib/api.ts` (derived from `api.generated.d.ts`)
- `@archon/workflows` dependencies: `@archon/git` + `@archon/paths` + `@archon/providers/types` + `@hono/zod-openapi` + `zod` only. No DB, no AI SDKs (injected via `WorkflowDeps`)
- `@archon/providers/types` is the SDK-free contract subpath. `@archon/workflows` imports from there, never from concrete provider modules
- `@archon/git` has NO `@archon/core` dependency
- `@archon/paths` has NO `@archon/*` deps (only `pino`, `dotenv`)
- `@archon/core` provides `createWorkflowStore()` adapter bridging core DB → `IWorkflowStore`
- Don't add unrelated methods to existing narrow interfaces (`IPlatformAdapter`, `IAgentProvider`, `IDatabase`, `IWorkflowStore`). Define a new interface instead

### Critical Don't-Miss Rules (Anti-Patterns)

- Never `git clean -fd` — permanently deletes untracked files. Use `git checkout .` instead
- Never `exec` with shell expansion for git. Use `execFileAsync` (or `@archon/git` functions)
- Never silently swallow errors in agent runtimes. Throw early with explicit error. Document any intentional fallback with a comment explaining why it is safe
- Never silently broaden permissions or capabilities
- **No autonomous lifecycle mutation across process boundaries**: if a process can't distinguish "running elsewhere" from "orphaned by crash", do NOT mark work failed/cancelled/abandoned via timer or staleness heuristic. Surface ambiguous state to the user with a one-click action. Reference: #1216
- Never edit `package-lock.json` / `yarn.lock` (repo uses `bun.lock`)
- Never skip hooks (`--no-verify`) or bypass signing unless explicitly requested
- DB `UPDATE`: rely on `updateConversation` throwing when no rows match; re-throw to surface missing records. Don't swallow `rowCount === 0`
- Git operation errors: use `classifyIsolationError()` from `@archon/isolation` to map to user-friendly messages. Always log raw error
- Don't add config keys, feature flags, or branches without a concrete current caller (YAGNI)
- Don't extract a utility until the same pattern appears at least 3 times and has stabilized
- Don't add backwards-compatibility shims when you can just change the code. No `// removed` comments. No renamed `_unused` vars
- Don't run `cli`/workflow commands outside a git repo — they resolve to repo root; will fail outside
- Adapter conversation IDs are platform-specific and load-bearing: Slack `thread_ts`, Telegram `chat_id`, GitHub `owner/repo#n`, Discord channel ID, Web string. Don't normalize across platforms
- `@archon` mention detection: parse in issue/PR **comments only**, not descriptions (descriptions contain example commands — see #96)
- Sessions are immutable: transitions create a new session linked by `parent_session_id` + `transition_reason`. Don't mutate session state in place

---

## Usage Guidelines

**For AI Agents:**

- Read this file AND CLAUDE.md before implementing
- When rules conflict, the more restrictive applies
- Update this file when new non-obvious patterns emerge

**For Humans:**

- Keep lean — complements CLAUDE.md, no duplication
- Update when tech stack or patterns change
- Prune obvious rules over time

Last Updated: 2026-05-21
