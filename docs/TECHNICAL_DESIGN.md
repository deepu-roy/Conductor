# Technical Design — AI-Assisted SDLC

**Project codename:** AI-SDLC
**Version:** 1.0 (handover to Claude Code)
**Companion:** `FUNCTIONAL_DESIGN.md`

---

## 1. Component overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         AZURE DEVOPS                                │
│                                                                     │
│  Work Item (Epic/Feature) ──tag:ai:ready──> Service Hook            │
│                                                  │                  │
│                                                  ▼                  │
│                                         Pipeline: design-gen        │
│                                                  │                  │
│  Work Items (Tasks, children) <──── az boards ───┤                  │
│                                                  │                  │
│  PR: [Design] WI-<id> <──────── git/az repos ────┤                  │
│                                                                     │
│  Design PR merged ──────────────> Pipeline: implement-story         │
│                                                  │                  │
│  Feature PR (story/WI-<id>) <─── git/az repos ───┤                  │
│                                                                     │
│  PR opened ───────────────────> Pipeline: pr-review (3x parallel)   │
│                                                                     │
│  PR merged ───────────────────> Pipeline: post-merge cleanup        │
└─────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
                                 ┌───────────────┐
                                 │ Claude Code   │
                                 │ (headless)    │
                                 │   claude -p   │
                                 └───────┬───────┘
                                         │
           ┌─────────────┬────────────┬──┴──┬─────────────┬──────────┐
           ▼             ▼            ▼     ▼             ▼          ▼
      .claude/      .claude/    .claude/  .claude/    .claude/    .claude/
      skills/       agents/     hooks/    scripts/    project/    settings
      (master)      (sub-       (guard-   (CLI        (project    .json
                     agents)    rails)    wrappers)   layer)
```

## 2. Repository layout (actual paths)

```
<repo-root>/
├── .claude/
│   ├── CLAUDE.md                                # global policy
│   ├── settings.json                            # hook registrations
│   ├── mcp.json                                 # minimal (ideally empty)
│   ├── skills/                                  # MASTER — distributed as submodule/pkg
│   │   ├── bootstrap-project/SKILL.md
│   │   ├── requirements-analysis/SKILL.md
│   │   ├── technical-slicing/SKILL.md
│   │   ├── implement-story/SKILL.md             # orchestrator
│   │   ├── implement-slice/SKILL.md             # single-layer impl
│   │   ├── pr-review/SKILL.md
│   │   ├── security-review/SKILL.md
│   │   └── tech-debt-review/SKILL.md
│   ├── agents/
│   │   ├── contract-dev.md
│   │   ├── backend-dev.md
│   │   ├── frontend-dev.md
│   │   ├── code-reviewer.md
│   │   ├── security-auditor.md
│   │   └── tech-debt-auditor.md
│   ├── hooks/
│   │   ├── block-sensitive-files.sh             # PreToolUse — hard block
│   │   ├── scope-enforce.sh                     # PreToolUse — subagent boundary
│   │   ├── format-after-edit.sh                 # PostToolUse — deterministic format
│   │   └── trace-decisions.sh                   # append-only audit log
│   ├── scripts/
│   │   ├── ado-wi-show.sh
│   │   ├── ado-wi-create-slice.sh
│   │   ├── ado-wi-update.sh
│   │   ├── ado-pr-comment.sh
│   │   ├── slack-notify.sh
│   │   └── check-tech-agnostic.sh
│   └── project/                                 # OWNED BY PROJECT TEAM
│       ├── PROFILE.md                           # from bootstrap, confirmed
│       ├── CLAUDE.md                            # project policy overrides
│       ├── overrides/
│       │   ├── requirements-analysis.md
│       │   ├── technical-slicing.md
│       │   ├── implement-slice.md
│       │   ├── pr-review.md
│       │   └── security-review.md
│       ├── guidelines/
│       │   ├── coding-standards.md
│       │   ├── error-handling.md
│       │   ├── api-contracts.md
│       │   └── naming.md
│       └── stacks/                              # populated on demand
│           ├── react.md
│           └── dotnet.md
├── .azure-pipelines/
│   ├── design-gen.yml
│   ├── implement-story.yml
│   ├── pr-review.yml
│   └── post-merge.yml
└── docs/
    └── designs/
        └── WI-<id>/
            ├── functional.md
            ├── technical.md
            └── slices.md
