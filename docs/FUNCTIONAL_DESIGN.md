# Functional Design — AI-Assisted SDLC

**Project codename:** AI-SDLC
**Version:** 2.0 (unified `plugin/` distribution — GitHub Copilot and Claude Code)
**Audience:** Engineering lead, platform team, project owner
**Related:** `TECHNICAL_DESIGN.md`

---

## 1. Purpose

Deliver a working SDLC pipeline where an AI coding tool — GitHub Copilot or Claude Code, both loading the same installed `ai-sdlc` plugin and guided by composable, project-aware skills — converts a tagged ADO work item into a reviewed design, implementation PRs, and automated review comments. Humans remain the decision-makers at every gate. The system removes typing, not judgement.

## 2. Goals and non-goals

### Goals

- One-command onboarding: `/bootstrap-project` profiles any repo and proposes the project layer for human confirmation.
- Master skills remain read-only across projects; project-specific rules live in a separate, additive overrides layer.
- CLI-first tooling (`az`, `git`, `gh`, `curl`); MCP only where no CLI is viable.
- Stories with both frontend and backend slices implement in parallel through dedicated subagents with enforced file-boundary scopes.
- Every automated stage emits a reviewable artifact (PR, work item, comment). No silent writes to production branches or protected resources.
- Full audit trail per run (`stream-json` logs archived per pipeline).

### Non-goals

- Auto-approving or auto-merging PRs. Humans merge.
- Generating infrastructure or pipeline YAML from prompts. Infra edits are blocked by hook.
- Replacing security review for anything touching auth, money, or PII.
- Running end-to-end UI tests as part of the automated gates (only unit + integration are covered; E2E remains a separate, existing harness).

## 3. Personas

| Persona | Concern | Touchpoint |
|---|---|---|
| Product Manager | Describe intent once, get a reviewable design back | Writes ADO work item, tags `ai:ready` |
| Tech Lead | Ensure design is sound, slicing is safe, tech debt isn't introduced | Reviews design PR, sets merge policy |
| Developer | Fix what Claude got wrong, own the eventual merge | Reviews feature PRs, pairs on slices |
| Security reviewer | Catch auth/PII/injection mistakes before merge | Reads security subagent comments, final approve on sensitive PRs |
| Platform owner | Keep the pipeline reliable and auditable | Owns the `ai-sdlc` plugin (`plugin/skills/`, `plugin/agents/`), watches run logs |

## 4. Scope of work covered (the six stages)

| # | Stage | Automated by | Human gate | Output artifact |
|---|---|---|---|---|
| 1 | Requirements → functional + technical design | `requirements-analysis` skill | Review design PR | `docs/designs/WI-<id>/functional.md`, `technical.md` |
| 2 | Slicing (technical + functional) | `technical-slicing` skill (chained after stage 1) | Same design PR | `docs/designs/WI-<id>/slices.md`, child ADO work items |
| 3 | Acceptance criteria, impact, risk per slice | Same pass as stage 2 | Fields on each child work item | ADO Task fields |
| 4 | Implementation (sequential or parallel) | `implement-story` orchestrator → `backend-dev` + `frontend-dev` subagents | Feature PR review | Feature branch + PR |
| 5 | Unit + integration tests | Same implementation run + PR build | PR checks | Tests in same PR |
| 6 | PR, security, tech-debt review | Three parallel subagents on every PR | Human approve → merge | PR comments |

## 5. End-to-end flow — narrative

1. **PM writes a raw requirement** in an ADO Epic or Feature work item and tags it `ai:ready`.
2. **ADO Service Hook** fires on the tag → pipeline `design-gen` starts.
3. Pipeline runs the AI tool headless with `/requirements-analysis <id>`. The skill:
   - Reads the work item (via `az boards`).
   - Loads `shared/project/PROFILE.md`, policy overrides, guidelines, stacks.
   - Generates `functional.md` (tech-agnostic), `technical.md` (stack-specific), `slices.md` (slicing + AC + risk).
   - Creates child ADO Task work items, one per slice, linked to the parent.
   - Opens a PR `[Design] WI-<id>: <title>` on a `design/WI-<id>` branch.
   - Posts one notification with the PR link.
4. **Humans review the design PR.** Inline comments drive revisions; if the skill needs to re-run, it reacts to a PR comment trigger. Merge of the design PR = approval to implement.
5. **Merge webhook** triggers pipeline `implement-story`. The orchestrator:
   - Classifies slices as contract / backend / frontend.
   - If API contract changes: runs `contract-dev` subagent first, alone. Reviews its output. If contract-dev surfaces a question, stops and asks the human.
   - Spawns `backend-dev` and `frontend-dev` in parallel on disjoint file scopes.
   - Merges their branches into `story/WI-<id>`, runs integration tests, opens one PR.
