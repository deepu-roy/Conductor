---
name: update-functional
description: Incorporate answers to open questions in functional.md, update the document, re-evaluate any existing technical.md and slices.md for downstream impact, apply corrections, and determine whether technical design can now proceed. Use after a human has answered questions flagged in §6 of functional.md.
argument-hint: "<work-item-id>"
allowed-tools: Read, Write, Edit, Bash(git:*), Bash(ai-sdlc-*)
---

# Update functional design with answers

Work item: $1

## Procedure

### Step 1 — Load current state
Read `docs/designs/WI-$1/functional.md`. Extract all items in section 6
(Open questions). Categorise each as:
- ANSWERED — answer is present inline or in the ADO work item comments
- UNANSWERED — still open
- DEFERRED — explicitly out of scope for this story

### Step 2 — Read answers
Read the ADO work item comments for any answers posted since the
document was generated:
```bash
ai-sdlc-wi-show $1 | jq '.comments // .fields["System.History"]'
```
Also read any inline edits the human made directly to functional.md.
Capture the source of each answer (comment ID, date, user or "edited functional.md") for citation in the next step.

### Step 3 — Update functional.md
For each ANSWERED question:
- Incorporate the answer into the relevant section
  (personas, success criteria, scope, journeys — wherever it belongs)
- Remove it from section 6
- Add a citation: [answered by <source> on <date>]

For each DEFERRED question:
- Move to a new section 7 Deferred decisions with rationale

For each still UNANSWERED question:
- Leave in section 6, flag as [BLOCKING] if it prevents technical design,
  [NON-BLOCKING] if technical design can proceed without it

### Step 4 — Re-run tech-agnostic check
```bash
ai-sdlc-check-tech-agnostic docs/designs/WI-$1/functional.md
```

### Step 5 — Re-evaluate existing technical design and slices

If `docs/designs/WI-$1/technical.md` exists, read it. If `docs/designs/WI-$1/slices.md`
exists, read it.

For each ANSWERED question from Step 3, assess its downstream impact:

**Impact categories:**
- **NONE** — the answer matches what technical.md/slices.md already assumed; no change needed.
- **ADDITIVE** — the answer introduces new scope (e.g. a new endpoint) that is missing from
  technical.md or slices.md. Add the missing design elements.
- **CORRECTIVE** — the answer contradicts an assumption already baked into technical.md or
  slices.md (e.g. a "409 Conflict" note that should now say "upsert"). Fix the incorrect
  statements, remove stale `[NEEDS HUMAN INPUT]` markers, and resolve any open ADRs that the
  answer settles.
- **STRUCTURAL** — the answer changes the data model, API shape, or slice boundaries
  significantly. Flag this explicitly in the report and apply the structural changes to both
  documents.

Apply all ADDITIVE, CORRECTIVE, and STRUCTURAL changes in-place to technical.md and slices.md.
Cite the source of each change: `[OQ-N resolved; answered by <source> on <date>]`.

After editing, check that technical.md contains no remaining `[NEEDS HUMAN INPUT]` tags
that were made obsolete by the newly answered questions.

### Step 6 — Gate check
Evaluate: can technical design proceed?

BLOCKING criteria (any one blocks):
- A success criterion is still [NEEDS HUMAN INPUT]
- A user journey has an unresolved branch
- The scope boundary is ambiguous (in-scope vs out-of-scope unclear)

NON-BLOCKING (can proceed):
- Edge cases not fully defined
- Nice-to-have persona details missing
- Non-critical NFRs unspecified

### Step 7 — Commit and report
```bash
git add docs/designs/WI-$1/functional.md \
        docs/designs/WI-$1/technical.md \
        docs/designs/WI-$1/slices.md
git commit -m "WI-$1: update design docs with answered questions"
git push
```

(Only stage files that actually changed.)

Emit:
```
=== FUNCTIONAL UPDATE COMPLETE ===
Questions answered: N
Questions deferred: N
Questions still open: N
  - BLOCKING: N
  - NON-BLOCKING: N

Technical design impact:
  - NONE: N questions had no downstream effect
  - ADDITIVE: N questions added new design elements
  - CORRECTIVE: N questions corrected existing design
  - STRUCTURAL: N questions required structural changes

Verdict: PROCEED to technical design | BLOCKED — resolve open questions first

Blocking questions remaining:
- <list>
```