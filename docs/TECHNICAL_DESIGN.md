# Technical Design — AI-Assisted SDLC

**Project codename:** AI-SDLC
**Version:** 2.0 (shared/ canonical architecture)
**Companion:** `FUNCTIONAL_DESIGN.md`

---

## Table of contents

1. [Overview](#1-overview)
2. [Repository layout](#2-repository-layout)
3. [PROFILE.md — the config backbone](#3-profilemd--the-config-backbone)
4. [Shared skills](#4-shared-skills)
5. [Agent architecture](#5-agent-architecture)
6. [Scripts and config-driven execution](#6-scripts-and-config-driven-execution)
7. [Hook system](#7-hook-system)
8. [Pipeline stages — end to end](#8-pipeline-stages--end-to-end)
9. [Windows developer setup](#9-windows-developer-setup)
10. [Bootstrap deep dive](#10-bootstrap-deep-dive)
11. [Adding a new skill](#11-adding-a-new-skill)
12. [Extending notifications or repo integrations](#12-extending-notifications-or-repo-integrations)
13. [Permissions model](#13-permissions-model)
14. [Observability](#14-observability)
15. [Cost model](#15-cost-model)
16. [Security considerations](#16-security-considerations)
17. [Troubleshooting](#17-troubleshooting)

---

## 1. Overview

AI-SDLC is a pipeline that turns Azure DevOps work items into implemented, reviewed pull requests with minimal human intervention. Work items tagged `ai:ready` flow through design generation, parallel subagent implementation, and multi-dimensional PR review — all driven by Claude Code (local) or GitHub Copilot (CI).

The key architectural principle is **a single canonical source for all AI behaviour**, shared by both tools. Skills, agent definitions, scripts, and project config all live in `shared/`. Both `.claude/` (Claude Code) and `.github/` (GitHub Copilot) contain only thin wrappers — a few lines of tool-specific frontmatter that point back to `shared/`.

```
                         ┌──────────────────────────────┐
                         │        AZURE DEVOPS           │
                         │  Work Item tagged ai:ready    │
                         │           │                   │
                         │           ▼                   │
                         │  ado-poller.yml (hourly)      │
                         │   dispatches repository_      │
                         │   dispatch event              │
                         └──────────────┬────────────────┘
                                        │
                    ┌───────────────────▼─────────────────────┐
                    │          shared/  (canonical)            │
                    │                                          │
                    │  skills/     agents/     scripts/        │
                    │  (10)        (6)         (9)             │
                    │                                          │
                    │  project/                                │
                    │    PROFILE.md   ◄── single config        │
                    │    CLAUDE.md        backbone             │
                    │    guidelines/                           │
                    │    overrides/                            │
                    │    stacks/                               │
                    └──────┬────────────────┬─────────────────┘
                           │                │
              ┌────────────▼──┐        ┌────▼──────────────────┐
              │  .claude/     │        │  .github/              │
              │               │        │                        │
              │  CLAUDE.md    │        │  copilot-             │
              │  settings.json│        │  instructions.md      │
              │  mcp.json     │        │  hooks/               │
              │               │        │   hooks.json          │
              │  hooks/       │        │   normalize-*.sh      │
              │  (4 scripts)  │        │   block-sensitive.sh  │
              │               │        │   scope-enforce.sh    │
              │  agents/      │        │  agents/              │
              │  (thin        │        │  (thin wrappers       │
              │   wrappers)   │        │   w/ Copilot          │
              │               │        │   frontmatter)        │
              └───────────────┘        │                        │
              Claude Code              │  workflows/ (5)        │
              (local / headless)       │  instructions/ (4)     │
                                       └────────────────────────┘
                                       GitHub Copilot
                                       (CI / local)
```

---

## 2. Repository layout

```
<repo-root>/
│
├── shared/                                  ← CANONICAL SOURCE — both tools read this
│   ├── skills/                              ← 10 SKILL.md files (single source)
│   │   ├── bootstrap-project/SKILL.md
│   │   ├── requirements-analysis/SKILL.md
│   │   ├── technical-slicing/SKILL.md
│   │   ├── implement-story/SKILL.md         ← orchestrator
│   │   ├── implement-slice/SKILL.md         ← single-slice fallback
│   │   ├── pr-review/SKILL.md
│   │   ├── security-review/SKILL.md
│   │   ├── tech-debt-review/SKILL.md
│   │   ├── update-functional/SKILL.md
│   │   └── verify-story/
│   │       ├── SKILL.md
│   │       └── report-template.md
│   │
│   ├── agents/                              ← 6 full agent definitions
│   │   ├── backend-dev.md
│   │   ├── frontend-dev.md
│   │   ├── contract-dev.md
│   │   ├── code-reviewer.md
│   │   ├── security-auditor.md
│   │   ├── tech-debt-auditor.md
│   │   └── scope-map.json                  ← authoritative scope boundaries
│   │
│   ├── scripts/                             ← 9 CLI wrapper scripts
│   │   ├── ado-wi-show.sh
│   │   ├── ado-wi-update.sh
│   │   ├── ado-wi-create-slice.sh
│   │   ├── ado-pr-comment.sh
│   │   ├── check-compile.sh                ← reads PROFILE.md gates.compile
│   │   ├── check-startup.sh                ← reads PROFILE.md gates.startup
│   │   ├── check-tech-agnostic.sh
│   │   ├── notify.sh                       ← config-driven: Slack | Teams | webhook
│   │   └── create-pr.sh                    ← config-driven: GitHub | Azure Repos
│   │
│   └── project/                            ← PROJECT-OWNED configuration layer
│       ├── PROFILE.md                      ← activated by renaming from PROFILE.draft.md
│       ├── PROFILE.draft.md                ← bootstrap writes here; human confirms
│       ├── CLAUDE.md                       ← project policy (overrides global policy)
│       ├── guidelines/
│       │   ├── coding-standards.md
│       │   ├── error-handling.md
│       │   ├── api-contracts.md
│       │   └── naming.md
│       ├── overrides/
│       │   ├── .gitkeep
│       │   └── verify-story.md             ← example per-skill override
│       └── stacks/                         ← per-stack files (populated on demand)
│           └── <stack>.md
│
├── .claude/                                ← Claude Code configuration
│   ├── CLAUDE.md                           ← global policy → references shared/project/
│   ├── settings.json                       ← hook registrations (PreToolUse/PostToolUse)
│   ├── mcp.json                            ← MCP server config
│   ├── settings.local.json                 ← local overrides (gitignored)
│   ├── hooks/                              ← hook scripts for Claude Code
│   │   ├── block-sensitive-files.sh        ← PreToolUse: blocks secrets/pipelines/skills
│   │   ├── scope-enforce.sh                ← PreToolUse: enforces per-subagent boundaries
│   │   ├── format-after-edit.sh            ← PostToolUse: runs project formatter
│   │   └── trace-decisions.sh              ← PostToolUse: append-only audit log
│   ├── agents/                             ← thin wrappers (Claude frontmatter only)
│   │   ├── backend-dev.md
│   │   ├── frontend-dev.md
│   │   ├── contract-dev.md
│   │   ├── code-reviewer.md
│   │   ├── security-auditor.md
│   │   ├── tech-debt-auditor.md
│   │   └── scope-map.json                  ← symlink or copy of shared/agents/scope-map.json
│   └── trace/                              ← runtime audit logs (gitignored in CI)
│       └── <run-id>.jsonl
│
├── .github/                                ← GitHub Copilot configuration
│   ├── copilot-instructions.md             ← global Copilot policy → references shared/project/
│   ├── hooks/                              ← hook scripts + normalize shims
│   │   ├── hooks.json                      ← Copilot hook config
│   │   ├── normalize-input.sh              ← converts Copilot JSON format → Claude format
│   │   ├── normalize-and-block-sensitive.sh
│   │   ├── normalize-and-scope-enforce.sh
│   │   ├── normalize-and-format.sh
│   │   ├── normalize-and-trace.sh
│   │   ├── block-sensitive-files.sh        ← same logic as .claude/hooks version
│   │   ├── scope-enforce.sh                ← same logic as .claude/hooks version
│   │   ├── format-after-edit.sh
│   │   └── trace-decisions.sh
│   ├── agents/                             ← thin wrappers (Copilot frontmatter only)
│   │   ├── backend-dev.agent.md
│   │   ├── frontend-dev.agent.md
│   │   ├── contract-dev.agent.md
│   │   ├── code-reviewer.agent.md
│   │   ├── security-auditor.agent.md
│   │   ├── tech-debt-auditor.agent.md
│   │   └── scope-map.json
│   ├── instructions/                       ← per-file-type Copilot instructions
│   │   ├── api-contracts.instructions.md
│   │   ├── coding-standards.instructions.md
│   │   ├── error-handling.instructions.md
│   │   └── naming.instructions.md
│   └── workflows/                          ← 5 GitHub Actions workflows (protected)
│       ├── ado-poller.yml                  ← hourly: polls ADO for ai:ready items
│       ├── design-gen.yml                  ← requirements-analysis skill
│       ├── implement-story.yml             ← parallel subagent implementation
│       ├── pr-review.yml                   ← 3-way parallel PR review
│       └── post-merge.yml                  ← closes ADO items, notifies Slack
│
├── .azure-pipelines/                       ← Azure Pipelines YAML (protected, human-authored)
│   ├── design-gen.yml
│   ├── implement-story.yml
│   ├── pr-review.yml
│   └── post-merge.yml
│
└── docs/
    ├── FUNCTIONAL_DESIGN.md
    ├── TECHNICAL_DESIGN.md                 ← this file
    └── designs/
        └── WI-<id>/
            ├── functional.md
            ├── technical.md
            ├── slices.md
            ├── verification.md             ← written by verify-story subagent
            └── screenshots/               ← browser verification screenshots
```

---

## 3. PROFILE.md — the config backbone

`shared/project/PROFILE.md` is the single configuration file that controls how every skill and script behaves. It is created by `/bootstrap-project` as `PROFILE.draft.md` and activated by renaming it to `PROFILE.md`. Until `PROFILE.md` exists, all AI-SDLC skills abort with the message: `PROFILE.md not found. Run /bootstrap-project first.`

### 3.1 Complete annotated example

The following is a fully filled-in example for a GitHub Actions + GitHub + Slack team:

```yaml
project:
  name: my-product
  type: fullstack-monorepo      # frontend | backend | fullstack | infra | fullstack-monorepo
  repo_kind: monorepo           # single | monorepo

# ── Orchestration ─────────────────────────────────────────────────────────────
# Controls which pipeline tool, repo host, and notification system the scripts use.
orchestration:
  pipeline_tool: github-actions          # github-actions | azure-pipelines
  repo_host: github                      # github | azure-repos
  work_items:
    source: ado                          # ado is the only supported work-item source
    org_url: https://dev.azure.com/acme
    project: MyProduct
  notifications:
    type: slack                          # slack | teams | webhook
    webhook_url: https://hooks.slack.com/services/T000/B000/xxxx
    channel: "#engineering"              # Slack only; omit for teams/webhook

# ── Stacks ────────────────────────────────────────────────────────────────────
stacks:
  frontend:
    framework: react                     # source: apps/web/package.json:12
    meta_framework: next                 # source: apps/web/package.json:13
    language: typescript                 # source: apps/web/tsconfig.json:1
    styling: tailwind                    # source: apps/web/tailwind.config.ts:1
    test: vitest                         # source: apps/web/vitest.config.ts:1
  backend:
    framework: dotnet                    # source: apps/api/Api.csproj:3
    language: csharp                     # source: apps/api/Api.csproj:3
    orm: ef-core                         # source: apps/api/Api.csproj:18
    test: xunit                          # source: tests/Api.Tests/Api.Tests.csproj:7
  contract:
    format: openapi
    path: contracts/openapi.yaml
  infra:
    ci: github-actions                   # source: .github/workflows/ directory present
    iac: bicep                           # source: infra/*.bicep files
    container: docker                    # source: Dockerfile at repo root

conventions_detected:
  - "Monorepo with pnpm workspaces"      # source: pnpm-workspace.yaml:1
  - "API follows CQRS pattern"           # source: apps/api/Commands/, apps/api/Queries/

recommended_skills:
  always:
    - requirements-analysis
    - technical-slicing
    - implement-story
    - implement-slice
    - pr-review
    - security-review
    - tech-debt-review
  stack_specific:
    - react-patterns
    - dotnet-patterns
  not_applicable: []

# Commands the hooks and pipelines run.
gates:
  pre_commit: "pnpm lint && pnpm test --run"
  pre_merge:  "pnpm build && dotnet test"
  unit_test:  "pnpm test --run"
  integration_test: "pnpm test:integration"
  format:     "pnpm prettier --write"

  compile:
    frontend: "pnpm build"
    backend:  "dotnet build"

  startup:
    frontend: "pnpm dev"
    backend:  "dotnet run --project apps/api"

  healthcheck:
    frontend: "curl -sf http://localhost:3000 > /dev/null"
    backend:  "curl -sf http://localhost:5000/health > /dev/null"

  startup_wait_seconds: 15
  skip_browser_verification: false

quarantined_paths: []     # add paths AI must never auto-edit
reviewers: []             # ADO reviewer login names for auto-assignment
```

### 3.2 Field reference

| Field | Type | Required | Description |
|---|---|---|---|
| `project.name` | string | yes | Human-readable project name |
| `project.type` | enum | yes | One of: `frontend`, `backend`, `fullstack`, `infra`, `fullstack-monorepo` |
| `project.repo_kind` | enum | yes | `single` or `monorepo` |
| `orchestration.pipeline_tool` | enum | yes | `github-actions` or `azure-pipelines` |
| `orchestration.repo_host` | enum | yes | `github` or `azure-repos` — drives `create-pr.sh` |
| `orchestration.work_items.source` | enum | yes | Always `ado` in current release |
| `orchestration.work_items.org_url` | URL | yes | ADO organization URL |
| `orchestration.work_items.project` | string | yes | ADO project name |
| `orchestration.notifications.type` | enum | yes | `slack`, `teams`, or `webhook` — drives `notify.sh` |
| `orchestration.notifications.webhook_url` | URL | yes | Incoming webhook URL |
| `orchestration.notifications.channel` | string | Slack only | Target channel, e.g. `#engineering` |
| `stacks.*` | object | recommended | Detected stack; each field carries a `# source:` comment |
| `gates.pre_commit` | shell command | recommended | Runs before commits during implementation |
| `gates.pre_merge` | shell command | recommended | Runs before feature PR is opened |
| `gates.compile.frontend` | shell command | optional | `check-compile.sh` runs this; `n/a` to skip |
| `gates.compile.backend` | shell command | optional | `check-compile.sh` runs this; `n/a` to skip |
| `gates.startup.frontend` | shell command | optional | `check-startup.sh` starts the frontend process |
| `gates.startup.backend` | shell command | optional | `check-startup.sh` starts the backend process |
| `gates.healthcheck.frontend` | shell command | optional | HTTP check after startup wait |
| `gates.healthcheck.backend` | shell command | optional | HTTP check after startup wait |
| `gates.startup_wait_seconds` | int | optional | Default 15; seconds to wait after starting app |
| `gates.skip_browser_verification` | bool | optional | Default false; set true to skip verify-story |
| `quarantined_paths` | string[] | optional | Paths AI must never touch; enforced by scope-enforce |
| `reviewers` | string[] | optional | ADO login names auto-added as PR reviewers |

---

## 4. Shared skills

### 4.1 Discovery and path convention

Skills live at `shared/skills/<name>/SKILL.md`. Both Claude Code and GitHub Copilot load them:

- **Claude Code:** The global `.claude/CLAUDE.md` references skills by name. Claude Code resolves `shared/skills/<name>/SKILL.md` when a skill is invoked. There are no per-skill wrapper files in `.claude/skills/` — both tools discover directly from `shared/`.
- **GitHub Copilot:** The `copilot-instructions.md` defines the same load order. Copilot reads skill files from `shared/skills/<name>/SKILL.md` when invoked by name.

### 4.2 Load order — mandatory

Every skill and agent, before generating its primary artifact, loads context files in this exact order:

1. `shared/project/PROFILE.md` — **required**; abort if absent with the message `Run /bootstrap-project first.`
2. `shared/project/CLAUDE.md` — project policy (optional; continue if missing)
3. `shared/project/overrides/<this-skill-name>.md` — skill-specific override (optional)
4. All files in `shared/project/guidelines/` — coding standards, error handling, naming, API contracts
5. Stack files in `shared/project/stacks/` matching the detected frameworks in PROFILE

If `PROFILE.md` is missing, execution stops. All other files are optional — missing files are expected on new projects and cause no error.

### 4.3 Skill inventory

| Skill | Trigger | Primary output |
|---|---|---|
| `bootstrap-project` | Human: `/bootstrap-project` | `shared/project/PROFILE.draft.md` + scaffolded guideline stubs |
| `requirements-analysis` | Pipeline: `/requirements-analysis <id>` | `docs/designs/WI-<id>/functional.md`, `technical.md`, `slices.md` |
| `technical-slicing` | Chained from `requirements-analysis` | `slices.md` with YAML schema; ADO child Task work items |
| `implement-story` | Pipeline: `/implement-story <id>` | Feature PR on `story/WI-<id>`; delegates to subagents |
| `implement-slice` | Single-slice fallback or manual | Commit on assigned sub-branch |
| `pr-review` | Pipeline: subagent per job | PR comments with severity tags; no writes to code |
| `security-review` | Pipeline: subagent per job | Security-focused PR comments |
| `tech-debt-review` | Pipeline: subagent per job | Tech-debt-focused PR comments |
| `update-functional` | Manual: `/update-functional <id>` | Updates `functional.md` to reflect post-implementation reality |
| `verify-story` | Spawned by `implement-story` | `docs/designs/WI-<id>/verification.md`; browser AC verification |

### 4.4 Tech-agnostic functional doc rule

`functional.md` must not contain framework, protocol, or cloud-service names. `check-tech-agnostic.sh` enforces a grep blocklist against the file and exits non-zero on any match. The blocked terms include: `OAuth`, `JWT`, `REST`, `GraphQL`, `gRPC`, `PostgreSQL`, `MySQL`, `Redis`, `MongoDB`, `React`, `Angular`, `Vue`, `Next`, `Svelte`, `Kubernetes`, `Docker`, `AWS`, `Lambda`, `S3`, `Cosmos`, `RabbitMQ`, `Kafka`, `Azure` (as cloud service name). These terms are permitted in `technical.md`.

---

## 5. Agent architecture

### 5.1 Two-layer design

Every agent has two components:

**Layer 1 — Thin wrapper** (tool-specific, in `.claude/agents/` or `.github/agents/`):
Contains only the tool's required frontmatter (name, description, tools list) and a single `See shared/agents/<name>.md` reference. No procedure. No logic.

**Layer 2 — Full definition** (shared, in `shared/agents/<name>.md`):
Contains the complete procedure, scope declaration, output contract, and blocker rules. One file, referenced by both tools.

### 5.2 Frontmatter differences

**Claude Code wrapper** (`.claude/agents/backend-dev.md`):
```yaml
---
name: backend-dev
description: Implement backend slices — server code, data layer, business logic, and their
  tests. Operates only within backend paths. Used by the implement-story orchestrator.
tools: [Read, Write, Edit, Glob, Grep, Bash(git:*), Bash(dotnet:*), Bash(npm:*),
  Bash(pnpm:*), Bash(npx:*), Bash(python:*), Bash(go:*), Bash(mvn:*), Bash(gradle:*),
  Bash(jq:*), Bash(yq:*), Bash(shared/scripts/*)]
context: fork
---

See `shared/agents/backend-dev.md` for the full procedure, scope, and output contract.
```

**Copilot wrapper** (`.github/agents/backend-dev.agent.md`):
```yaml
---
name: backend-dev
description: Implement backend slices — server code, data layer, business logic, and their
  tests. Operates only within backend paths. Triggers on "backend", "api", "server",
  "service layer", "data access", "migration".
tools: ["read", "edit", "search", "execute"]
---

See `shared/agents/backend-dev.md` for the full procedure, scope, and output contract.
```

The key differences: Claude Code uses `context: fork` and a specific `Bash(command:*)` whitelist; Copilot uses generic tool names and relies on its own permission system.

### 5.3 scope-map.json

`shared/agents/scope-map.json` (also present as `.claude/agents/scope-map.json` and `.github/agents/scope-map.json`) defines per-subagent file boundaries. The `scope-enforce.sh` hook reads this file at runtime. Precedence: `denied` wins over `read_only` wins over `read_write`.

```json
{
  "contract-dev": {
    "read_write": ["contracts/**"],
    "read_only": ["docs/designs/**", "shared/project/**", "apps/**/openapi*", "apps/**/*.graphql"],
    "denied": ["apps/api/**", "apps/web/**", ".azure-pipelines/**", ".github/workflows/**",
               "shared/skills/**", "*.env", "*.pem", "*.key"]
  },
  "backend-dev": {
    "read_write": ["apps/api/**", "tests/api/**", "apps/server/**", "tests/server/**"],
    "read_only": ["contracts/**", "shared/project/**", "docs/designs/**", "apps/shared/**"],
    "denied": ["apps/web/**", "apps/client/**", ".azure-pipelines/**", ".github/workflows/**",
               "shared/skills/**", "*.env", "*.pem", "*.key"]
  },
  "frontend-dev": {
    "read_write": ["apps/web/**", "tests/web/**", "apps/client/**", "tests/client/**"],
    "read_only": ["contracts/**", "shared/project/**", "docs/designs/**", "apps/shared/**"],
    "denied": ["apps/api/**", "apps/server/**", ".azure-pipelines/**", ".github/workflows/**",
               "shared/skills/**", "*.env", "*.pem", "*.key"]
  },
  "code-reviewer": { "read_write": [], "read_only": ["**"], "denied": ["*.env","*.pem","*.key"] },
  "security-auditor": { "read_write": [], "read_only": ["**"], "denied": [] },
  "tech-debt-auditor": { "read_write": [], "read_only": ["**"], "denied": ["*.env","*.pem","*.key"] },
  "verify-story": {
    "read_write": ["docs/designs/WI-*/verification.md", "docs/designs/WI-*/screenshots/**"],
    "read_only": ["**"],
    "denied": ["*.env","*.pem","*.key","shared/skills/**",".azure-pipelines/**",".github/workflows/**"]
  }
}
```

A merge conflict between backend and frontend sub-branches always indicates a scope violation, because their `read_write` paths are declared disjoint.

### 5.4 Subagent return contract

Every subagent ends its run with a JSON block the orchestrator parses:

```json
{
  "subagent": "backend-dev",
  "slices_implemented": ["S2", "S4"],
  "branch": "story/WI-1234/backend",
  "commit_sha": "abc123",
  "tests": { "unit": "passed", "integration": "passed" },
  "files_touched": ["apps/api/Handlers/CreateOrderHandler.cs"],
  "blockers": [],
  "questions": []
}
```

If `blockers` or `questions` is non-empty, the orchestrator does not merge — it opens a draft PR with the blockers surfaced at the top and comments on the parent ADO work item.

---

## 6. Scripts and config-driven execution

All scripts in `shared/scripts/` are idempotent where possible, exit non-zero on failure, and log to stderr. Scripts may be called by skills, by workflows, or directly by developers.

### 6.1 Script inventory

| Script | Purpose |
|---|---|
| `ado-wi-show.sh <id>` | Print ADO work item JSON: `az boards work-item show --id <id>` |
| `ado-wi-update.sh <id> --state <s> --discussion <text>` | Update work item state and append discussion comment |
| `ado-wi-create-slice.sh <parent-id> <slice-yaml>` | Create a child Task work item from a slice YAML file |
| `ado-pr-comment.sh <pr-id> <thread-status> <comment-file>` | Post a comment thread on an ADO PR |
| `check-compile.sh [frontend\|backend\|both]` | Reads `gates.compile.<layer>` from PROFILE.md and runs it |
| `check-startup.sh [frontend\|backend\|both]` | Starts app, waits `startup_wait_seconds`, runs healthcheck, kills |
| `check-tech-agnostic.sh <file>` | Grep blocklist against a file; exits non-zero on any forbidden term |
| `notify.sh <message>` | Config-driven notification (see below) |
| `create-pr.sh --title <t> --body <b> --branch <br> [--base <base>]` | Config-driven PR creation (see below) |

### 6.2 notify.sh — branching logic

`notify.sh` reads `orchestration.notifications.type` and `orchestration.notifications.webhook_url` from `shared/project/PROFILE.md` using `yq`. If PROFILE.md is absent or the notification fields contain `[NEEDS HUMAN INPUT]`, the script exits 0 silently — a missing notification config is never a pipeline failure.

When configured:
- **`type: slack`** — constructs a JSON payload `{text, channel}` (channel included if the `channel` field is set). Posts to the webhook URL with `curl`. A Slack incoming webhook ignores the `channel` field if the app has a fixed channel.
- **`type: teams`** — constructs a MessageCard payload `{"@type":"MessageCard","text":"..."}`. Posts to the Power Automate / Teams webhook URL.
- **`type: webhook`** — constructs a minimal `{text, timestamp}` JSON payload. Posts to any generic HTTP endpoint.

All three variants use `curl -sS -X POST -H 'Content-type: application/json'` and write nothing to stdout on success; the caller sees a one-line confirmation message on stdout.

### 6.3 create-pr.sh — branching logic

`create-pr.sh` reads `orchestration.repo_host` from PROFILE.md using `yq`. If PROFILE.md is absent, it defaults to `github`. The `--body` argument can be either literal text or `@path/to/file` (the `@` prefix triggers a file read).

- **`repo_host: github`** — calls `gh pr create --title ... --body ... --head ... --base ...`. Requires `gh` CLI authenticated (via `GH_TOKEN` env var in CI, or `gh auth login` locally).
- **`repo_host: azure-repos`** — calls `az repos pr create --title ... --description ... --source-branch ... --target-branch ...`. Requires `az` CLI with the `azure-devops` extension and an active `az devops login` session.

---

## 7. Hook system

Hooks run before and after every tool call to enforce guardrails. The two tools have different hook mechanisms, but share the same underlying logic via the `shared/` scripts.

### 7.1 Claude Code hooks (settings.json)

`.claude/settings.json` registers hooks using Claude Code's `PreToolUse` / `PostToolUse` event model:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/block-sensitive-files.sh" },
          { "type": "command", "command": ".claude/hooks/scope-enforce.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{ "type": "command", "command": ".claude/hooks/format-after-edit.sh" }]
      },
      {
        "matcher": ".*",
        "hooks": [{ "type": "command", "command": ".claude/hooks/trace-decisions.sh" }]
      }
    ]
  }
}
```

Each hook receives the full tool-call payload as JSON on stdin. To **allow** the tool call, exit 0. To **block** it, exit 2 — Claude Code surfaces the stderr output to the model as the reason for the block.

### 7.2 Copilot hooks (hooks.json)

`.github/hooks/hooks.json` registers hooks using Copilot's hook mechanism:

```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      { "type": "command", "bash": ".github/hooks/normalize-and-block-sensitive.sh", "timeoutSec": 10 },
      { "type": "command", "bash": ".github/hooks/normalize-and-scope-enforce.sh", "timeoutSec": 10 }
    ],
    "postToolUse": [
      { "type": "command", "bash": ".github/hooks/normalize-and-format.sh", "timeoutSec": 30 },
      { "type": "command", "bash": ".github/hooks/normalize-and-trace.sh", "timeoutSec": 5 }
    ]
  }
}
```

Copilot hook scripts cannot use exit 2 to signal a block. Instead, they write a JSON denial to stdout:

```json
{"permissionDecision": "deny", "permissionDecisionReason": "BLOCKED: file.env is a secret file."}
```

### 7.3 The normalize shims

Copilot sends tool-call JSON in a different shape than Claude Code:

| Field | Claude Code | Copilot |
|---|---|---|
| Tool name key | `tool_name` | `toolName` |
| Tool arguments key | `tool_input` (object) | `toolArgs` (JSON string) |
| File path key | `tool_input.file_path` | `toolArgs.path` or `toolArgs.filePath` |
| Result key | `tool_response` | `toolResult` |
| Tool name casing | PascalCase (`Edit`) | lowercase (`edit`) |

Each `normalize-and-*.sh` script pipes stdin through `normalize-input.sh` first, which detects the Copilot format (presence of `toolName` without `tool_name`) and converts it to the Claude Code shape. The downstream `block-sensitive-files.sh` and `scope-enforce.sh` scripts then operate on the normalized payload exactly as they do in the Claude Code path.

After normalization, exit code 2 from the shared hook script is caught and translated to the Copilot JSON denial format.

### 7.4 What each hook does

**block-sensitive-files.sh** (PreToolUse, Edit|Write events):

Blocks writes to:
- Secrets: `*.env`, `*.env.*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*secret*`, `*secrets*`, `*credentials*`, `*.pgpass`, `*id_rsa*`, `*id_ed25519*`
- Pipeline configs: `.azure-pipelines/*`, `.github/workflows/*`, `.gitlab-ci.yml`, `Jenkinsfile`, `azure-pipelines.yml`
- Master skills: `shared/skills/**`, `.claude/skills/**`, `.claude/CLAUDE.md`, `.claude/settings.json`, `.claude/mcp.json`
- Scope maps: `.claude/agents/scope-map.json`, `shared/agents/scope-map.json`

The message on block: `"BLOCKED by block-sensitive-files: <file>. If this is intentional, a human must author the change."`

**scope-enforce.sh** (PreToolUse, Edit|Write events):

Reads the calling subagent's name from `payload.subagent_type` (or `.subagent`). If the payload has no subagent context (main agent), this hook is a no-op. Otherwise, loads the subagent's scope from `scope-map.json` and evaluates the target file path against `denied`, `read_only`, and `read_write` globs (in that precedence order). Blocks are logged to `.claude/trace/scope-blocks.jsonl`.

**format-after-edit.sh** (PostToolUse, Edit|Write events):

Runs the project formatter on the edited file. The formatter is inferred from file extension: `.ts/.tsx/.js/.jsx/.json/.md/.yml/.yaml` → prettier via `pnpm` or `npx`; `.cs` → `dotnet format`; `.py` → `ruff format` or `black`; `.go` → `gofmt`. Never fails the turn — formatter errors are logged to `.claude/trace/format-failures.jsonl` and execution continues.

**trace-decisions.sh** (PostToolUse, all tools):

Appends one JSON line per tool call to `.claude/trace/<run-id>.jsonl`. The run ID comes from `$CLAUDE_RUN_ID` (set by CI workflows), then `$BUILD_BUILDID` (Azure Pipelines), then falls back to `local-<date>-<pid>`. The line contains: timestamp, run_id, subagent name, tool name, file path, command (truncated to 200 chars), and success status.

---

## 8. Pipeline stages — end to end

The system has five pipeline stages. GitHub Actions workflows are the reference implementation; `.azure-pipelines/` contains the same logic for Azure Pipelines.

### 8.1 Stage 0 — ADO polling (ado-poller.yml)

Runs every hour via cron. Queries ADO with WIQL for work items tagged `ai:ready` but not `ai:processing`, in non-terminal states. For each match:

1. Fires a `repository_dispatch` event (`ado-workitem-ai-ready`) with the work item ID in the payload.
2. Tags the work item with `ai:processing` to prevent re-dispatch on the next poll.

Slack notification on empty queue: `"No work items tagged ai:ready pending."`. Slack notification on dispatched items: `"Dispatched WI-X, WI-Y for requirement analysis."`.

### 8.2 Stage 1 — Design generation (design-gen.yml)

Triggered by `repository_dispatch` from the poller, or manually via `workflow_dispatch`.

```
1. Resolve work item ID (from dispatch payload or manual input)
2. Install jq, yq, az devops extension
3. az devops login with ADO_PAT
4. chmod +x all hook and script files
5. npm install -g @github/copilot
6. Run Copilot with /requirements-analysis <id>
7. Archive .github/trace/ as artifact (90-day retention)
```

The skill procedure:
- Reads the ADO work item via `shared/scripts/ado-wi-show.sh`
- Loads the project layer (PROFILE → CLAUDE.md → overrides → guidelines → stacks)
- Generates `docs/designs/WI-<id>/functional.md`, `technical.md`, and `slices.md`
- Runs `check-tech-agnostic.sh` on `functional.md`
- Creates ADO child Task work items for each slice via `ado-wi-create-slice.sh`
- Commits design docs, pushes, opens a design PR via `create-pr.sh`
- Notifies Slack via `notify.sh`

### 8.3 Stage 2 — Story implementation (implement-story.yml)

Triggered on push to `master` where `docs/designs/WI-*/**` paths changed, or manually.

The workflow has five jobs:

| Job | Depends on | What it does |
|---|---|---|
| `derive-wi` | — | Extracts WI number from merge commit message or manual input |
| `contract` | `derive-wi` | Runs `contract-dev` if slices.md contains `layer: contract` slices; creates `story/WI-<id>` base branch |
| `backend` | `derive-wi`, `contract` | Checks out `story/WI-<id>`, creates sub-branch, runs `backend-dev` |
| `frontend` | `derive-wi`, `contract` | Checks out `story/WI-<id>`, creates sub-branch, runs `frontend-dev` |
| `merge-and-pr` | `derive-wi`, `backend`, `frontend` | Merges sub-branches into `story/WI-<id>`, opens feature PR, updates ADO, notifies Slack |

A merge conflict in `merge-and-pr` is surfaced as a pipeline error and treated as a scope violation — it should not happen if scope-enforce worked correctly.

### 8.4 Stage 3 — PR review (pr-review.yml)

Triggered on pull requests targeting `master` (excluding trace and design doc paths), or manually.

Runs three parallel matrix jobs, one per reviewer agent:

| Job | Agent | Focus |
|---|---|---|
| Code Review | `code-reviewer` | Correctness, patterns, maintainability |
| Security Review | `security-auditor` | Vulnerabilities, secret handling, input validation |
| Tech Debt Review | `tech-debt-auditor` | Duplication, coupling, complexity |

Each job: resolves PR metadata, checks out at the PR head SHA, runs the Copilot agent with a prompt to `git diff origin/master...HEAD` and post findings as PR comments. Agents never approve. Severity tags: `blocker`, `major`, `minor`, `nit`.

### 8.5 Stage 4 — Post-merge (post-merge.yml)

Triggered on push to `master`. No AI invocation. Pure bash:

1. Parses `WI-<id>` references from the merge commit message.
2. Updates each referenced work item state to `Closed` with a link to the commit.
3. Sends a Slack notification: `:white_check_mark: Merged to main: WI-X (abc12345)`.

### 8.6 Slice schema

Technical-slicing produces `slices.md` containing YAML that drives the implementation phase. Each entry:

```yaml
slices:
  - id: S1
    title: <short imperative title>
    layer: contract | backend | frontend | infra
    files:
      - path: <glob or exact>
        access: read-write | read-only
    depends_on: []          # other slice IDs; empty = can start immediately
    parallel_with: [S2]     # declared parallelism
    acceptance:
      - "Given ..., when ..., then ..."
    impact:
      blast_radius: low | medium | high
      touches: [database, api, web]
      rollback: trivial | moderate | hard
    risk:
      failure_mode: "<one sentence>"
      mitigation: "<one sentence>"
    test_plan:
      unit: "<command>"
      integration: "<command>"
```

Infra slices (`layer: infra`) cause `implement-story` to abort and flag for human implementation.

---

## 9. Windows developer setup

CI pipelines run on `ubuntu-latest` and require no Windows-specific configuration. The challenge is local developer use, where hooks are bash scripts.

### 9.1 Option A — WSL2 (recommended)

Run Claude Code entirely inside WSL2. No changes to hook scripts needed.

```powershell
# Install WSL2 (run in PowerShell as Administrator)
wsl --install
# Restart when prompted, then open the WSL2 terminal
```

Inside the WSL2 terminal:

```bash
# Install dependencies
sudo apt-get update && sudo apt-get install -y jq curl git
sudo curl -sSLo /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# Install Azure CLI and devops extension
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az extension add --name azure-devops

# Install gh CLI
sudo apt-get install -y gh

# Install Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Clone repo inside WSL2 filesystem (not /mnt/c — performance matters)
git clone git@github.com:org/repo.git ~/projects/repo
cd ~/projects/repo
claude
```

WSL2 accesses the Windows filesystem via `/mnt/c/...` but hooks perform significantly better when the repo lives in the Linux filesystem (`~/projects/`).

### 9.2 Option B — Git Bash

Use Git Bash from Git for Windows. Most hook scripts work; `yq` and `jq` need Windows binaries.

```powershell
# Install jq for Windows (scoop or winget)
winget install jqlang.jq

# Install yq for Windows
winget install MikeFarah.yq

# Install Azure CLI for Windows
winget install Microsoft.AzureCLI
```

Configure Git Bash for Claude Code:

```bash
# In Git Bash, set env var to prevent path conversion issues
export MSYS_NO_PATHCONV=1

# Add to ~/.bashrc in Git Bash
echo 'export MSYS_NO_PATHCONV=1' >> ~/.bashrc
```

Configure Claude Code to use Git Bash as the shell in `.claude/settings.local.json`:

```json
{
  "shell": "C:\\Program Files\\Git\\bin\\bash.exe"
}
```

Known limitations with Git Bash:
- `#!/usr/bin/env bash` shebangs work if `bash.exe` is on PATH
- `date -u +%Y-%m-%dT%H:%M:%SZ` works in Git Bash
- `az` and `gh` commands work if their Windows installers added them to PATH

### 9.3 Option C — Native PowerShell

Create PowerShell equivalents for each hook script, then point `settings.json` at the `.ps1` files.

**Structure of a PowerShell hook file:**

PowerShell hooks receive the tool-call payload as JSON on stdin. To allow, exit with code 0 (or simply return). To block, write a message to stderr and exit with code 2.

Example `block-sensitive-files.ps1`:

```powershell
#!/usr/bin/env pwsh
# Hook: PreToolUse on Edit|Write
# Purpose: Block writes to secret files, pipeline configs, and master skills.

$payload = $input | ConvertFrom-Json -ErrorAction SilentlyContinue
$file = $payload.tool_input.file_path
if (-not $file) { exit 0 }

$file = $file -replace '^\.\/', ''

$secretPatterns = @('*.env','*.env.*','*.pem','*.key','*.p12','*.pfx',
                    '*secret*','*secrets*','*credentials*')
$pipelinePatterns = @('.azure-pipelines/*','.github/workflows/*',
                      '.gitlab-ci.yml','Jenkinsfile')
$skillPatterns = @('shared/skills/*','.claude/skills/*',
                   '.claude/CLAUDE.md','.claude/settings.json')
$scopeMapPatterns = @('.claude/agents/scope-map.json','shared/agents/scope-map.json')

function Test-GlobMatch {
    param([string]$Pattern, [string]$Path)
    $regex = '^' + [regex]::Escape($Pattern).Replace('\*\*', '.*').Replace('\*', '[^/]*') + '$'
    return $Path -match $regex
}

$allBlocked = $secretPatterns + $pipelinePatterns + $skillPatterns + $scopeMapPatterns
foreach ($pattern in $allBlocked) {
    if (Test-GlobMatch -Pattern $pattern -Path $file) {
        Write-Error "BLOCKED by block-sensitive-files: $file"
        Write-Error "If this is intentional, a human must author the change."
        exit 2
    }
}
exit 0
```

Update `.claude/settings.json` to call the PowerShell scripts:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "pwsh .claude/hooks/block-sensitive-files.ps1" },
          { "type": "command", "command": "pwsh .claude/hooks/scope-enforce.ps1" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{ "type": "command", "command": "pwsh .claude/hooks/format-after-edit.ps1" }]
      },
      {
        "matcher": ".*",
        "hooks": [{ "type": "command", "command": "pwsh .claude/hooks/trace-decisions.ps1" }]
      }
    ]
  }
}
```

You must port four scripts: `block-sensitive-files.ps1`, `scope-enforce.ps1`, `format-after-edit.ps1`, and `trace-decisions.ps1`. The `normalize-input.sh` shims in `.github/hooks/` are only used by Copilot in CI and do not need Windows equivalents.

---

## 10. Bootstrap deep dive

`/bootstrap-project` is the one-time onboarding skill. It runs once per project adoption, must be invoked manually by a human (`disable-model-invocation: true`), and never writes `PROFILE.md` directly — only `PROFILE.draft.md`.

### 10.1 The seven phases

**Phase 1 — Inventory:** Glob and Grep the repo for signal files. Build an evidence list with file:line citations for every detected fact.

**Phase 2 — Classify:** For each evidence item, produce a structured classification entry:
```
frontend.framework: react     # source: apps/web/package.json:12 (react@18.2.0)
orchestration.pipeline_tool: github-actions  # source: .github/workflows/ directory present
orchestration.repo_host: github              # source: git remote origin = github.com/org/repo
```
Ambiguous signals list both alternatives:
```
backend.test: xunit | nunit   # source: ambiguous — both referenced in tests/SomeTests.csproj:7-9
                              # [NEEDS HUMAN INPUT]
```

**Phase 3 — Recommend skills:** Produce `recommended_skills.always`, `stack_specific`, and `not_applicable` lists based on detected stack.

**Phase 4 — Scaffold the project layer:** Create all `shared/project/` files that do not already exist. Starter templates contain section headers and `[NEEDS HUMAN INPUT]` markers — never guessed content.

**Phase 5 — Write PROFILE.draft.md:** Write the complete PROFILE in the canonical YAML schema. Every field either has a detected value with source citation, or contains `[NEEDS HUMAN INPUT]`.

**Phase 6 — Generate project CLAUDE.md:** Reads the 10 most recently modified source files, package.json scripts, any existing CONTRIBUTING.md or ADRs, and generates `shared/project/CLAUDE.md` with real content: how to build and run, how to test, key architectural patterns, non-obvious gotchas. Uncertain observations are marked `[VERIFY]` (Claude observed it; human should confirm), not `[NEEDS HUMAN INPUT]` (no signal at all).

**Phase 7 — Handoff:** Prints a structured summary listing the draft file location, what was scaffolded vs skipped, detected stacks, orchestration fields needing human input, and the four next steps (review draft, fill guidelines, rename to PROFILE.md, commit).

### 10.2 What bootstrap auto-detects vs. requires human input

| Field | Auto-detected | Requires human input |
|---|---|---|
| `project.name` | From `package.json` name or git remote | If neither is usable |
| `project.type` | From detected stack combination | If ambiguous |
| `orchestration.pipeline_tool` | From `.github/workflows/` or `.azure-pipelines/` presence | If both present or neither |
| `orchestration.repo_host` | From `git remote get-url origin` URL | If URL is unrecognized |
| `orchestration.work_items.org_url` | From `az devops configure` if configured | Always verify |
| `orchestration.work_items.project` | Cannot be auto-detected | Always |
| `orchestration.notifications.type` | Cannot be auto-detected | Always |
| `orchestration.notifications.webhook_url` | Cannot be auto-detected | Always |
| `stacks.*` | Framework files, config files | When ambiguous |
| `gates.*` | From `package.json` scripts, Makefile | When not in manifest |

### 10.3 Evidence-citation format

Every field in the draft carries a `# source:` comment in the form `<file>:<line> (<evidence>)`. Fabricated facts are prohibited — if bootstrap cannot cite evidence, the field value is literally `[NEEDS HUMAN INPUT]`. This makes the review step straightforward: a human reads the draft, checks the cited files, and either confirms or corrects each value.

---

## 11. Adding a new skill

To add a new skill to the system (e.g., `performance-review`):

**Step 1 — Create the skill file:**

```bash
mkdir -p shared/skills/performance-review
# Write the skill procedure in shared/skills/performance-review/SKILL.md
```

The SKILL.md must include the frontmatter block, the load-order preamble (PROFILE → CLAUDE.md → overrides → guidelines → stacks), and the skill procedure. Follow the existing skills as templates.

**Step 2 — Add to block-sensitive-files.sh protection:**

Both `.claude/hooks/block-sensitive-files.sh` and `.github/hooks/block-sensitive-files.sh` contain a pattern for `shared/skills/*`. New skills in `shared/skills/` are automatically protected — no change needed.

**Step 3 — No wrapper files needed:**

Both tools discover skills directly from `shared/skills/<name>/SKILL.md`. There are no wrapper files in `.claude/skills/` or `.github/instructions/` for skills. If you want the skill to appear in skill listings, the discovery is via the shared path.

**Step 4 — Add a subagent if the skill needs one:**

If the new skill spawns a subagent (as `pr-review` spawns `code-reviewer`):

1. Write the full agent definition in `shared/agents/<name>.md`
2. Add the Claude Code thin wrapper in `.claude/agents/<name>.md` (frontmatter + `See shared/agents/<name>.md`)
3. Add the Copilot thin wrapper in `.github/agents/<name>.agent.md` (Copilot frontmatter + same reference)
4. Add the agent's scope to `shared/agents/scope-map.json`, `.claude/agents/scope-map.json`, and `.github/agents/scope-map.json`

**Step 5 — Add to a workflow if pipeline-invoked:**

Add a new job to the relevant GitHub Actions workflow (`.github/workflows/`) or Azure Pipelines file (`.azure-pipelines/`). These files are protected — only humans may edit them.

---

## 12. Extending notifications or repo integrations

### 12.1 Adding a new notification type

Edit `shared/scripts/notify.sh`. Add a new `case` branch for the new type name:

```bash
case "$notif_type" in
  slack)   # ... existing ...  ;;
  teams)   # ... existing ...  ;;
  webhook) # ... existing ...  ;;
  pagerduty)
    # Example: PagerDuty Events API v2
    payload=$(jq -n --arg t "$msg" '{routing_key: $ROUTING_KEY, event_action: "trigger",
      payload: {summary: $t, severity: "info", source: "ai-sdlc"}}')
    curl -sS -X POST -H 'Content-Type: application/json' \
      --data "$payload" "https://events.pagerduty.com/v2/enqueue" >/dev/null
    echo "PagerDuty notification sent."
    ;;
esac
```

Update the PROFILE.md `orchestration.notifications.type` enum documentation in `shared/project/PROFILE.draft.md` to include the new option, so bootstrap reflects it.

### 12.2 Adding a new repo host

Edit `shared/scripts/create-pr.sh`. Add a new `case` branch:

```bash
case "$repo_host" in
  github)       # ... existing ... ;;
  azure-repos)  # ... existing ... ;;
  gitlab)
    glab mr create \
      --title "$title" \
      --description "$body_text" \
      --source-branch "$branch" \
      --target-branch "$base"
    ;;
esac
```

Also update the `PROFILE.draft.md` template so bootstrap can detect and set the new value, and update the detection logic in `shared/skills/bootstrap-project/SKILL.md` (Phase 1, repo host detection) to recognize the new remote URL pattern.

---

## 13. Permissions model

| Actor | Scope | Secret location |
|---|---|---|
| ADO PAT (`ADO_PAT`) | Work items RW, code RW, build RW, PR RW | GitHub Actions secret / Azure Pipelines library |
| GitHub token (`GH_TOKEN` / `COPILOT_TOKEN`) | Repo contents write, PR write | GitHub Actions secret |
| Anthropic API key (via Copilot) | Claude inference | GitHub Actions secret |
| Slack webhook (`SLACK_WEBHOOK_URL`) | Post to one channel | GitHub Actions secret / Pipeline library |
| `GITHUB_TOKEN` | PR read, PR write comments | Auto-injected by Actions runner |

Claude/Copilot running in CI executes with only the granted token's permissions. Branch policies on `master` require at least one human approval — Claude cannot merge. The `block-sensitive-files` hook prevents writing pipeline YAML even if an adversarial prompt tries to do so.

---

## 14. Observability

| Signal | Where it goes | Retention |
|---|---|---|
| Copilot/Claude stdout + stderr | Pipeline log and `copilot-output.log` artifact | 90 days |
| Hook trace (`trace-decisions.sh`) | `.github/trace/<run-id>.jsonl` uploaded as artifact | 90 days |
| Scope block events | `.claude/trace/scope-blocks.jsonl` | Local / per run |
| Formatter failures | `.claude/trace/format-failures.jsonl` | Local / per run |
| Subagent return JSON | Embedded in feature PR description | PR lifetime |
| Slack thread | Slack channel | Per Slack retention |
| ADO work item comments | ADO | Forever |

Querying traces locally:

```bash
# All blocked tool calls across a run
jq 'select(.tool=="Edit" or .tool=="Write") | select(.status=="false")' \
  .claude/trace/<run-id>.jsonl

# All scope violations
jq '.' .claude/trace/scope-blocks.jsonl
```

---

## 15. Cost model (rough)

Based on May 2026 Anthropic pricing via GitHub Copilot (claude-sonnet-4-6):

| Stage | Tokens (rough) | Cost estimate |
|---|---|---|
| Design gen (`/requirements-analysis`) | ~80k in + 30k out | ~$2.50 |
| Contract-dev | ~20k in + 10k out | ~$0.20 |
| Backend-dev | ~120k in + 40k out | ~$1.50 |
| Frontend-dev | ~120k in + 40k out | ~$1.50 |
| PR review × 3 reviewers | ~60k in + 10k out each | ~$2.40 |
| **Total per typical story** | | **~$8** |

Double for complex stories, halve for simple ones. At 50 stories/week the bill is approximately $2k/month ± 50%. Use `--max-turns` caps in workflow files to bound worst-case spend.

---

## 16. Security considerations

**Prompt injection surface:** Work item descriptions, PR descriptions, and file contents all flow into the model context. The hook layer is the primary defence: `block-sensitive-files` prevents exfiltration via file write, `scope-enforce` prevents lateral movement between layers.

**Secret handling:** All secrets live in pipeline variable groups or GitHub Actions secrets, injected as environment variables. They are never written to files, never echoed in script output (pipelines mask values matching secret patterns).

**PAT scope minimisation:** The ADO PAT is limited to one ADO project. Rotate quarterly. The Copilot token (`GH_TOKEN`) is scoped to `contents: write` and `pull-requests: write` only — it cannot modify Actions workflows.

**Merge discipline:** Branch policies on `master` require human approval. Claude/Copilot can only open PRs and post comments. It cannot approve or merge.

**Master skill protection:** The `block-sensitive-files` hook blocks writes to `shared/skills/**`. Project customisation goes in `shared/project/` — never in `shared/skills/`.

**Audit:** Every tool call is logged by `trace-decisions.sh`. Every blocked call is logged separately in `scope-blocks.jsonl`. Trace artifacts are retained for 90 days.

**Data residency:** If using a hosted Anthropic endpoint (e.g. via Azure AI Foundry), configure the Copilot CLI to point at that endpoint. Trace data stays within the CI runner's retention boundary.

---

## 17. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| All skills abort with `"Run /bootstrap-project first."` | `shared/project/PROFILE.md` does not exist | Run `/bootstrap-project`, complete the checklist, rename `PROFILE.draft.md` → `PROFILE.md` |
| Hook not running (Claude Code, macOS/Linux) | Script not executable | `chmod +x .claude/hooks/*.sh` |
| Hook not running (Claude Code, Windows Git Bash) | Hook path uses forward slashes but Git Bash expects native paths | Set `MSYS_NO_PATHCONV=1` in Git Bash; verify hook command in `settings.json` uses forward slashes |
| Hook not running (Claude Code, Windows native) | `.sh` scripts cannot run natively | Use WSL2 (Option A), Git Bash (Option B), or port to PowerShell `.ps1` (Option C) |
| Hook not running (Copilot) | `hooks.json` not registered or `bash` path incorrect | Verify `.github/hooks/hooks.json` path; confirm Copilot version supports hook config; check `chmod +x .github/hooks/*.sh` runs in CI setup step |
| `PROFILE.md not found; defaulting to github repo_host.` in notify.sh | Scripts called before `PROFILE.md` is activated | Rename `PROFILE.draft.md` → `PROFILE.md` after bootstrap review |
| `Unknown notification type: <x>` from notify.sh | `orchestration.notifications.type` contains an unsupported value | Set to `slack`, `teams`, or `webhook` in PROFILE.md |
| `Unknown repo_host: <x>` from create-pr.sh | `orchestration.repo_host` contains an unsupported value | Set to `github` or `azure-repos` in PROFILE.md |
| Scope block: `"Subagent 'backend-dev' has no declared scope covering apps/web/..."` | backend-dev attempted to write a frontend file — usually a prompt misunderstanding | Review subagent prompt. The subagent must return a blocker in JSON summary, not edit out of scope |
| Merge conflict in `merge-and-pr` job | Scope violation — backend and frontend sub-branches touched the same file | Investigate which shared file was written by both subagents. Fix the slices.md file-scope declarations or the subagent prompts. The conflict should not occur if scope was respected |
| Feature PR opened as draft unexpectedly | `verify-story` returned `ISSUES_FOUND` or `BLOCKED` | Read `docs/designs/WI-<id>/verification.md` for specific AC failures |
| Browser verification skipped | Chrome MCP not connected, or all slices are `layer: backend` only, or `skip_browser_verification: true` | Check the trace for the skip reason; connect Chrome MCP for local runs |
| ADO work item state not updated after merge | `post-merge.yml` could not parse `WI-<id>` from commit message | Ensure merge commit message contains `WI-<id>`; verify `ADO_PAT` secret is set and has work item write permission |
| Notification not sent after design PR | `notify.sh` silently skipped (PROFILE.md not found or notification not configured) | Verify PROFILE.md exists and `orchestration.notifications.*` fields are filled in without `[NEEDS HUMAN INPUT]` |
| `yq: command not found` in CI | yq install step failed or was skipped | Verify the `Install tooling` step in the workflow ran successfully; yq binary path is `/usr/local/bin/yq` |
| `az devops login` fails | `ADO_PAT` secret not set or expired | Verify the secret in GitHub Actions settings; rotate the PAT if expired |
| Copilot workflow step exits 0 but no skill output produced | Copilot invocation received but skill aborted due to missing PROFILE.md or malformed input | Check `copilot-output.log` artifact; confirm `shared/project/PROFILE.md` is committed to the repo |
