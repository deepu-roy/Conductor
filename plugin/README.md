# ai-sdlc Plugin

AI-assisted SDLC pipeline — from tagged work item to merged PR, with human gates at every step.

## Installation

This plugin is cross-tool compatible — it works in **GitHub Copilot (VS Code)**, **GitHub Copilot CLI**, and **Claude Code**.

### GitHub Copilot (VS Code) — Preview

1. Open Command Palette (`⇧⌘P` / `Ctrl+Shift+P`)
2. Run **Chat: Install Plugin From Source**
3. Enter: `https://github.com/deepu-roy/ai-sdlc-orchestrator`

Or register a local clone in VS Code settings:

```jsonc
// settings.json
"chat.pluginLocations": {
    "/path/to/ai-sdlc-orchestrator/plugin": true
}
```

> Requires `chat.plugins.enabled` to be `true` (Preview feature).

### GitHub Copilot CLI

```bash
copilot plugin install --from https://github.com/deepu-roy/ai-sdlc-orchestrator
```

### Claude Code

```bash
claude plugin add --from https://github.com/deepu-roy/ai-sdlc-orchestrator
```

See the [main README](../README.md#installation) for full installation details.

## Post-Install Setup

After installing, run the bootstrap skill to initialize your project:

```
/ai-sdlc:bootstrap-project
```

This creates `shared/project/` in your repo with:
- `PROFILE.draft.md` — fill this in and rename to `PROFILE.md`
- `guidelines/` — coding standards, error handling, naming, API contracts
- `CLAUDE.md` — project-level policy overrides

**That's it.** All skills and agents are immediately available.

## What's Included

### Skills (10)

| Skill | Description |
|-------|-------------|
| `bootstrap-project` | Initialize project configuration from templates |
| `requirements-analysis` | Analyze work items, identify personas, extract requirements |
| `update-functional` | Update functional design docs from requirements |
| `technical-slicing` | Break stories into implementable vertical slices |
| `implement-story` | Orchestrate full story implementation across slices |
| `implement-slice` | Implement a single vertical slice (contract → backend → frontend) |
| `pr-review` | Automated PR review (code + security + tech-debt) |
| `security-review` | OWASP Top 10 + LLM security audit |
| `tech-debt-review` | Duplication, coupling, test quality audit |
| `verify-story` | End-to-end story acceptance verification |

### Agents (6)

| Agent | Role |
|-------|------|
| `backend-dev` | Implements server code, data layer, business logic |
| `frontend-dev` | Implements UI components, client state, tests |
| `contract-dev` | Defines/updates API contracts (OpenAPI, GraphQL) |
| `code-reviewer` | Reviews for correctness & standards adherence |
| `security-auditor` | Reviews for OWASP Top 10, injection, secrets |
| `tech-debt-auditor` | Reviews for duplication, coupling, test gaps |

### CLI Tools (11, auto-added to PATH)

| Command | Purpose |
|---------|---------|
| `ai-sdlc-wi-show` | Fetch work item details from ADO |
| `ai-sdlc-wi-update` | Update work item state/fields |
| `ai-sdlc-wi-create-slice` | Create child task WI from slice |
| `ai-sdlc-create-pr` | Create PR (GitHub or ADO) |
| `ai-sdlc-pr-comment` | Post PR comment |
| `ai-sdlc-notify` | Send notification (webhook) |
| `ai-sdlc-check-compile` | Run compile gate |
| `ai-sdlc-check-startup` | Run startup healthcheck gate |
| `ai-sdlc-check-tech-agnostic` | Verify functional docs are tech-agnostic |
| `ai-sdlc-scope-guard` | Block writes to protected paths |
| `ai-sdlc-bash-guard` | Block dangerous shell operations |

### Hooks (2)

- **PostToolUse(Write|Edit)**: Scope guard — blocks writes to pipelines, secrets, env files
- **PreToolUse(Bash)**: Bash guard — blocks `--force`, `--no-verify`, destructive ops

## Project Configuration

The plugin expects `shared/project/PROFILE.md` in your project root. This file configures:

- Repository host (GitHub/ADO)
- Tech stack
- Gate commands (compile, lint, test)
- Notification endpoints
- Team conventions

Run `bootstrap-project` to generate the template.

## Interoperability

This plugin uses the `.claude-plugin/plugin.json` format, which is auto-detected by all three tools:
- **GitHub Copilot (VS Code)** — Agent Plugins (Preview)
- **GitHub Copilot CLI** — Plugin system
- **Claude Code** — Plugin system

Same skills, agents, hooks, and bin scripts work identically across all environments. VS Code discovers the manifest at `.claude-plugin/plugin.json` automatically.

## Architecture

```
plugin/
├── .claude-plugin/plugin.json    # Plugin manifest
├── skills/                       # 10 SDLC skills
├── agents/                       # 6 specialist agents
├── bin/                          # 11 CLI tools (auto-added to PATH)
├── hooks/hooks.json              # Safety hooks
├── project-templates/            # Templates for bootstrap
├── settings.json                 # Recommended permissions
└── README.md
```

## Safety

- **No auto-approve**: Agents post comments only; humans approve PRs
- **Scope enforcement**: Writes to protected paths are blocked
- **No force push**: `git push --force` and `--no-verify` are blocked
- **Human gates**: Every pipeline step requires explicit human go-ahead