```

## 3. Data flow — end to end

### 3.1 Stage 1–3 (design generation)

```
1. Work item tagged ai:ready
2. ADO Service Hook → POST webhook to pipeline
3. Pipeline checks out repo, az login via PAT
4. ClaudeCodeBaseTask runs:
     claude -p "/requirements-analysis <id>" \
       --output-format stream-json \
       --max-turns 30 \
       --allowed-tools "Read,Write,Bash(git:*),Bash(az:*),Bash(gh:*),Bash(curl:*)"
5. Skill procedure:
     5a. Read ADO work item          → az boards work-item show --id <id>
     5b. Load project layer          → Read PROFILE.md, CLAUDE.md, overrides, guidelines
     5c. Generate 3 design docs      → Write functional.md / technical.md / slices.md
     5d. Tech-agnostic check         → Bash: check-tech-agnostic.sh
     5e. Create child work items     → az boards work-item create (loop)
     5f. Commit + push + open PR     → git + az repos pr create
     5g. Notify Slack                → curl webhook
6. Pipeline archives claude-trace-<id>.jsonl.gz
```

### 3.2 Stage 4 (story implementation, parallel)

```
1. Design PR merged → ADO Service Hook → implement-story pipeline
2. Pipeline runs orchestrator:
     claude -p "/implement-story <id>" --max-turns 120
3. Orchestrator procedure:
     3a. Load slices.md, group by layer
     3b. If contract slice exists → spawn contract-dev (Task tool), wait
     3c. Spawn backend-dev + frontend-dev in parallel (Task tool)
     3d. Merge branches into story/WI-<id>
     3e. Run tests
     3f. Open feature PR
     3g. Update ADO work items to Resolved
     3h. Notify Slack
