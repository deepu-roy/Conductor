---
name: technical-slicing
description: Break a technical design into implementable slices. Usually chained from requirements-analysis; can be called standalone to re-slice an existing design.
argument-hint: "<work-item-id>"
allowed-tools: Read, Write, Glob, Grep, Bash(jq:*), Bash(yq:*), Bash(shared/scripts/*)
---

# Technical slicing

You produce `slices.md` for work item **$1** from an existing `docs/designs/WI-$1/technical.md`.

## Hard rules

1. **One slice = one PR-sized unit.** Rule of thumb: <400 lines of diff, <6 files, single focus.
2. **Parallel slices have disjoint writable file scopes.** No two slices in the same `parallel_with` group write the same file.
3. **Contract slices run first.** Any slice in `layer: contract` has `depends_on: []` and all other slices depend on it.
4. **Every slice has measurable AC, declared impact, declared risk, declared test plan.** No adjectives in AC.
5. **Never invent slices for work that isn't in the design.** If the design is sparse, flag `[NEEDS HUMAN INPUT]` in a header and stop.

## Procedure

### Step 1 — Load inputs

- `shared/project/PROFILE.md` (required — abort if missing)
- `shared/project/overrides/technical-slicing.md` (if present)
- `shared/project/guidelines/*.md`
- `docs/designs/WI-$1/functional.md`
- `docs/designs/WI-$1/technical.md`

### Step 2 — Identify quarantined paths

From `PROFILE.md` `quarantined_paths`. If the design requires touching any of these, do not generate a slice for that work — instead, add to a `blocked` list at the top of `slices.md` and do not emit a slice for it.

### Step 3 — Draft slices

Walk the technical design. For each distinct unit of work:

1. Identify the layer (contract / backend / frontend / infra).
2. List the files that would change. Be specific — globs are acceptable, but they must be disjoint from other parallel slices.
3. Write at least one Given/When/Then acceptance criterion.
4. Decide blast radius, rollback cost, failure mode, mitigation.
5. Pick a test plan — the exact commands that will prove the slice works.

### Step 4 — Check disjointness

For every pair of slices declared `parallel_with`:

- Compute the intersection of writable file globs.
- If non-empty, either serialize them (remove `parallel_with`, add `depends_on`) or split the conflicting file into its own slice.

### Step 5 — Check the dependency graph

- Every `depends_on` references a real slice ID.
- Contract slices have no deps.
- Cycles are not allowed. If detected, abort and emit a diagnostic header.

### Step 6 — Emit `slices.md`

See schema in requirements-analysis skill. Top of file:

```yaml
parent_work_item: $1
generated_by: technical-slicing
blocked:        # work that could not be sliced due to quarantine or missing info
  - reason: "<sentence>"
    details: "<file or component>"
```

### Step 7 — Handoff

```
=== SLICING COMPLETE ===
Work item: WI-$1
Slices: <count>
Parallel groups: <count>
Contract slices: <count>
Blocked items: <count>

Next step: requirements-analysis skill resumes to create ADO Tasks and open design PR.
```
