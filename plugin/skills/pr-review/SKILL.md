---
name: pr-review
description: Review a PR diff for correctness, readability, and adherence to project standards. Posts PR comments; never approves. Invoked by the pr-review pipeline.
argument-hint: "<pr-id>"
allowed-tools: Read, Grep, Glob, Bash(git:*), Bash(az:*), Bash(jq:*), Bash(conductor-*)
---

# PR review

Review the diff in PR **$1**. Post comments. Do not approve.

## Hard rules

1. **No approvals.** Only comments. Humans approve.
2. **Cite file:line.** Every finding points to a location in the diff.
3. **Severity discipline.** Use blocker / major / minor / nit. Don't inflate.
4. **No noise.** If a line is fine, do not comment. Reviewers who over-comment get ignored.

## Procedure

### Step 1 — Load context

- `shared/project/PROFILE.md`
- `shared/project/overrides/pr-review.md` (if present)
- `shared/project/guidelines/*.md`
- Relevant `stacks/*`

### Step 2 — Read the diff

```bash
git fetch origin
git diff origin/main...HEAD
```

Also fetch the parent design if the PR description references `WI-<id>`:

```bash
# Locate docs/designs/WI-<id>/slices.md, compare implementation to declared AC
```

### Step 3 — Checklist per changed file

For each file, check:

1. Does it satisfy the slice AC?
2. Does it violate any guideline? Cite the guideline file and section.
3. Obvious bugs: race conditions, unchecked null/undefined, missing error paths, off-by-one, resource leaks.
4. Readability: overly long function, unclear name, dead code, commented-out code.
5. Test quality: does the test actually assert behaviour, or is it vacuous?
6. Public API changes: are they documented and backwards-compatible?

### Step 4 — Post comments

Write each finding as a structured comment:

```
[<severity>] <file>:<line>
<description>
<reference: guideline/section or slice AC ID>
```

Post inline via:

```bash
az repos pr thread create \
  --pull-request-id $1 \
  --file-path "<path>" \
  --right-file-start-line <line> \
  --right-file-end-line <line> \
  --comments "[<severity>] <text>"
```

Then post one summary comment on the PR:

```
Code review complete.
Blockers: N
Major: N
Minor: N
Nits: N
Full list: see inline comments.
```

### Step 5 — Handoff

```
=== CODE REVIEW COMPLETE ===
PR: $1
Files reviewed: <count>
Findings: blocker=N major=N minor=N nit=N
Approved: no (humans approve)
```
