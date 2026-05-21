# Architecture — Documentation Site

`packages/docs-web` is the user-facing documentation site (`docs.archon.dev`-style). It is an **Astro 6 + Starlight** static site, separate from the React Web UI and from any runtime backend.

## Technology Stack

| Category | Tech |
|---|---|
| Framework | Astro 6 |
| Docs theme | `@astrojs/starlight` |
| Image processing | `sharp` |
| Content format | MDX (`.md` / `.mdx`) under `src/content/docs/` |

## Sections

```mermaid
flowchart LR
    root["docs/"] --> gs["getting-started/"]
    root --> guides["guides/"]
    root --> adapters["adapters/"]
    root --> deploy["deployment/"]
    root --> ref["reference/"]
    root --> book["book/"]
    root --> contrib["contributing/"]
    gs --> gs1["overview, quick-start, installation,<br/>configuration, concepts, ai-assistants"]
    guides --> g1["authoring-workflows, authoring-commands,<br/>approval/loop/script nodes, hooks, skills, mcp-servers,<br/>global-workflows, remotion-workflow"]
    adapters --> a1["slack, telegram, github, web (+ index)"]
    deploy --> d1["local, docker, cloud, windows,<br/>e2e-testing (+ wsl variant)"]
    ref --> r1["architecture, api, cli"]
    book --> b1["what-is-archon, first-five-minutes,<br/>first-command, first-workflow, how-it-works,<br/>dag-workflows, isolation, hooks-and-quality,<br/>essential-workflows, quick-reference"]
    contrib --> c1["new-developer-guide, cli-internals,<br/>adding-a-community-provider, releasing,<br/>dx-quirks"]
```

## Build and Serve

- Dev: `bun run dev:docs`
- Build: `bun run build:docs` → `packages/docs-web/dist/`
- CI deployment: `.github/workflows/deploy-docs.yml`

## Generated Endpoints

- `packages/docs-web/src/pages/workflows.json.ts` — emits a JSON catalog of workflow templates for an in-docs marketplace UI. Data lives in `src/data/marketplace.ts`.
- `src/data/roadmap.ts` — roadmap copy consumed by an index/roadmap page.

## Content Configuration

`src/content.config.ts` defines the Starlight collection. Frontmatter conventions are standard Starlight (`title`, `description`, optional `sidebar.order`).

## Editorial Conventions

- Each section has an `index.md` landing page that lists its children.
- The "Book" section (`book/`) is the curated narrative onboarding path; the other sections are reference-shaped.
- Code samples use language-tagged fenced blocks; no live execution.

## Relation to the Other Parts

The docs site does **not** import from any other workspace. It is deployed independently. When backend or CLI behavior changes, the affected MDX page lives in this part — the maintainer-review workflow described in `CLAUDE.md` skips `CHANGELOG.md` but does scan docs (#1724).