6. **PR build** fires three subagents in parallel on the diff: `code-reviewer`, `security-auditor`, `tech-debt-auditor`. Each posts findings as PR comments, tagged by severity. None can approve.
7. **Humans approve and merge.** Post-merge, ADO work item auto-moves to Resolved via an `az boards` call, and a final summary notification goes out.

## 6. Review and revision points — the full list

These are the places where humans are required or invited to intervene. Anything outside this list is automated.

| Stage | Review surface | What the reviewer decides |
|---|---|---|
| 1–3 | Design PR in repo | Is the functional model right? Is the slicing safe? Are AC measurable? |
| 1–3 | Child ADO work items | Accept, re-title, reassign priority, kill |
| 4 (contract) | Contract-dev branch or direct human response to orchestrator question | Approve contract shape |
| 4 (impl) | Feature PR | Code correctness |
| 6 | PR security comments | Accept / escalate / block |
| 6 | PR tech-debt comments | Accept / defer / ignore |
| PROFILE | `shared/project/PROFILE.draft.md` | Confirm stack detection before first real run |

## 7. What minimal human effort looks like in practice

For a typical mid-size story (e.g. "allow users to save searches"):

- PM spends ~5 minutes writing the work item description.
- Tech lead spends ~15 minutes reviewing the design PR, usually approving with one or two revision comments.
- Developer spends ~20–40 minutes reviewing the feature PR, running it locally if needed, and closing on edge cases.
- Security and tech debt subagent comments are triaged in ~5 minutes.
- Total human time: roughly one hour for what used to be a day's worth of ticket carving, spec writing, and first-pass implementation.

This number degrades sharply for:

- Stories that cross three or more surfaces (frontend + backend + infra + data). Split these into smaller parent stories.
- Stories touching quarantined code marked in `shared/project/PROFILE.md`'s `quarantined_paths`. The system will refuse to auto-implement; a human must pair.
- Stories requiring new architectural decisions. The skill will flag `[NEEDS ADR]` and stop — this is intentional.

## 8. Project onboarding — functional description

When the system is dropped into a new repo for the first time:

1. A human installs the `ai-sdlc` plugin once (`copilot plugin install --from https://github.com/deepu-roy/ai-sdlc-orchestrator` or `claude plugin add --from ...`), then runs `/bootstrap-project` once, locally.
2. The skill scans manifests, framework signals, CI config, test frameworks, linter configs, and infra files. It does not write or commit.
3. It generates `shared/project/PROFILE.draft.md` with every claim citing the file and line that supports it, and copies the CI pipeline templates from the plugin into `.azure-pipelines/` or `.github/workflows/`.
4. The human reviews, corrects, and renames to `PROFILE.md`. This commit activates the project layer.
5. Stock `guidelines/` and `stacks/` files are created as starter scaffolds — the human fills them in over the first week of use. All plugin skills gracefully handle missing optional files; none are required except `PROFILE.md`.

## 9. Composable skill model — functional description

Every plugin skill, before producing output, consults in this order:

1. `shared/project/PROFILE.md` — what stack are we in?
2. `shared/project/CLAUDE.md` — project policy.
3. `shared/project/overrides/<skill-name>.md` — skill-specific augmentation.
4. `shared/project/guidelines/*.md` — all files, loaded in alphabetical order.
5. `shared/project/stacks/<relevant-stack>.md` — only the stacks the PROFILE says apply.

On conflict, the higher-precedence source wins.

**Plugin skills are read-only from the project's perspective.** Projects never edit them directly — they live in `plugin/skills/` inside the installed `ai-sdlc` plugin and are distributed as a single plugin package (`marketplace.json` / `plugin/.claude-plugin/plugin.json`), versioned and updated independently of any consuming project.

## 10. CLI-first policy — functional description

The default transport for every external interaction is a CLI. Skills that need ADO, Git, Slack, cloud providers, containers, or Kubernetes call their official CLIs through the `Bash(...)` tool whitelist. MCP is reserved for:

- Bidirectional streaming (e.g. Claude listening on a Slack thread).
- Systems with no stable CLI.

Every new skill added to the system defaults to CLI; an MCP fallback requires a short justification comment in the skill frontmatter.

## 11. Multi-agent composition — functional description

A story's slices are grouped by layer:

- **Contract slices** — API schema, type contracts, DB migration structure.
- **Backend slices** — server, data, business logic, backend tests.
- **Frontend slices** — UI, client state, client tests.

