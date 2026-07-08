# Technical Design — Conductor

**Project codename:** Conductor
**Version:** 3.0 (unified `plugin/` architecture)
**Companion:** `FUNCTIONAL_DESIGN.md`

---

## Table of contents

1. [Overview](#1-overview)
2. [Repository layout](#2-repository-layout)
3. [PROFILE.md — the config backbone](#3-profilemd--the-config-backbone)
4. [Plugin skills](#4-plugin-skills)
5. [Agent architecture](#5-agent-architecture)
6. [Bin tools and config-driven execution](#6-bin-tools-and-config-driven-execution)
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

Conductor is a pipeline that turns Azure DevOps work items into implemented, reviewed pull requests with minimal human intervention. Work items tagged `ai:ready` flow through design generation, parallel subagent implementation, and multi-dimensional PR review — driven by **GitHub Copilot (CLI or VS Code)** or **Claude Code**, both loading the exact same plugin.

The key architectural principle is **a single installable plugin, distributed once, used identically by every tool.** All skills, agent definitions, CLI tools, and hooks live in `plugin/` in this repository (`Conductor`) and are consumed by target projects as an installed plugin — never copied into the target repo. Only project-owned configuration (`shared/project/`) and CI pipeline definitions (`.azure-pipelines/`, `.github/workflows/`) are ever written into a consuming project, and those are generated once by `bootstrap-project` from the templates in `plugin/project-templates/`.

```
                         ┌──────────────────────────────┐
                         │        AZURE DEVOPS           │
                         │  Work Item tagged ai:ready    │
                         │           │                   │
                         │           ▼                   │
                         │  ado-poller.yml (hourly)      │
                         │   dispatches repository_      │
                         │   dispatch / webhook event     │
                         └──────────────┬────────────────┘
                                        │
                    ┌───────────────────▼─────────────────────┐
                    │     Conductor (this repo)      │
                    │                                          │
                    │  marketplace.json  ── plugin manifest    │
                    │  plugin/                                 │
                    │    .claude-plugin/plugin.json            │
                    │    skills/    (10)   agents/  (6)        │
                    │    bin/       (11)   hooks/hooks.json (2)│
                    │    project-templates/                    │
                    └──────────────────┬───────────────────────┘
                                       │ installed once via
                                       │ `copilot plugin install` /
                                       │ `claude plugin add`
                                       ▼
                    ┌──────────────────────────────────────────┐
                    │           CONSUMING PROJECT REPO           │
                    │                                            │
                    │  shared/project/     ← PROJECT-OWNED       │
                    │    PROFILE.md        single config         │
                    │    CLAUDE.md         backbone               │
                    │    guidelines/                              │
                    │    overrides/                                │
                    │    stacks/                                   │
                    │                                              │
                    │  .azure-pipelines/   ← copied from           │
                    │  .github/workflows/    project-templates/    │
                    └──────────────────────────────────────────────┘
                    GitHub Copilot (CLI / VS Code) and Claude Code
                    both discover the same plugin/ skills, agents,
                    bin tools, and hooks — no per-tool wrapper files.
```

---

## 2. Repository layout

```
Conductor/                        ← THIS repo — the plugin source
│
├── marketplace.json                         ← plugin registry manifest (name, version, capability counts)
│
├── plugin/                                  ← THE INSTALLABLE PLUGIN — single source for all tools
│   ├── .claude-plugin/
│   │   └── plugin.json                      ← plugin manifest (name, version, author, keywords)
│   ├── README.md                            ← plugin-local reference (skills/agents/bin/hooks tables)
│   ├── settings.json                        ← recommended tool permissions
│   ├── scope-map.json                       ← authoritative per-subagent file-scope boundaries
│   │
│   ├── skills/                              ← 10 SKILL.md files (single source, no per-tool wrappers)
│   │   ├── bootstrap-project/SKILL.md
│   │   ├── requirements-analysis/SKILL.md
│   │   ├── update-functional/SKILL.md
│   │   ├── technical-slicing/SKILL.md
│   │   ├── implement-story/SKILL.md         ← orchestrator
│   │   ├── implement-slice/SKILL.md         ← single-slice fallback
│   │   ├── pr-review/SKILL.md
│   │   ├── security-review/SKILL.md
│   │   ├── tech-debt-review/SKILL.md
│   │   └── verify-story/
│   │       ├── SKILL.md
│   │       └── report-template.md
│   │
│   ├── agents/                              ← 6 full agent definitions (no thin wrappers)
│   │   ├── backend-dev.md
│   │   ├── frontend-dev.md
│   │   ├── contract-dev.md
│   │   ├── code-reviewer.md
│   │   ├── security-auditor.md
│   │   └── tech-debt-auditor.md
│   │
│   ├── bin/                                 ← 11 CLI tools, auto-added to PATH when the plugin is installed
│   │   ├── conductor-wi-show
│   │   ├── conductor-wi-update
│   │   ├── conductor-wi-create-slice
│   │   ├── conductor-create-pr                ← config-driven: GitHub | Azure Repos
│   │   ├── conductor-pr-comment
│   │   ├── conductor-notify                   ← config-driven: Slack | Teams | webhook
│   │   ├── conductor-check-compile            ← reads PROFILE.md gates.compile
│   │   ├── conductor-check-startup            ← reads PROFILE.md gates.startup
│   │   ├── conductor-check-tech-agnostic
│   │   ├── conductor-scope-guard              ← hook: blocks writes to protected paths
│   │   └── conductor-bash-guard               ← hook: blocks destructive shell commands
│   │
│   ├── hooks/
│   │   └── hooks.json                       ← 2 hooks: PostToolUse(Write|Edit), PreToolUse(Bash)
│   │
│   └── project-templates/                   ← copied into a consuming repo by bootstrap-project
│       ├── PROFILE.draft.md
│       ├── CLAUDE.md
│       ├── guidelines/
│       │   ├── coding-standards.md
│       │   ├── error-handling.md
│       │   ├── api-contracts.md
│       │   └── naming.md
│       ├── overrides/
│       │   └── verify-story.md
│       ├── stacks/.gitkeep
│       ├── .azure-pipelines/                ← 4 Azure Pipelines YAML templates
│       │   ├── design-gen.yml
│       │   ├── implement-story.yml
│       │   ├── pr-review.yml
│       │   └── post-merge.yml
│       └── .github/workflows/               ← 5 GitHub Actions workflow templates
│           ├── ado-poller.yml
│           ├── design-gen.yml
│           ├── implement-story.yml
│           ├── pr-review.yml
│           └── post-merge.yml
│
└── docs/
    ├── FUNCTIONAL_DESIGN.md
    └── TECHNICAL_DESIGN.md                  ← this file

────────────────────────────────────────────────────────────────────────────

<consuming-project-repo>/                    ← a project with the plugin installed
│
├── shared/project/                          ← PROJECT-OWNED configuration layer, generated once
│   ├── PROFILE.md                           ← activated by renaming from PROFILE.draft.md
│   ├── PROFILE.draft.md                     ← bootstrap writes here; human confirms
│   ├── CLAUDE.md                            ← project policy (overrides plugin defaults)
│   ├── guidelines/
│   │   ├── coding-standards.md
│   │   ├── error-handling.md
│   │   ├── api-contracts.md
│   │   └── naming.md
│   ├── overrides/
│   │   └── verify-story.md                  ← example per-skill override
│   └── stacks/                              ← per-stack files (populated on demand)
│
├── .azure-pipelines/                        ← copied from plugin/project-templates, human-owned
│   ├── design-gen.yml
│   ├── implement-story.yml
│   ├── pr-review.yml
│   └── post-merge.yml
│
├── .github/workflows/                       ← copied from plugin/project-templates, human-owned
│   ├── ado-poller.yml
│   ├── design-gen.yml
│   ├── implement-story.yml
│   ├── pr-review.yml
│   └── post-merge.yml
│
└── docs/designs/
    └── WI-<id>/
        ├── functional.md
        ├── technical.md
        ├── slices.md
        ├── verification.md                  ← written by verify-story subagent
        └── screenshots/                     ← browser verification screenshots
```

The plugin itself is **never** copied into a consuming repo. It is installed once (`copilot plugin install --from <repo-url>` or `claude plugin add --from <repo-url>`) and the tool resolves `plugin/skills/`, `plugin/agents/`, `plugin/bin/`, and `plugin/hooks/hooks.json` directly from the installed plugin location. Updating the plugin (a new tagged release of this repo) updates every consuming project automatically on next install/refresh — there is nothing to keep in sync by hand.

---

## 3. PROFILE.md — the config backbone

`shared/project/PROFILE.md` is the single configuration file that controls how every skill and bin tool behaves. It is created by `/bootstrap-project` as `PROFILE.draft.md` and activated by renaming it to `PROFILE.md`. Until `PROFILE.md` exists, all Conductor skills abort with the message: `PROFILE.md not found. Run /bootstrap-project first.`

### 3.1 Complete annotated example

The following is a fully filled-in example for a GitHub Actions + GitHub + Slack team:

```yaml
project:
  name: my-product
  type: fullstack-monorepo      # frontend | backend | fullstack | infra | fullstack-monorepo
  repo_kind: monorepo           # single | monorepo

# ── Orchestration ─────────────────────────────────────────────────────────────
# Controls which pipeline tool, repo host, and notification system the bin tools use.
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
| `orchestration.repo_host` | enum | yes | `github` or `azure-repos` — drives `conductor-create-pr` |
| `orchestration.work_items.source` | enum | yes | Always `ado` in current release |
| `orchestration.work_items.org_url` | URL | yes | ADO organization URL |
| `orchestration.work_items.project` | string | yes | ADO project name |
| `orchestration.notifications.type` | enum | yes | `slack`, `teams`, or `webhook` — drives `conductor-notify` |
| `orchestration.notifications.webhook_url` | URL | yes | Incoming webhook URL |
| `orchestration.notifications.channel` | string | Slack only | Target channel, e.g. `#engineering` |
| `stacks.*` | object | recommended | Detected stack; each field carries a `# source:` comment |
| `gates.pre_commit` | shell command | recommended | Runs before commits during implementation |
| `gates.pre_merge` | shell command | recommended | Runs before feature PR is opened |
| `gates.compile.frontend` | shell command | optional | `conductor-check-compile` runs this; `n/a` to skip |
| `gates.compile.backend` | shell command | optional | `conductor-check-compile` runs this; `n/a` to skip |
| `gates.startup.frontend` | shell command | optional | `conductor-check-startup` starts the frontend process |
| `gates.startup.backend` | shell command | optional | `conductor-check-startup` starts the backend process |
| `gates.healthcheck.frontend` | shell command | optional | HTTP check after startup wait |
| `gates.healthcheck.backend` | shell command | optional | HTTP check after startup wait |
| `gates.startup_wait_seconds` | int | optional | Default 15; seconds to wait after starting app |
| `gates.skip_browser_verification` | bool | optional | Default false; set true to skip verify-story |
| `quarantined_paths` | string[] | optional | Paths AI must never touch; enforced by scope-guard |
| `reviewers` | string[] | optional | ADO login names auto-added as PR reviewers |

---

## 4. Plugin skills

### 4.1 Discovery and path convention

Skills live at `plugin/skills/<name>/SKILL.md` inside the installed plugin. Both GitHub Copilot and Claude Code discover them the same way once the plugin is installed (`copilot plugin install --from ...` / `claude plugin add --from ...`): there are no per-tool wrapper files, and skills are never copied into the consuming project.

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
| `bootstrap-project` | Human: `/bootstrap-project` | `shared/project/PROFILE.draft.md` + scaffolded guideline stubs + copied pipeline templates |
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

`functional.md` must not contain framework, protocol, or cloud-service names. `conductor-check-tech-agnostic` enforces a grep blocklist against the file and exits non-zero on any match. The blocked terms include: `OAuth`, `JWT`, `REST`, `GraphQL`, `gRPC`, `PostgreSQL`, `MySQL`, `Redis`, `MongoDB`, `React`, `Angular`, `Vue`, `Next`, `Svelte`, `Kubernetes`, `Docker`, `AWS`, `Lambda`, `S3`, `Cosmos`, `RabbitMQ`, `Kafka`, `Azure` (as cloud service name). These terms are permitted in `technical.md`.

---

## 5. Agent architecture

### 5.1 Single definition, no thin wrappers

Every agent has exactly one file: `plugin/agents/<name>.md`. It contains the complete procedure, scope declaration, output contract, and blocker rules. Both GitHub Copilot and Claude Code load this same file directly from the installed plugin — there is no tool-specific frontmatter split and no duplicated wrapper file to keep in sync.

### 5.2 scope-map.json

`plugin/scope-map.json` defines per-subagent file boundaries. The `conductor-scope-guard` hook reads this file at runtime. Precedence: `denied` wins over `read_only` wins over `read_write`.

```json
{
  "contract-dev": {
    "read_write": ["contracts/**"],
    "read_only": ["docs/designs/**", "shared/project/**", "apps/**/openapi*", "apps/**/*.graphql"],
    "denied": ["apps/api/**", "apps/web/**", ".azure-pipelines/**", ".github/workflows/**",
               "plugin/skills/**", "plugin/agents/**", "*.env", "*.pem", "*.key"]
  },
  "backend-dev": {
    "read_write": ["apps/api/**", "tests/api/**", "apps/server/**", "tests/server/**"],
    "read_only": ["contracts/**", "shared/project/**", "docs/designs/**", "apps/shared/**"],
    "denied": ["apps/web/**", "apps/client/**", ".azure-pipelines/**", ".github/workflows/**",
               "plugin/skills/**", "plugin/agents/**", "*.env", "*.pem", "*.key"]
  },
  "frontend-dev": {
    "read_write": ["apps/web/**", "tests/web/**", "apps/client/**", "tests/client/**"],
    "read_only": ["contracts/**", "shared/project/**", "docs/designs/**", "apps/shared/**"],
    "denied": ["apps/api/**", "apps/server/**", ".azure-pipelines/**", ".github/workflows/**",
               "plugin/skills/**", "plugin/agents/**", "*.env", "*.pem", "*.key"]
  },
  "code-reviewer": { "read_write": [], "read_only": ["**"], "denied": ["*.env","*.pem","*.key"] },
  "security-auditor": { "read_write": [], "read_only": ["**"], "denied": [] },
  "tech-debt-auditor": { "read_write": [], "read_only": ["**"], "denied": ["*.env","*.pem","*.key"] },
  "verify-story": {
    "read_write": ["docs/designs/WI-*/verification.md", "docs/designs/WI-*/screenshots/**"],
    "read_only": ["**"],
    "denied": ["*.env","*.pem","*.key","plugin/skills/**","plugin/agents/**",".azure-pipelines/**",".github/workflows/**"]
  }
}
```

A merge conflict between backend and frontend sub-branches always indicates a scope violation, because their `read_write` paths are declared disjoint.

### 5.3 Subagent return contract

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

## 6. Bin tools and config-driven execution

All CLI tools in `plugin/bin/` are prefixed `conductor-`, idempotent where possible, exit non-zero on failure, and log to stderr. They are added to `PATH` automatically once the plugin is installed, and may be called by skills, by pipeline YAML, or directly by developers.

### 6.1 Bin tool inventory

| Command | Purpose |
|---|---|
| `conductor-wi-show <id>` | Print ADO work item JSON: `az boards work-item show --id <id>` |
| `conductor-wi-update <id> --state <s> --discussion <text>` | Update work item state and append discussion comment |
| `conductor-wi-create-slice <parent-id> <slice-yaml>` | Create a child Task work item from a slice YAML file |
| `conductor-pr-comment <pr-id> <thread-status> <comment-file>` | Post a comment thread on a PR |
| `conductor-check-compile [frontend\|backend\|both]` | Reads `gates.compile.<layer>` from PROFILE.md and runs it |
| `conductor-check-startup [frontend\|backend\|both]` | Starts app, waits `startup_wait_seconds`, runs healthcheck, kills |
| `conductor-check-tech-agnostic <file>` | Grep blocklist against a file; exits non-zero on any forbidden term |
| `conductor-notify <message>` | Config-driven notification (see below) |
| `conductor-create-pr --title <t> --body <b> --branch <br> [--base <base>]` | Config-driven PR creation (see below) |
| `conductor-scope-guard <file>` | Hook: blocks writes to protected paths |
| `conductor-bash-guard <command>` | Hook: blocks destructive shell commands |

### 6.2 conductor-notify — branching logic

`conductor-notify` reads `orchestration.notifications.type` and `orchestration.notifications.webhook_url` from `shared/project/PROFILE.md` using `yq`. If `PROFILE.md` is absent or the notification fields contain `[NEEDS HUMAN INPUT]`, the script exits 0 silently — a missing notification config is never a pipeline failure.

When configured:
- **`type: slack`** — constructs a JSON payload `{text, channel}` (channel included if the `channel` field is set). Posts to the webhook URL with `curl`.
- **`type: teams`** — constructs a MessageCard payload `{"@type":"MessageCard","text":"..."}`. Posts to the Power Automate / Teams webhook URL.
- **`type: webhook`** — constructs a minimal `{text, timestamp}` JSON payload. Posts to any generic HTTP endpoint.

All three variants use `curl -sS -X POST -H 'Content-type: application/json'` and write nothing to stdout on success; the caller sees a one-line confirmation message on stdout.

### 6.3 conductor-create-pr — branching logic

`conductor-create-pr` reads `orchestration.repo_host` from PROFILE.md using `yq`. If PROFILE.md is absent, it defaults to `github`. The `--body` argument can be either literal text or `@path/to/file` (the `@` prefix triggers a file read).

- **`repo_host: github`** — calls `gh pr create --title ... --body ... --head ... --base ...`. Requires `gh` CLI authenticated (via `GH_TOKEN` env var in CI, or `gh auth login` locally).
- **`repo_host: azure-repos`** — calls `az repos pr create --title ... --description ... --source-branch ... --target-branch ...`. Requires `az` CLI with the `azure-devops` extension and an active `az devops login` session.

---

## 7. Hook system

The plugin ships two hooks in `plugin/hooks/hooks.json`, backed by two bin scripts. Both GitHub Copilot and Claude Code discover this single `hooks.json` from the installed plugin — there is no per-tool duplication and no JSON-shape normalization layer.

```json
{
  "hooks": [
    {
      "event": "PostToolUse",
      "matcher": { "tool": "Write|Edit" },
      "hooks": [
        {
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/bin/conductor-scope-guard \"$FILE_PATH\"",
          "description": "Prevent writes to protected paths (pipeline YAML, secrets, master skills)"
        }
      ]
    },
    {
      "event": "PreToolUse",
      "matcher": { "tool": "Bash" },
      "hooks": [
        {
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/bin/conductor-bash-guard \"$COMMAND\"",
          "description": "Block dangerous operations: git push --force, git commit --no-verify, rm -rf /"
        }
      ]
    }
  ]
}
```

### 7.1 conductor-scope-guard (PostToolUse, Write|Edit)

Blocks writes to protected path patterns: pipeline configs (`.azure-pipelines/*`, `.github/workflows/*`), secrets (`*.env`, `*secrets*`, `*credentials*`), and master skill/agent content (`plugin/skills/*`, `plugin/agents/*`). On a match it prints `BLOCKED: Write to protected path '<file>' is not allowed.` and exits non-zero, which the calling tool surfaces to the model as the reason for the block.

### 7.2 conductor-bash-guard (PreToolUse, Bash)

Blocks destructive shell invocations before they run: `git push --force` (and `--force-with-lease` variants), `git commit --no-verify`, and `rm -rf /`-style recursive deletes at filesystem roots.

### 7.3 Subagent scope enforcement

Scope enforcement for subagents (`contract-dev`, `backend-dev`, `frontend-dev`, and the read-only reviewers) is layered on top of `conductor-scope-guard` by consulting `plugin/scope-map.json` for the calling subagent's declared `read_write` / `read_only` / `denied` globs, in that precedence order, before allowing a write.

---

## 8. Pipeline stages — end to end

The system has five pipeline stages. GitHub Actions workflow templates (`plugin/project-templates/.github/workflows/`) are the reference implementation; the Azure Pipelines templates (`plugin/project-templates/.azure-pipelines/`) implement the same logic using `ClaudeCodeBaseTask@1`. Both sets of templates are copied into the consuming repo by `bootstrap-project` and are then human-owned — the plugin's `conductor-scope-guard` hook refuses to let AI agents edit them afterward.

Every pipeline job that invokes a skill or agent must first install the plugin so the `/skill-name` commands, agent definitions, and `conductor-*` bin tools are available:

- **GitHub Actions:** `npm install -g @github/copilot && copilot plugin install --from https://github.com/deepu-roy/Conductor`
- **Azure Pipelines:** `npm install -g @anthropic-ai/claude-code && claude plugin add --from https://github.com/deepu-roy/Conductor` (ahead of the `ClaudeCodeBaseTask@1` step)

### 8.1 Stage 0 — ADO polling (ado-poller.yml)

Runs every hour via cron (GitHub Actions) or fires from an ADO Service Hook (Azure Pipelines `resources.webhooks`). Queries ADO with WIQL for work items tagged `ai:ready` but not `ai:processing`, in non-terminal states. For each match:

1. Fires a `repository_dispatch` event (`ado-workitem-ai-ready`) with the work item ID in the payload.
2. Tags the work item with `ai:processing` to prevent re-dispatch on the next poll.

Notifications go through `conductor-notify` on both empty-queue and dispatched-items outcomes.

### 8.2 Stage 1 — Design generation (design-gen.yml)

Triggered by `repository_dispatch` from the poller, or manually via `workflow_dispatch`.

```
1. Resolve work item ID (from dispatch payload or manual input)
2. Install jq, yq, az devops extension
3. az devops login with ADO_PAT
4. Install the Copilot/Claude CLI and the Conductor plugin
5. Run /requirements-analysis <id>
6. Archive the run log as a build artifact (90-day retention)
```

The skill procedure:
- Reads the ADO work item via `conductor-wi-show`
- Loads the project layer (PROFILE → CLAUDE.md → overrides → guidelines → stacks)
- Generates `docs/designs/WI-<id>/functional.md`, `technical.md`, and `slices.md`
- Runs `conductor-check-tech-agnostic` on `functional.md`
- Creates ADO child Task work items for each slice via `conductor-wi-create-slice`
- Commits design docs, pushes, opens a design PR via `conductor-create-pr`
- Notifies via `conductor-notify`

### 8.3 Stage 2 — Story implementation (implement-story.yml)

Triggered on push to `master` where `docs/designs/WI-*/**` paths changed, or manually.

The workflow has five jobs:

| Job | Depends on | What it does |
|---|---|---|
| `derive-wi` | — | Extracts WI number from merge commit message or manual input |
| `contract` | `derive-wi` | Runs `contract-dev` if slices.md contains `layer: contract` slices; creates `story/WI-<id>` base branch |
| `backend` | `derive-wi`, `contract` | Checks out `story/WI-<id>`, creates sub-branch, runs `backend-dev` |
| `frontend` | `derive-wi`, `contract` | Checks out `story/WI-<id>`, creates sub-branch, runs `frontend-dev` |
| `merge-and-pr` | `derive-wi`, `backend`, `frontend` | Merges sub-branches into `story/WI-<id>`, opens feature PR, updates ADO, notifies |

A merge conflict in `merge-and-pr` is surfaced as a pipeline error and treated as a scope violation — it should not happen if scope enforcement worked correctly.

### 8.4 Stage 3 — PR review (pr-review.yml)

Triggered on pull requests targeting `master` (excluding design doc paths), or manually.

Runs three parallel matrix jobs, one per reviewer agent:

| Job | Agent | Focus |
|---|---|---|
| Code Review | `code-reviewer` | Correctness, patterns, maintainability |
| Security Review | `security-auditor` | Vulnerabilities, secret handling, input validation |
| Tech Debt Review | `tech-debt-auditor` | Duplication, coupling, complexity |

Each job: resolves PR metadata, checks out at the PR head SHA, runs the agent with a prompt to `git diff origin/master...HEAD` and post findings as PR comments. Agents never approve. Severity tags: `blocker`, `major`, `minor`, `nit`.

### 8.5 Stage 4 — Post-merge (post-merge.yml)

Triggered on push to `master`. No AI invocation — pure bash, using `conductor-wi-update` and `conductor-notify`:

1. Parses `WI-<id>` references from the merge commit message.
2. Updates each referenced work item state to `Closed` with a link to the commit.
3. Sends a notification: `:white_check_mark: Merged to main: WI-X (abc12345)`.

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

CI pipelines run on `ubuntu-latest` and require no Windows-specific configuration. The challenge is local developer use, since `conductor-*` bin tools are bash scripts.

### 9.1 Option A — WSL2 (recommended)

Run Copilot CLI or Claude Code entirely inside WSL2. No changes needed.

```powershell
wsl --install
```

Inside the WSL2 terminal:

```bash
sudo apt-get update && sudo apt-get install -y jq curl git
sudo curl -sSLo /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az extension add --name azure-devops

sudo apt-get install -y gh

npm install -g @github/copilot   # or: npm install -g @anthropic-ai/claude-code
copilot plugin install --from https://github.com/deepu-roy/Conductor

git clone git@github.com:org/repo.git ~/projects/repo
cd ~/projects/repo
copilot
```

WSL2 accesses the Windows filesystem via `/mnt/c/...` but performs significantly better when the repo lives in the Linux filesystem (`~/projects/`).

### 9.2 Option B — Git Bash

Use Git Bash from Git for Windows. Most bin tools work; `yq` and `jq` need Windows binaries.

```powershell
winget install jqlang.jq
winget install MikeFarah.yq
winget install Microsoft.AzureCLI
```

```bash
export MSYS_NO_PATHCONV=1
echo 'export MSYS_NO_PATHCONV=1' >> ~/.bashrc
```

Known limitations: `#!/usr/bin/env bash` shebangs work if `bash.exe` is on PATH; `az` and `gh` commands work if their Windows installers added them to PATH.

### 9.3 Option C — Native PowerShell

Not officially supported. `plugin/bin/` scripts are bash-only; porting them to `.ps1` equivalents is a larger undertaking than for the old per-project hook model, since the bin tools now live inside the plugin package rather than a project-local `shared/scripts/` directory. Prefer Option A or B on Windows.

---

## 10. Bootstrap deep dive

`/bootstrap-project` is the one-time onboarding skill. It runs once per project adoption, must be invoked manually by a human, and never writes `PROFILE.md` directly — only `PROFILE.draft.md`.

### 10.1 The phases

**Phase 1 — Inventory:** Glob and Grep the repo for signal files. Build an evidence list with file:line citations for every detected fact.

**Phase 2 — Classify:** For each evidence item, produce a structured classification entry with a `# source:` citation. Ambiguous signals list both alternatives and are marked `[NEEDS HUMAN INPUT]`.

**Phase 3 — Recommend skills:** Produce `recommended_skills.always`, `stack_specific`, and `not_applicable` lists based on detected stack.

**Phase 4 — Scaffold the project layer:** Copy every `shared/project/` file from `plugin/project-templates/` that does not already exist. Starter templates contain section headers and `[NEEDS HUMAN INPUT]` markers — never guessed content.

**Phase 5 — Write PROFILE.draft.md:** Write the complete PROFILE in the canonical YAML schema. Every field either has a detected value with source citation, or contains `[NEEDS HUMAN INPUT]`.

**Phase 6 — Generate project CLAUDE.md:** Reads recently modified source files, package.json scripts, any existing CONTRIBUTING.md or ADRs, and generates `shared/project/CLAUDE.md` with real content. Uncertain observations are marked `[VERIFY]`.

**Phase 7 — Handoff:** Prints a structured summary listing the draft file location, what was scaffolded vs skipped, detected stacks, orchestration fields needing human input, and the next steps (review draft, fill guidelines, rename to `PROFILE.md`, copy pipeline templates, commit).

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

Every field in the draft carries a `# source:` comment in the form `<file>:<line> (<evidence>)`. Fabricated facts are prohibited — if bootstrap cannot cite evidence, the field value is literally `[NEEDS HUMAN INPUT]`.

---

## 11. Adding a new skill

To add a new skill to the plugin (e.g., `performance-review`):

**Step 1 — Create the skill file:**

```bash
mkdir -p plugin/skills/performance-review
# Write the skill procedure in plugin/skills/performance-review/SKILL.md
```

The `SKILL.md` must include the frontmatter block, the load-order preamble (PROFILE → CLAUDE.md → overrides → guidelines → stacks), and the skill procedure. Follow the existing skills as templates.

**Step 2 — No path changes needed for protection:**

`conductor-scope-guard` already protects the `plugin/skills/*` pattern, so the new skill is automatically covered.

**Step 3 — No wrapper files needed:**

Both GitHub Copilot and Claude Code discover skills directly from `plugin/skills/<name>/SKILL.md` in the installed plugin. There is nothing else to write.

**Step 4 — Add a subagent if the skill needs one:**

If the new skill spawns a subagent (as `pr-review` spawns `code-reviewer`):

1. Write the full agent definition in `plugin/agents/<name>.md`.
2. Add the agent's scope to `plugin/scope-map.json`.

**Step 5 — Add to a workflow if pipeline-invoked:**

Add a new job to the relevant GitHub Actions workflow template (`plugin/project-templates/.github/workflows/`) or Azure Pipelines template (`plugin/project-templates/.azure-pipelines/`). Existing consuming projects need to re-copy the updated template — it is not retroactively updated by a plugin version bump, since it already lives in their repo as a human-owned file.

**Step 6 — Update the plugin manifests:**

Bump `version` in `plugin/.claude-plugin/plugin.json` and `marketplace.json`, and update the `capabilities.skills` count in `marketplace.json` and the skill/agent/bin tables in `plugin/README.md` and the root `README.md`.

---

## 12. Extending notifications or repo integrations

### 12.1 Adding a new notification type

Edit `plugin/bin/conductor-notify`. Add a new `case` branch for the new type name:

```bash
case "$notif_type" in
  slack)   # ... existing ...  ;;
  teams)   # ... existing ...  ;;
  webhook) # ... existing ...  ;;
  pagerduty)
    payload=$(jq -n --arg t "$msg" '{routing_key: $ROUTING_KEY, event_action: "trigger",
      payload: {summary: $t, severity: "info", source: "conductor"}}')
    curl -sS -X POST -H 'Content-Type: application/json' \
      --data "$payload" "https://events.pagerduty.com/v2/enqueue" >/dev/null
    echo "PagerDuty notification sent."
    ;;
esac
```

Update the PROFILE.md `orchestration.notifications.type` enum documentation in `plugin/project-templates/PROFILE.draft.md` to include the new option, so bootstrap reflects it.

### 12.2 Adding a new repo host

Edit `plugin/bin/conductor-create-pr`. Add a new `case` branch:

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

Also update the `PROFILE.draft.md` template so bootstrap can detect and set the new value, and update the detection logic in `plugin/skills/bootstrap-project/SKILL.md` (Phase 1, repo host detection) to recognize the new remote URL pattern.

---

## 13. Permissions model

| Actor | Scope | Secret location |
|---|---|---|
| ADO PAT (`ADO_PAT`) | Work items RW, code RW, build RW, PR RW | GitHub Actions secret / Azure Pipelines variable group |
| GitHub token (`GH_TOKEN` / `COPILOT_TOKEN`) | Repo contents write, PR write | GitHub Actions secret |
| Anthropic API key (`ANTHROPIC_API_KEY`) | Claude inference | GitHub Actions secret / Pipeline variable group |
| Notification webhook (`SLACK_WEBHOOK_URL`) | Post to one channel | GitHub Actions secret / Pipeline variable group |
| `GITHUB_TOKEN` | PR read, PR write comments | Auto-injected by Actions runner |

Agents running in CI execute with only the granted token's permissions. Branch policies on `master` require at least one human approval — agents cannot merge. The `conductor-scope-guard` hook prevents writing pipeline YAML even if an adversarial prompt tries to do so.

---

## 14. Observability

| Signal | Where it goes | Retention |
|---|---|---|
| Copilot/Claude stdout + stderr | Pipeline log and `copilot-output.log` / run-log build artifact | 90 days |
| Subagent return JSON | Embedded in feature PR description | PR lifetime |
| Notification message | Slack/Teams/webhook channel | Per channel retention |
| ADO work item comments | ADO | Forever |

Querying a run log locally after downloading the artifact:

```bash
grep -i error copilot-output.log
```

---

## 15. Cost model (rough)

| Stage | Tokens (rough) | Cost estimate |
|---|---|---|
| Design gen (`/requirements-analysis`) | ~80k in + 30k out | ~$2.50 |
| Contract-dev | ~20k in + 10k out | ~$0.20 |
| Backend-dev | ~120k in + 40k out | ~$1.50 |
| Frontend-dev | ~120k in + 40k out | ~$1.50 |
| PR review × 3 reviewers | ~60k in + 10k out each | ~$2.40 |
| **Total per typical story** | | **~$8** |

Double for complex stories, halve for simple ones. At 50 stories/week the bill is approximately $2k/month ± 50%. Use `maxTurns` / `--max-turns` caps in workflow files to bound worst-case spend.

---

## 16. Security considerations

**Prompt injection surface:** Work item descriptions, PR descriptions, and file contents all flow into the model context. The hook layer is the primary defence: `conductor-scope-guard` prevents exfiltration via file write, and subagent scope enforcement (backed by `plugin/scope-map.json`) prevents lateral movement between layers.

**Secret handling:** All secrets live in pipeline variable groups or GitHub Actions secrets, injected as environment variables. They are never written to files, never echoed in script output.

**PAT scope minimisation:** The ADO PAT is limited to one ADO project. Rotate quarterly. The GitHub token is scoped to `contents: write` and `pull-requests: write` only — it cannot modify Actions workflows.

**Merge discipline:** Branch policies on `master` require human approval. Agents can only open PRs and post comments. They cannot approve or merge.

**Master skill protection:** `conductor-scope-guard` blocks writes to `plugin/skills/**` and `plugin/agents/**`. Project customisation goes in `shared/project/` — never in the plugin itself.

**Bash guard:** `conductor-bash-guard` blocks `git push --force`, `git commit --no-verify`, and destructive `rm -rf` invocations before they execute.

**Data residency:** If using a hosted Anthropic endpoint (e.g. via Azure AI Foundry), configure the CLI to point at that endpoint. Run-log artifacts stay within the CI runner's retention boundary.

---

## 17. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| All skills abort with `"Run /bootstrap-project first."` | `shared/project/PROFILE.md` does not exist | Run `/bootstrap-project`, complete the checklist, rename `PROFILE.draft.md` → `PROFILE.md` |
| `/requirements-analysis` or other skill commands not found | The Conductor plugin was not installed for this session | Run `copilot plugin install --from https://github.com/deepu-roy/Conductor` or `claude plugin add --from ...` |
| Hook not running (macOS/Linux) | Plugin bin scripts not executable | Re-install the plugin; verify `plugin/bin/*` retained their executable bit in git (`git ls-files -s plugin/bin`) |
| Hook not running (Windows Git Bash) | Path uses forward slashes but Git Bash expects native paths | Set `MSYS_NO_PATHCONV=1` in Git Bash |
| Hook not running (Windows native) | `.sh`-style bash scripts cannot run natively | Use WSL2 (Option A) or Git Bash (Option B) |
| `"PROFILE.md not found; defaulting to github repo_host."` from `conductor-create-pr` | Bin tool called before `PROFILE.md` is activated | Rename `PROFILE.draft.md` → `PROFILE.md` after bootstrap review |
| `Unknown notification type: <x>` from `conductor-notify` | `orchestration.notifications.type` contains an unsupported value | Set to `slack`, `teams`, or `webhook` in PROFILE.md |
| `Unknown repo_host: <x>` from `conductor-create-pr` | `orchestration.repo_host` contains an unsupported value | Set to `github` or `azure-repos` in PROFILE.md |
| Scope block: `"Subagent 'backend-dev' has no declared scope covering apps/web/..."` | backend-dev attempted to write a frontend file — usually a prompt misunderstanding | Review subagent prompt. The subagent must return a blocker in its JSON summary, not edit out of scope |
| Merge conflict in `merge-and-pr` job | Scope violation — backend and frontend sub-branches touched the same file | Investigate which shared file was written by both subagents. Fix the `slices.md` file-scope declarations or the subagent prompts |
| Feature PR opened as draft unexpectedly | `verify-story` returned `ISSUES_FOUND` or `BLOCKED` | Read `docs/designs/WI-<id>/verification.md` for specific AC failures |
| Browser verification skipped | Chrome MCP not connected, or all slices are `layer: backend` only, or `skip_browser_verification: true` | Check the run log for the skip reason; connect Chrome MCP for local runs |
| ADO work item state not updated after merge | `post-merge.yml` could not parse `WI-<id>` from commit message | Ensure merge commit message contains `WI-<id>`; verify `ADO_PAT` secret is set and has work item write permission |
| Notification not sent after design PR | `conductor-notify` silently skipped (PROFILE.md not found or notification not configured) | Verify PROFILE.md exists and `orchestration.notifications.*` fields are filled in without `[NEEDS HUMAN INPUT]` |
| `yq: command not found` in CI | yq install step failed or was skipped | Verify the `Install tooling` step in the workflow ran successfully; yq binary path is `/usr/local/bin/yq` |
| `az devops login` fails | `ADO_PAT` secret not set or expired | Verify the secret in GitHub Actions settings; rotate the PAT if expired |
| Pipeline step exits 0 but no skill output produced | Copilot/Claude invocation received but the skill aborted due to missing PROFILE.md or malformed input | Check the `copilot-output.log` / run-log artifact; confirm `shared/project/PROFILE.md` is committed to the repo |
