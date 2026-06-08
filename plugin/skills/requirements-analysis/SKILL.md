---
name: requirements-analysis
description: Convert an ADO work item tagged ai:ready into functional.md + technical.md + slices.md, create child ADO Tasks, open a design PR, and notify Slack. Use when invoked by the design-gen pipeline with a work item ID.
argument-hint: "<work-item-id>"
allowed-tools: Read, Write, Glob, Grep, Bash(git:*), Bash(gh:*), Bash(az:*), Bash(curl:*), Bash(jq:*), Bash(yq:*), Bash(ai-sdlc-*)
---

# Requirements analysis → design + slicing

You are converting ADO work item **$1** into three design artifacts + child work items + a design PR.

## Hard rules

1. **Propose, don't invent.** Every claim cites a source: the work item field it came from, a linked doc, a prior design, or `[NEEDS HUMAN INPUT]`.
2. **Tech-agnostic `functional.md`.** Blocklist: OAuth, JWT, REST, GraphQL, gRPC, PostgreSQL, MySQL, Redis, MongoDB, React, Angular, Vue, Next, Kubernetes, Docker, AWS, Azure (as cloud service), Lambda, S3, Cosmos, RabbitMQ, Kafka. These are allowed in `technical.md`.
3. **Measurable success criteria.** Reject adjectives (fast, secure, scalable). Require numbers or user-observable behaviour.
4. **One slice = one PR-sized unit.** Disjoint file scopes between parallel slices. Measurable AC, declared impact, declared risk, test plan.
5. **No auto-merge. No pushes to main. No edits to `shared/skills/`, `.azure-pipelines/`, or secret files.** Hooks enforce.

## Procedure

### Step 1 — Load project layer

Read (in order):
1. `shared/project/PROFILE.md` — if missing, abort with: `PROFILE.md not found. Run /bootstrap-project first.`
2. `shared/project/CLAUDE.md` (if present)
3. `shared/project/overrides/requirements-analysis.md` (if present)
4. `shared/project/guidelines/*.md` — all files
5. `shared/project/stacks/*.md` — only those matching the PROFILE

On any conflict, higher-precedence source wins: overrides > project CLAUDE.md > guidelines > master.

### Step 2 — Fetch the work item

```bash
ai-sdlc-wi-show $1 > /tmp/wi-$1.json
```

Extract: title, description, acceptance criteria, tags, linked parents, linked children (if any).

Also scan `docs/designs/` for prior designs that might be related. Link them; do not duplicate their content.

### Step 3 — Generate three documents

Write all three under `docs/designs/WI-$1/`.

#### 3a. `functional.md`

Structure:

```markdown
# Functional design — WI-$1: <title>

## 1. User problem
<One paragraph. Cite work item field.>

## 2. Personas
- <Persona>: <what they want, cite source>

## 3. Scope
### In scope
### Out of scope

## 4. User journeys
<For each journey: Given / When / Then>

## 5. Success criteria (measurable)
- <Criterion>        [source: <work item field or [NEEDS HUMAN INPUT]>]

## 6. Open questions
- <Question> → <who to ask>

```
After writing, for **each open question** in §6, execute this command (outside the document — do not write the command into functional.md):

```bash
ai-sdlc-wi-update $1 --discussion "Open question: <Question> → <who to ask>"
```

Then run:

```bash
ai-sdlc-check-tech-agnostic docs/designs/WI-$1/functional.md
```

If it exits non-zero, revise the document.


#### 3b. `technical.md`

Structure:

```markdown
# Technical design — WI-$1

## 1. Stack impact
<Which PROFILE stacks are touched: frontend / backend / contract / infra>

## 2. Data model
<New tables, columns, migrations — if any>

## 3. API contract impact
<New/changed endpoints or schemas — if any>

## 4. Key flows
<Sequence description, using existing service names from the repo>

## 5. NFRs
- Latency: <specific number or N/A>
- Throughput: <specific number or N/A>
- Data retention: <specific number or N/A>
- Availability: <specific number or N/A>

## 6. ADRs needed
- [ ] <If any architectural choice is non-trivial, flag it. Do not invent the ADR.>

## 7. Dependencies
<External systems, internal services>

## 8. Risks
<Bullet list>
```

#### 3c. `slices.md`

This is the handoff to implementation. Use strict YAML:

```yaml
parent_work_item: $1
slices:
  - id: S1
    title: <imperative>
    layer: contract | backend | frontend | infra
    files:
      - path: <glob>
        access: read-write | read-only
    depends_on: []
    parallel_with: []
    acceptance:
      - "Given ..., when ..., then ..."
    impact:
      blast_radius: low | medium | high
      touches: []
      rollback: trivial | moderate | hard
    risk:
      failure_mode: "<sentence>"
      mitigation: "<sentence>"
    test_plan:
      unit: "<exact command>"
      integration: "<exact command>"
```

Slicing rules:
- No two parallel slices share a writable file path.
- Every slice has at least one measurable AC.
- Contract slices (if any) have no `depends_on` — they run first.
- Backend and frontend slices for the same story list each other in `parallel_with` only if the contract is settled.

If slicing would require touching any path listed under `quarantined_paths` in PROFILE.md, stop. Write a comment on the parent work item asking for human pairing, and emit an empty `slices.md` with a `# Blocked: quarantined paths: [...]` header.

### Step 4 — Create child ADO Tasks

For each slice:

```bash
# extract single slice YAML to a temp file, then:
ai-sdlc-wi-create-slice $1 /tmp/slice-<id>.yaml
```

Attach the full slice YAML as the work item description.

### Step 5 — Open the design PR

```bash
git checkout -b design/WI-$1
git add docs/designs/WI-$1/
git commit -m "Design: WI-$1 <title>"
git push --set-upstream origin design/WI-$1

az repos pr create \
  --source-branch design/WI-$1 \
  --target-branch main \
  --title "[Design] WI-$1: <title>" \
  --description "$(cat <<EOF
## Design for WI-$1

### Documents
- functional.md
- technical.md
- slices.md

### Child work items created
<list of IDs>

### Open questions
<from functional.md §6>

### Reviewers
<from CODEOWNERS or shared/project/PROFILE.md reviewers field>
EOF
)" \
  --work-items $1 \
  --output json
```

### Step 6 — Slack notification

```bash
ai-sdlc-notify "Design ready for review: WI-$1 — <PR URL>"
```

### Step 7 — Handoff ritual

Emit exactly this block at the end of your output (no prose after it):

```
=== REQUIREMENTS ANALYSIS COMPLETE ===
Work item: WI-$1
Documents: docs/designs/WI-$1/{functional,technical,slices}.md
Child work items created: <list>
Design PR: <URL>
Slack notified: yes
Blocked: <none | reason>
Open questions: <count>

Next step: human review of design PR. On merge, implement-story pipeline triggers.
```