4. Subagent procedure (each):
     - Fork context, load scoped tools
     - Read only their assigned slice + PROFILE + overrides + relevant stacks/*
     - PreToolUse hook enforces file-path scope
     - Write code, write tests, run tests
     - Commit on own sub-branch
     - Return summary to orchestrator
```

### 3.3 Stage 5–6 (PR checks + review)

```
1. Feature PR opened → pr-review pipeline triggers
2. Three parallel jobs, one subagent each:
     - code-reviewer
     - security-auditor
     - tech-debt-auditor
3. Each subagent:
     - git diff origin/main...HEAD
     - Read CLAUDE.md + project layer
     - Post findings via az repos pr update --description + inline comments
     - Tag severity: blocker / major / minor / nit
4. Subagents never approve. Human approves.
5. On merge → post-merge pipeline updates ADO + Slack
```

## 4. Master skill — specifications

### 4.1 bootstrap-project

| Attribute | Value |
|---|---|
| Trigger | Human: `claude -p "/bootstrap-project"` |
| Invocation | `disable-model-invocation: true` (humans only) |
| Tools | Read, Write, Glob, Grep, Bash(git:*), Bash(ls:*), Bash(cat:*), Bash(find:*) |
| Produces | `shared/project/PROFILE.draft.md` + skeleton `guidelines/`, `stacks/`, `overrides/` placeholders |
| Must not | Commit, push, edit master skills, write `PROFILE.md` (only `.draft.md`) |

Detection matrix:

| Signal file | Infers |
|---|---|
| `package.json` with `react` dep | Frontend framework: React; check for Next, Vite |
| `package.json` with `@angular/core` | Frontend framework: Angular |
| `*.csproj`, `global.json` | Backend: .NET; version from TargetFramework |
| `pyproject.toml`, `requirements.txt` | Backend: Python |
| `go.mod` | Backend: Go |
| `pom.xml`, `build.gradle*` | Backend: JVM |
| `angular.json`, `nx.json`, `pnpm-workspace.yaml`, `lerna.json` | Monorepo |
| `.azure-pipelines/`, `azure-pipelines.yml` | CI: Azure Pipelines |
| `.github/workflows/` | CI: GitHub Actions |
| `vitest.config.*`, `jest.config.*` | JS test framework |
| `tests/*Tests.csproj`, `xunit` refs | .NET test framework |
| `Dockerfile*`, `docker-compose*` | Container present |
| `infra/*.bicep`, `*.tf`, `helm/` | IaC tool |

### 4.2 requirements-analysis

| Attribute | Value |
|---|---|
| Trigger | Pipeline: `/requirements-analysis <work-item-id>` |
| Tools | Read, Write, Bash(git:*), Bash(az:*), Bash(gh:*), Bash(curl:*) |
| Produces | `docs/designs/WI-<id>/{functional,technical,slices}.md` + child work items + design PR + Slack post |
| Policy | Tech-agnostic functional doc (blocklist enforced via `check-tech-agnostic.sh`); every claim cites source |

Tech-agnostic blocklist (grep'd):

```
OAuth, JWT, REST, GraphQL, gRPC, PostgreSQL, MySQL, Redis, MongoDB,
React, Angular, Vue, Next, Svelte, Kubernetes, Docker, AWS, Azure
(as cloud service), Lambda, S3, Cosmos, RabbitMQ, Kafka
```

These are permitted in `technical.md`, banned in `functional.md`. The check script exits non-zero on violations.

### 4.3 technical-slicing

Chained from `requirements-analysis`. Same trigger, same run.

| Attribute | Value |
|---|---|
| Output | `slices.md` with YAML schema (see 4.3.1); one ADO Task per slice |
| Rules | One slice = one PR-sized unit; disjoint file scopes between parallel slices; every slice has measurable AC, impact, risk, test plan |

#### 4.3.1 Slice schema

```yaml
slices:
  - id: S1
    title: <short imperative title>
    layer: contract | backend | frontend | infra
    files:                           # explicit — enforced by scope hook
      - path: <glob or exact>
        access: read-write | read-only
    depends_on: [S0]                 # other slice IDs, must be empty for parallel start
    parallel_with: [S2, S3]          # declared parallelism
    acceptance:                      # Given/When/Then
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

### 4.4 implement-story (orchestrator)

| Attribute | Value |
|---|---|
| Trigger | Pipeline: `/implement-story <work-item-id>` |
| Tools | Task, Read, Write, Bash(git:*), Bash(gh:*), Bash(az:*), Bash(curl:*) |
| Produces | Single feature PR on `story/WI-<id>`; updated ADO work items; Slack summary |
| Rules | Never writes feature code itself; delegates to subagents; aborts on contract ambiguity |

### 4.5 implement-slice (single-slice fallback)

Used when a story has only one slice, or a subagent is operating on a single slice. Same output shape: a commit on a sub-branch.

### 4.6 pr-review / security-review / tech-debt-review

All three share a pattern:

| Attribute | Value |
|---|---|
| Trigger | Pipeline: one subagent per skill |
| Tools | Read, Grep, Bash(git:*), Bash(az:*) |
| Output | PR comments only; no writes to code; no approvals |
| Severity | blocker / major / minor / nit — enforced by the CLAUDE.md rules the skill references |

## 5. Subagent contracts

Every subagent definition file (`.claude/agents/<name>.md`) includes the required frontmatter:

```yaml
---
name: <kebab-case>
description: <one sentence, used by Task tool for auto-delegation>
tools: [<tight whitelist>]
context: fork                # forks context; never shares main context
---
```

### 5.1 File-scope enforcement

The `scope-enforce.sh` hook is attached per subagent via settings. It reads the subagent name from the hook input (`transcript_path` or environment) and:

1. Loads the subagent's declared scope from a lookup table (in `.claude/agents/scope-map.json`).
2. Parses `.tool_input.file_path` from the hook payload.
3. Exits 0 if in scope, 2 (block) with a clear reason if out of scope.
4. Logs every check to `.claude/trace/scope-<timestamp>.log`.

Example `scope-map.json`:

```json
{
  "backend-dev": {
    "read_write": ["apps/api/**", "tests/api/**"],
    "read_only":  ["contracts/**", "shared/project/**"],
    "denied":     ["apps/web/**", ".azure-pipelines/**", "*.env", "*.pem"]
  },
  "frontend-dev": {
    "read_write": ["apps/web/**", "tests/web/**"],
    "read_only":  ["contracts/**", "shared/project/**"],
    "denied":     ["apps/api/**", ".azure-pipelines/**", "*.env", "*.pem"]
  },
  "contract-dev": {
    "read_write": ["contracts/**"],
    "read_only":  ["docs/designs/**", "shared/project/**"],
    "denied":     ["apps/**", ".azure-pipelines/**", "*.env", "*.pem"]
  }
}
```

### 5.2 Subagent return contract

Every subagent ends its run with a JSON block the orchestrator parses:

```json
{
  "subagent": "backend-dev",
  "slices_implemented": ["S2", "S4"],
  "branch": "story/WI-1234/backend",
  "commit_sha": "abc123...",
  "tests": { "unit": "passed", "integration": "passed" },
  "files_touched": ["apps/api/..."],
  "blockers": [],
  "questions": []
}
```

If `blockers` or `questions` is non-empty, orchestrator does not proceed — it opens a draft PR with these surfaced at the top.

## 6. Hooks — specifications

### 6.1 block-sensitive-files.sh (PreToolUse, all subagents + main)

Blocks: `*.env`, `*.pem`, `*.key`, `*secrets*`, `.azure-pipelines/*.yml`, `.github/workflows/*.yml`, `shared/skills/*` (master skills are read-only from the model's perspective).

```bash
#!/usr/bin/env bash
set -euo pipefail
payload=$(cat)
file=$(echo "$payload" | jq -r '.tool_input.file_path // empty')
[[ -z "$file" ]] && exit 0
case "$file" in
  *.env|*.pem|*.key|*secrets*|*secret.*|*.p12|*.pfx)
    echo "BLOCKED: $file is a secret file." >&2; exit 2 ;;
  */.azure-pipelines/*|*/.github/workflows/*)
    echo "BLOCKED: $file is pipeline config. Infra edits require human author." >&2; exit 2 ;;
  */shared/skills/*)
    echo "BLOCKED: $file is a master skill. Customize via shared/project/ instead." >&2; exit 2 ;;
esac
exit 0
```

### 6.2 scope-enforce.sh (PreToolUse, subagent-scoped)

See 5.1. Uses `jq` + glob matching (bash `extglob` or `find` fallback).

### 6.3 format-after-edit.sh (PostToolUse on Edit|Write)

Runs project-configured formatter. Reads `shared/project/PROFILE.md` for the command (e.g. `pnpm prettier --write`, `dotnet format`). Silent on success; logs on failure; never fails the overall turn.

### 6.4 trace-decisions.sh (PostToolUse, every tool)

Appends one JSON line per tool call to `.claude/trace/<run-id>.jsonl`. Pipeline archives the file as build artifact.

## 7. Scripts — CLI wrappers

Every script is idempotent where possible, exits non-zero on failure, and logs to stderr.

### 7.1 ado-wi-show.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
az boards work-item show --id "$1" --output json
```

### 7.2 ado-wi-create-slice.sh

```bash
#!/usr/bin/env bash
# usage: ado-wi-create-slice.sh <parent-id> <slice-yaml-file>
set -euo pipefail
parent="$1"; yaml="$2"
title=$(yq -r '.title' "$yaml")
body=$(cat "$yaml")
az boards work-item create \
  --type "Task" \
  --title "$title" \
  --description "$body" \
  --fields "System.Parent=$parent" \
  --output json
```

### 7.3 ado-pr-comment.sh

```bash
#!/usr/bin/env bash
# usage: ado-pr-comment.sh <pr-id> <thread-status> <comment-file>
set -euo pipefail
pr="$1"; status="$2"; body_file="$3"
az repos pr thread create \
  --pull-request-id "$pr" \
  --comments "$(cat "$body_file")" \
  --status "$status" \
  --output json
```

### 7.4 slack-notify.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
: "${SLACK_WEBHOOK_URL:?}"
msg="$*"
curl -sS -X POST -H 'Content-type: application/json' \
  --data "$(jq -n --arg t "$msg" '{text:$t}')" \
  "$SLACK_WEBHOOK_URL" >/dev/null
```

### 7.5 check-tech-agnostic.sh

Grep blocklist against a file. Non-zero exit on any hit.

## 8. Pipelines — specifications

### 8.1 design-gen.yml

- Trigger: webhook from ADO Service Hook on `WorkItemUpdated` where `tags` contains `ai:ready`.
- Inputs: `workItemId` (from webhook payload).
- Steps: checkout → `az login` → `ClaudeCodeBaseTask@1` with `/requirements-analysis <id>` → archive trace.
- Token budget: `--max-turns 30`.
- Model: Opus (design quality matters most here).

### 8.2 implement-story.yml

- Trigger: webhook on PR merged where source branch matches `design/WI-*`.
- Inputs: `workItemId` (parsed from branch name).
- Steps: checkout → `az login` → ClaudeCodeBaseTask with `/implement-story <id>`.
- Token budget: `--max-turns 120`.
- Model: Sonnet (bulk of work is mechanical implementation; orchestrator's decisions are short).
- Timeout: 90 minutes.

### 8.3 pr-review.yml

- Trigger: PR opened or updated on `main`.
- Strategy: matrix, 3 parallel jobs (code, security, debt).
- Steps: checkout → `az login` → ClaudeCodeBaseTask invoking the three subagents.
- Token budget: `--max-turns 40` per reviewer.
- Model: Sonnet (review); Haiku for tech-debt review if cost pressure is high.

### 8.4 post-merge.yml

- Trigger: PR merged to `main`.
- Steps: `az boards work-item update --id <id> --state Closed`; `slack-notify.sh "Merged WI-<id>"`.
- No Claude invocation. Pure bash.

## 9. Permissions model

| Actor | Scope | Secret |
|---|---|---|
| ADO PAT (`ADO_PAT`) | Work items RW, code RW, build RW, PR RW | Pipeline library, not in repo |
| Anthropic API key (`ANTHROPIC_API_KEY`) | Claude inference | Pipeline library |
| Slack webhook (`SLACK_WEBHOOK_URL`) | Post to one channel | Pipeline library |
| Service connection `ado-service-hook` | Webhook ingress | ADO project admin |
| Branch policy on `main` | Require 1 human approval, require PR build to pass | ADO project admin |
| Branch policy on `design/**` | Require 1 human approval | ADO project admin |

Claude running in the pipeline executes with **only** the PAT's permissions. It cannot `git push --force`, cannot delete branches (disabled by branch policy), cannot edit pipelines (blocked by hook).

## 10. Observability

| Signal | Where it goes | Retention |
|---|---|---|
| `stream-json` traces | Pipeline artifact `claude-trace` | 90 days |
| Hook block events | `.claude/trace/blocks-<date>.log` committed by post-merge only if non-empty | Forever (git) |
| Subagent return JSON | Pipeline log + attached to PR description | PR lifetime |
| Slack thread | Slack channel | Per Slack retention |
| ADO work item comments | ADO | Forever |

Dashboards are phase 2. For v1, `jq` over archived traces is enough.

## 11. Cost model (rough)

Based on Apr 2026 Anthropic pricing for a medium story:

| Stage | Model | Tokens (rough) | Cost estimate |
|---|---|---|---|
| Design gen (stages 1-3) | Opus | ~80k in + 30k out | ~$3 |
| Impl — contract-dev | Sonnet | ~20k in + 10k out | ~$0.20 |
| Impl — backend-dev | Sonnet | ~120k in + 40k out | ~$1.50 |
| Impl — frontend-dev | Sonnet | ~120k in + 40k out | ~$1.50 |
| PR review x3 | Sonnet | ~60k in + 10k out each | ~$2.40 |
| **Total per story** | | | **~$8–10** |

Double this for complex stories. Halve it for simple ones. At 50 stories/week the bill is $2k/month ± 50%.

## 12. Security considerations

- **Prompt injection surface:** work item descriptions, PR descriptions, file contents. The `critical_injection_defense` already baked into Claude Code's behaviour is the first line. The hook layer is the second: block-sensitive-files prevents exfiltration via file read, scope-enforce prevents lateral movement.
- **Secret handling:** all secrets live in pipeline variable groups, injected as env vars. Never written to files. Never echoed to logs (pipeline masks).
- **PAT scope minimization:** the PAT is limited to one ADO project. Rotate quarterly.
- **Merge discipline:** branch policies on `main` and `design/**` require human approval. Claude cannot merge.
- **Audit:** every tool call is logged. Every blocked call is preserved.
- **Data residency:** if using Microsoft Foundry instead of public Anthropic API, configure the `ClaudeCodeBaseTask` to point at the Foundry endpoint. Trace data stays in your Azure tenant.

## 13. Extension model

Adding a new stack (e.g. Python backend):

1. Add detection rules to `bootstrap-project/SKILL.md`.
2. Add `stacks/python.md` as a scaffold (can be empty at first).
3. Add a new subagent `python-backend-dev.md` if the stack deserves its own scope.
4. Update `scope-map.json`.

Adding a new review dimension (e.g. performance review):

1. New master skill `shared/skills/performance-review/SKILL.md`.
2. New subagent `.claude/agents/performance-auditor.md`.
3. Add to `pr-review.yml` matrix.

Adding a new CI (e.g. GitHub Actions):

1. Copy `.azure-pipelines/*.yml` shape into `.github/workflows/`.
2. Replace `az` calls with `gh` where applicable (most calls become `gh api` or `gh pr create`).
3. Everything else is identical — Claude Code is CI-agnostic.

## 14. Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| ADO MCP/CLI version drift | Medium | Breaks automation | Pin `az devops` extension version in pipeline |
| Claude-generated tests are vacuous | Medium | Merged code without real coverage | Mutation testing on a random sample of merged PRs; CLAUDE.md rule against single-assertion tests |
| Subagent crosses file boundary | Low | Merge conflict, wrong attribution | scope-enforce.sh hook; merge conflict triggers human review |
| Prompt injection from work item | Low | Data leak attempt | Critical injection defense + file-block hook |
| Token cost overrun | Medium | Budget surprise | `--max-turns` caps + pipeline-level cost alert |
| Master skills upgrade breaks project layer | Medium | Regression | Versioned master skill pack; per-project pin; changelog + release notes |
| Too many reviewer comments | High | Review fatigue | Severity threshold; noise reduction via "only blocker/major appear inline; minor/nit go in a summary comment" |

## 15. Definition of done for v1

- `/bootstrap-project` runs cleanly on three distinct repos (React/.NET, Angular/Node, Python-only).
- A tagged work item produces a design PR with tech-agnostic functional doc, non-empty technical doc, and at least two well-formed slices within 10 minutes.
- A merged design PR produces a feature PR on `story/WI-<id>` with passing unit + integration tests.
- The feature PR has three review subagent comments within 5 minutes of opening.
- Zero auto-merges. Zero writes to blocked paths.
- Full trace archive exists per pipeline run.
- Pilot team reports tag-to-merge under two hours for three consecutive typical stories.
