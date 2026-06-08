# AI-SDLC Plugin

AI-assisted SDLC pipeline — from tagged work item to merged PR, with human gates at every decision point.

A PM tags an ADO work item `ai:ready`. The pipeline generates a design PR (functional spec, technical spec, slice plan). A human reviews and merges. The pipeline implements every slice, opens a feature PR, runs three parallel review agents (code quality, security, tech debt), and waits for a human to merge.

Works with both **Claude Code** and **GitHub Copilot**. Same skills, agents, hooks, and CLI tools in both environments.

---

## Table of contents

- [Installation](#installation)
- [Quick start](#quick-start)
- [Post-install setup checklist](#post-install-setup-checklist)
- [What's included](#whats-included)
- [How it works](#how-it-works)
- [Pipeline setup](#pipeline-setup)
- [MCP servers](#mcp-servers)
- [CLI prerequisites](#cli-prerequisites)
- [PROFILE.md reference](#profilemd-reference)
- [Normal workflow](#normal-workflow)
- [Project structure after setup](#project-structure-after-setup)
- [Safety model](#safety-model)
- [Windows setup](#windows-setup)
- [Detailed docs](#detailed-docs)

---

## Installation

The plugin format is cross-tool compatible — the same plugin works in **Claude Code**, **GitHub Copilot (VS Code)**, and **GitHub Copilot CLI**.

### GitHub Copilot (VS Code) — from source (Preview)

> Agent plugins in VS Code are currently in Preview. Enable with the `chat.plugins.enabled` setting.

1. Open the Command Palette (`⇧⌘P` / `Ctrl+Shift+P`)
2. Run **Chat: Install Plugin From Source**
3. Enter the repository URL:
   ```
   https://github.com/deepu-roy/ai-sdlc-orchestrator
   ```

The plugin appears in the **Agent Plugins - Installed** view in the Extensions sidebar. Skills, agents, hooks, and CLI tools are immediately available in chat.

### GitHub Copilot (VS Code) — local plugin

If you cloned the repo locally, register it via VS Code settings:

```jsonc
// settings.json
"chat.pluginLocations": {
    "/path/to/ai-sdlc-orchestrator/plugin": true
}
```

### GitHub Copilot CLI

```bash
copilot plugin install --from https://github.com/deepu-roy/ai-sdlc-orchestrator
```

Plugins installed via the CLI are auto-discovered by VS Code from `~/.copilot/installed-plugins/`.

### Claude Code — from GitHub

```bash
claude plugin add --from https://github.com/deepu-roy/ai-sdlc-orchestrator
```

### Claude Code — from local clone

```bash
git clone https://github.com/deepu-roy/ai-sdlc-orchestrator.git
claude plugin add --from ./ai-sdlc-orchestrator/plugin
```

> **Cross-tool note:** VS Code auto-detects the plugin format by finding `.claude-plugin/plugin.json`. The same plugin directory works in all three tools without modification.

---

## Quick start

### 1. Install the plugin

**VS Code (Copilot):** Command Palette → `Chat: Install Plugin From Source` → enter `https://github.com/deepu-roy/ai-sdlc-orchestrator`

**Claude Code:**
```bash
claude plugin add --from https://github.com/deepu-roy/ai-sdlc-orchestrator
```

### 2. Run bootstrap in your target repo

```bash
cd /path/to/your-project
claude -p "/bootstrap-project"
```

Bootstrap scans your repo, detects the tech stack, and generates:

- `shared/project/PROFILE.draft.md` — project configuration (you fill this in)
- `shared/project/CLAUDE.md` — project-level policy overrides
- `shared/project/guidelines/` — coding standards, error handling, naming, API contracts
- `shared/project/stacks/` — stack-specific configuration (populated on demand)
- `shared/project/overrides/` — per-skill behavior overrides

### 3. Fill in `PROFILE.draft.md`

```bash
$EDITOR shared/project/PROFILE.draft.md
```

Replace every `[NEEDS HUMAN INPUT]` entry. The most critical section is `orchestration`:

```yaml
orchestration:
  pipeline_tool: github-actions   # github-actions | azure-pipelines
  repo_host: github               # github | azure-repos
  work_items:
    source: ado
    org_url: https://dev.azure.com/myorg
    project: MyProject
  notifications:
    type: slack                   # slack | teams | webhook
    webhook_url: https://hooks.slack.com/services/...
    channel: "#engineering"
```

Also fill in `gates` (compile, test, lint commands), `stacks` (framework details), and `quarantined_paths` (files AI should never touch).

### 4. Activate the profile

```bash
mv shared/project/PROFILE.draft.md shared/project/PROFILE.md
```

All AI-SDLC skills will abort with a helpful error until `PROFILE.md` exists.

### 5. Copy pipeline templates

The plugin ships pipeline templates in `project-templates/`. Copy the ones matching your CI:

**Azure Pipelines:**
```bash
cp -r shared/project-templates/.azure-pipelines ./.azure-pipelines
```

**GitHub Actions:**
```bash
cp -r shared/project-templates/.github/workflows ./.github/workflows
```

### 6. Wire up secrets and triggers

See [Pipeline setup](#pipeline-setup) below.

### 7. Tag a work item `ai:ready`

The pipeline takes it from there.

---

## Post-install setup checklist

After installing the plugin and running bootstrap, complete these steps:

### Required

| Step | What to do |
|------|------------|
| **Fill in PROFILE.md** | Replace all `[NEEDS HUMAN INPUT]` entries in `shared/project/PROFILE.draft.md`, then rename to `PROFILE.md` |
| **Install `az` CLI** | Required for ADO work item integration. Install the `azure-devops` extension: `az extension add --name azure-devops` |
| **Install `gh` CLI** | Required if `repo_host: github`. Install from [cli.github.com](https://cli.github.com) |
| **Install `jq`** | Required by all CLI scripts. `brew install jq` (macOS) or `apt install jq` (Linux) |
| **Install `yq`** | Required for YAML parsing. `brew install yq` (macOS) or `snap install yq` (Linux) |
| **Set up pipelines** | Copy pipeline templates and configure CI triggers (see [Pipeline setup](#pipeline-setup)) |
| **Configure secrets** | Add API keys and tokens to your CI secret store (see [Pipeline setup](#pipeline-setup)) |
| **Set up notifications** | Create a Slack/Teams incoming webhook and add the URL to PROFILE.md and CI secrets |

### Required for browser verification (`verify-story` skill)

| Step | What to do |
|------|------------|
| **Install Chrome MCP** | The `verify-story` skill drives a real Chrome browser via MCP to verify acceptance criteria |
| **Configure MCP** | Add the Chrome MCP server to `.claude/mcp.json` in your project |

Example `.claude/mcp.json`:

```json
{
  "mcpServers": {
    "chrome": {
      "command": "npx",
      "args": ["@anthropic-ai/chrome-mcp"]
    }
  }
}
```

### Optional but recommended

| Step | What to do |
|------|------------|
| **Fill in guidelines** | Edit files in `shared/project/guidelines/` with your team's conventions |
| **Fill in stack files** | Add stack-specific rules to `shared/project/stacks/` |
| **Add skill overrides** | Create files in `shared/project/overrides/<skill-name>.md` to customize behavior |
| **Configure branch policies** | Require 1 human reviewer and passing status checks on `main` and `design/**` branches |
| **Set up ADO service hook** | For push-based triggers instead of polling (Azure Pipelines only) |

---

## What's included

### Skills (10)

| Skill | Purpose |
|-------|---------|
| `bootstrap-project` | One-time project onboarding — detects stack, generates PROFILE.draft.md |
| `requirements-analysis` | Converts ADO work item into functional.md + technical.md + slices.md, creates child tasks, opens design PR |
| `update-functional` | Updates functional design docs from revised requirements |
| `technical-slicing` | Breaks a technical design into implementable vertical slices |
| `implement-story` | Orchestrates full story implementation — delegates to subagents, enforces file scopes |
| `implement-slice` | Implements a single vertical slice (contract → backend → frontend) |
| `pr-review` | Automated PR review — posts comments, never approves |
| `security-review` | OWASP Top 10 + LLM-specific security audit |
| `tech-debt-review` | Duplication, coupling, test coverage audit |
| `verify-story` | Drives Chrome via MCP to verify acceptance criteria in a real browser |

### Agents (6)

| Agent | Role | File scope |
|-------|------|------------|
| `backend-dev` | Server code, data layer, business logic | `apps/api/**`, `apps/server/**` |
| `frontend-dev` | UI components, client state, tests | `apps/web/**`, `apps/client/**` |
| `contract-dev` | API contracts (OpenAPI, GraphQL, shared types) | `contracts/**` |
| `code-reviewer` | Code correctness and standards review | Read-only |
| `security-auditor` | OWASP, injection, secrets, auth review | Read-only |
| `tech-debt-auditor` | Duplication, coupling, test gap review | Read-only |

File scopes are enforced by `scope-map.json` and the scope-guard hook. Agents cannot write outside their boundaries.

### CLI tools (11)

All prefixed with `ai-sdlc-` and automatically available on PATH when the plugin is active.

| Command | Purpose |
|---------|---------|
| `ai-sdlc-wi-show` | Fetch work item details from ADO |
| `ai-sdlc-wi-update` | Update work item state/fields |
| `ai-sdlc-wi-create-slice` | Create child task work item from a slice |
| `ai-sdlc-create-pr` | Create PR on GitHub or Azure Repos |
| `ai-sdlc-pr-comment` | Post a comment on a PR |
| `ai-sdlc-notify` | Send notification via Slack, Teams, or generic webhook |
| `ai-sdlc-check-compile` | Run the compile gate from PROFILE.md |
| `ai-sdlc-check-startup` | Run the startup healthcheck gate |
| `ai-sdlc-check-tech-agnostic` | Verify functional docs contain no tech-specific terms |
| `ai-sdlc-scope-guard` | Block writes to protected paths |
| `ai-sdlc-bash-guard` | Block dangerous shell operations (`--force`, `--no-verify`, `rm -rf`) |

### Hooks (2)

| Hook | Event | Purpose |
|------|-------|---------|
| Scope guard | `PostToolUse` (Write/Edit) | Prevents writes to pipeline YAML, secrets, env files, master skills |
| Bash guard | `PreToolUse` (Bash) | Blocks `git push --force`, `git commit --no-verify`, destructive commands |

### Project templates

Copied into your repo by `bootstrap-project`:

| Template | Purpose |
|----------|---------|
| `PROFILE.draft.md` | Project configuration — stack, orchestration, gates |
| `CLAUDE.md` | Project-level policy overrides |
| `guidelines/` | Coding standards, error handling, naming, API contracts |
| `overrides/` | Per-skill behavior customization |
| `stacks/` | Stack-specific configuration files |
| `.azure-pipelines/` | Azure Pipelines YAML templates (4 pipelines) |
| `.github/workflows/` | GitHub Actions workflow templates (5 workflows) |

---

## How it works

```
ADO work item tagged ai:ready
        │
        ▼
┌─────────────────────────────────────────────────┐
│  Stage 1: Design generation                     │
│  requirements-analysis → functional.md,         │
│  technical.md, slices.md, child ADO tasks        │
│         │                                       │
│         ▼                                       │
│  Design PR ◄── human reviews & merges           │
│         │                                       │
│         ▼                                       │
│  Stage 2: Implementation                        │
│  implement-story orchestrator                   │
│    ├── contract-dev (first, alone)              │
│    ├── backend-dev  ─┐                          │
│    └── frontend-dev ─┘ (parallel, scoped)       │
│         │                                       │
│         ▼                                       │
│  Feature PR ◄── human reviews & merges          │
│         │                                       │
│         ▼                                       │
│  Stage 3: Automated review                      │
│    ├── code-reviewer    ─┐                      │
│    ├── security-auditor ─┤ (parallel, comments) │
│    └── tech-debt-auditor─┘                      │
│         │                                       │
│         ▼                                       │
│  Human approves & merges                        │
│         │                                       │
│         ▼                                       │
│  Post-merge: ADO work items closed, notified    │
└─────────────────────────────────────────────────┘
```

**Key principle:** AI proposes, humans decide. No automated merges. No auto-approvals.

---

## Pipeline setup

### Azure Pipelines

**1. Create CI secrets** — Project Settings → Pipelines → Library → create variable group `ai-sdlc-secrets`:

| Variable | Type | Value |
|----------|------|-------|
| `ANTHROPIC_API_KEY` | secret | Anthropic API key |
| `ADO_PAT` | secret | PAT with Work Items RW, Code RW, Build RW |
| `SLACK_WEBHOOK_URL` | secret | Slack/Teams incoming webhook URL |

**2. Create four pipelines**, each pointing at its YAML:

| Pipeline name | YAML file |
|---------------|-----------|
| `design-gen` | `.azure-pipelines/design-gen.yml` |
| `implement-story` | `.azure-pipelines/implement-story.yml` |
| `pr-review` | `.azure-pipelines/pr-review.yml` |
| `post-merge` | `.azure-pipelines/post-merge.yml` |

**3. Wire the ADO service hook** — Project Settings → Service Hooks → New:

- Type: `Work item updated`
- Filter: `Tags` contains `ai:ready`
- Action: Trigger pipeline `design-gen`, pass `workItemId`

**4. Set branch policies** on `main` and `design/**`:

- Require 1 human reviewer
- Require PR build to pass
- Prevent direct pushes

### GitHub Actions

**1. Create secrets** — Settings → Secrets and variables → Actions:

| Secret | Value |
|--------|-------|
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `ADO_PAT` | PAT with Work Items RW, Code RW |
| `GH_TOKEN` | GitHub token with repo + PR write scope |
| `SLACK_WEBHOOK_URL` | Slack/Teams incoming webhook URL |

**2. Workflows** are already in `.github/workflows/`:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ado-poller.yml` | Cron (every 5 min) | Polls ADO for `ai:ready` items, dispatches `design-gen` |
| `design-gen.yml` | `workflow_dispatch` | Runs requirements-analysis, opens design PR |
| `implement-story.yml` | Design PR merge | Orchestrates implementation, opens feature PR |
| `pr-review.yml` | Feature PR opened | Runs 3 parallel reviewers |
| `post-merge.yml` | Feature PR merge | Closes ADO items, sends notification |

**3. Set branch protection** on `main` and `design/**`:

- Require 1 approving review
- Require status checks to pass
- Restrict pushes to main

---

## MCP servers

The plugin is primarily CLI-first — most integrations use `az`, `gh`, `git`, and `curl`. MCP is used only where no stable CLI exists.

### Required MCP: Chrome (for `verify-story` only)

The `verify-story` skill drives a real Chrome browser to verify acceptance criteria. Add to `.claude/mcp.json`:

```json
{
  "mcpServers": {
    "chrome": {
      "command": "npx",
      "args": ["@anthropic-ai/chrome-mcp"]
    }
  }
}
```

### Optional MCP: Azure DevOps

If your environment has the Azure DevOps MCP server available, it can supplement the `az` CLI for richer work item interactions. The plugin works without it — all ADO operations fall back to the `az boards` CLI.

---

## CLI prerequisites

Install these tools before running any AI-SDLC skills:

```bash
# Azure CLI + DevOps extension (required for ADO work items)
brew install azure-cli              # macOS
az extension add --name azure-devops
az login
az devops configure --defaults organization=https://dev.azure.com/myorg project=MyProject

# GitHub CLI (required if repo_host: github)
brew install gh                     # macOS
gh auth login

# JSON/YAML processing (required by all scripts)
brew install jq yq                  # macOS

# Claude Code (required for running skills locally)
npm install -g @anthropic-ai/claude-code
```

**Linux equivalents:**
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az extension add --name azure-devops
sudo apt install jq
sudo snap install yq
```

**Verify installation:**
```bash
az version && gh version && jq --version && yq --version && claude --version
```

---

## PROFILE.md reference

The `shared/project/PROFILE.md` file is the single configuration backbone. Every skill reads it first and aborts if it's missing. Key sections:

| Section | Controls |
|---------|----------|
| `project` | Repo name, type (frontend/backend/fullstack), repo kind (single/monorepo) |
| `orchestration` | Pipeline tool, repo host, ADO org/project, notification config |
| `stacks` | Frontend/backend/contract/infra framework details |
| `gates` | Commands for compile, test, lint, format, startup, healthcheck |
| `quarantined_paths` | Paths AI must never auto-implement (requires human pairing) |
| `recommended_skills` | Which skills apply to this project |
| `conventions_detected` | Auto-detected conventions with file:line citations |

Skills resolve configuration in this precedence order (highest wins):

1. `shared/project/overrides/<skill-name>.md`
2. `shared/project/CLAUDE.md`
3. `shared/project/guidelines/*.md`
4. Global tool policy

---

## Normal workflow

Once setup is complete, the day-to-day flow is:

1. **PM creates a work item** in ADO with a clear description and tags it `ai:ready`.
2. **`design-gen` pipeline fires** — generates `functional.md`, `technical.md`, `slices.md`, creates child ADO Tasks, opens a design PR.
3. **Tech lead reviews the design PR** — edits slice YAML if needed, merges when satisfied.
4. **`implement-story` fires on merge** — runs `contract-dev` first, then `backend-dev` and `frontend-dev` in parallel with enforced file scopes. Opens a feature PR.
5. **`pr-review` fires on the feature PR** — three agents post review comments in parallel (no approvals).
6. **Human reviews, iterates, merges.**
7. **`post-merge` closes ADO work items** and sends a summary notification.

### Running skills manually (local development)

```bash
# Analyze a work item
claude -p "/requirements-analysis 12345"

# Re-slice an existing design
claude -p "/technical-slicing 12345"

# Implement a story
claude -p "/implement-story 12345"

# Review a PR
claude -p "/pr-review 42"

# Verify story in browser
claude -p "/verify-story 12345"

# Security audit
claude -p "/security-review 42"
```

---

## Project structure after setup

After running `bootstrap-project` and setting up pipelines, your repo will have:

```
<your-repo>/
├── shared/
│   └── project/                     ← YOUR configuration (edit freely)
│       ├── PROFILE.md               ← activated config backbone
│       ├── CLAUDE.md                ← project policy overrides
│       ├── guidelines/
│       │   ├── coding-standards.md
│       │   ├── error-handling.md
│       │   ├── api-contracts.md
│       │   └── naming.md
│       ├── overrides/               ← per-skill customization
│       │   └── verify-story.md
│       └── stacks/                  ← stack-specific rules
│
├── docs/
│   └── designs/
│       └── WI-<id>/                 ← generated per work item
│           ├── functional.md
│           ├── technical.md
│           └── slices.md
│
├── .azure-pipelines/                ← if using Azure Pipelines
│   ├── design-gen.yml
│   ├── implement-story.yml
│   ├── pr-review.yml
│   └── post-merge.yml
│
└── .github/workflows/               ← if using GitHub Actions
    ├── ado-poller.yml
    ├── design-gen.yml
    ├── implement-story.yml
    ├── pr-review.yml
    └── post-merge.yml
```

The plugin's skills, agents, hooks, and CLI tools are managed by the plugin system — they are **not** copied into your repo.

---

## Safety model

- **No auto-merge.** Agents post comments only. Humans approve and merge all PRs.
- **Scope enforcement.** The `scope-map.json` defines per-agent file boundaries. The scope-guard hook blocks writes outside an agent's scope.
- **Bash guard.** Blocks `git push --force`, `git commit --no-verify`, `rm -rf /`, and other destructive operations.
- **Protected paths.** Pipeline YAML, secret files (`.env`, `.pem`, `.key`), and master skills cannot be modified by AI.
- **Human gates.** Every pipeline stage requires explicit human approval to proceed.
- **Audit trail.** Every run produces a trace (`.claude/trace/` locally, build artifacts in CI).

---

## Windows setup

Hooks are bash scripts. On Windows, choose one approach:

### Option A: WSL2 (recommended)

```powershell
wsl --install
# Inside WSL2:
npm install -g @anthropic-ai/claude-code
cd ~ && git clone <your-repo> && cd <your-repo>
claude
```

### Option B: Git Bash

Install [Git for Windows](https://git-scm.com/download/win), then configure Claude Code to use Git Bash:

```json
{
  "shell": "C:\\Program Files\\Git\\bin\\bash.exe"
}
```

### Option C: Native PowerShell

Replace `.sh` hook scripts with `.ps1` equivalents. CI pipelines are unaffected (they run on `ubuntu-latest`).

---

## Detailed docs

| Document | Contents |
|----------|----------|
| [docs/FUNCTIONAL_DESIGN.md](docs/FUNCTIONAL_DESIGN.md) | What the system does and why — personas, stages, review points, onboarding |
| [docs/TECHNICAL_DESIGN.md](docs/TECHNICAL_DESIGN.md) | Full architecture — file specs, hook contracts, skill interfaces, cost model |
| [plugin/README.md](plugin/README.md) | Plugin manifest reference — skills, agents, hooks, CLI tools |