The orchestrator spawns subagents by layer. Each subagent runs in a forked context with:

- Its own tool whitelist.
- Its own file-read/write scope (enforced via the `ai-sdlc-scope-guard` hook, backed by `plugin/scope-map.json`).
- Its own test command.

Contract-dev runs first and alone. On completion, its branch is merged into the story branch. Backend-dev and frontend-dev then spawn in parallel, both branching from the contract merge. They cannot touch each other's files; the hook blocks and reports violations.

Merge back into `story/WI-<id>` is done by the orchestrator. If merge conflicts occur, the orchestrator aborts and flags to human — conflicts mean the scope boundary was crossed, which is a prompt bug to fix, not a diff to paper over.

## 12. Failure modes the system handles explicitly

| Failure | Behaviour |
|---|---|
| Skill cannot find required work item field | Writes `[NEEDS HUMAN INPUT]` into the doc; does not invent |
| Slicing would require touching a quarantined file | Aborts slicing; opens a comment on the parent work item asking for human pairing |
| Subagent runs out of turns | Pipeline fails loudly with last state preserved; human resumes locally |
| Contract-dev surfaces ambiguity | Orchestrator stops, posts question, does not spawn backend/frontend |
| Security subagent finds a `blocker` severity issue | Posts PR comment; pipeline status stays neutral but merge policy (enforced by branch protection in ADO) requires resolution before merge |
| Hook blocks a tool call | The agent receives the block reason, retries within constraints, or fails loudly |
| Pipeline turn budget exceeded (`maxTurns`) | Fails loudly; no partial commit |
| Deterministic step (lint, test) fails post-impl | Subagent tries up to 3 self-repair loops, then fails loudly |

## 13. Success criteria (measurable)

- `/bootstrap-project` correctly identifies the primary stack on 95% of a sample of 20 representative repos on first run.
- For a typical story (backend + frontend, no new ADR), end-to-end human time from tag to merge is under two hours.
- Design-PR revision rate: >50% of design PRs require zero or one revision round.
- Security subagent catches a seeded OWASP Top-10 issue in >70% of planted cases in a weekly regression suite.
- Zero auto-merges; zero writes to protected files (verified via hook logs).
- A run-log artifact exists for every pipeline run, retained 90 days.

## 14. Out of scope for v1

- A web UI. The system lives in ADO, Git, and chat notifications (Slack/Teams).
- Auto-generating ADRs. The AI flags when an ADR is needed; humans write it.
- Multi-repo refactors. One repo per run.
- Languages / stacks not yet represented in `stacks/`. Add as you go.
- Real-time observability dashboards. Read the run-log artifacts; a dashboard is phase 2.

## 15. Rollout plan — functional view

| Week | Milestone | Exit criterion |
|---|---|---|
| 1 | Bootstrap + project layer contract | Run on three live repos; PROFILE confirmed by each tech lead |
| 2 | Stage 1–3 skills end-to-end, CLI-only | One real feature reaches a clean design PR |
| 3 | Subagent trio + orchestrator | One real story reaches a clean feature PR |
| 4 | Review subagents on PR build | Three reviewers comment on every PR in pilot repo |
| 5 | Pilot with one team on one repo | Tag-to-merge in under two hours for a typical story |
| 6+ | Incremental rollout, pattern collection | Guideline files filled in, stack files refined |

## 16. Open questions for the human owner

1. Which pilot repo? Recommend a medium-complexity fullstack repo with a cooperative team and a tolerant branch policy.
2. Who owns the `ai-sdlc` plugin (`plugin/skills/`, `plugin/agents/` in this repo)? A platform team of at least two is strongly advised.
3. Which ADO project area has an `ai:ready` tag defined? Create one if absent.
4. Which notification channel receives summaries? Recommend a single dedicated Slack/Teams channel; don't spread.
5. Where do pipeline run-log artifacts live? Minimum: 90-day retention on the CI platform's own artifact store.

## 17. Handover checklist

To implement, the platform team needs:

- This document (`FUNCTIONAL_DESIGN.md`) for the "why and what".
- `TECHNICAL_DESIGN.md` for the "how".
- This repo (`ai-sdlc-orchestrator`), installed as a plugin into the target project via `copilot plugin install --from ...` or `claude plugin add --from ...`.
- Access to an ADO organization with a non-production pilot project.
- An Anthropic API key stored as `ANTHROPIC_API_KEY` secret in the pipeline library.
- An ADO PAT with work item + code + build scopes stored as `ADO_PAT`.
- A Slack or Teams incoming webhook URL stored as `SLACK_WEBHOOK_URL`.
