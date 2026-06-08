---
name: tech-debt-review
description: Review a PR diff for technical debt — pattern deviation, duplication, test quality, coupling, documentation gaps. Posts PR comments; never approves.
argument-hint: "<pr-id>"
allowed-tools: Read, Grep, Glob, Bash(git:*), Bash(az:*), Bash(jq:*), Bash(ai-sdlc-*)
---

# Tech debt review

Review PR **$1** for debt. Focus on what will bite future maintainers.

## Hard rules

1. **No approvals.**
2. **Bias toward silence.** Every comment has a cost in review fatigue. If a line is "not ideal but harmless," skip it.
3. **Reference the standard.** If you flag a pattern deviation, point to the guideline.

## Checklist

### Duplication
- Copy-pasted block >10 lines → major.
- Copy-pasted block 4–10 lines → minor.
- Same constant defined in >1 place → minor.

### Coupling
- New direct call from one bounded context to another's internals → major.
- Module imports from a quarantined path listed in PROFILE → blocker.
- Global state introduced → major.

### Abstraction
- Function with >50 lines → minor.
- Function with >100 lines → major.
- Function with >5 parameters → minor; >8 → major.
- Cyclomatic complexity warning visible → minor.

### Testing
- New public function without a unit test → major.
- Test that only checks it doesn't throw → minor (vacuous).
- Test that uses sleep/wait → minor (flaky).
- Integration test with no assertions about state → major.

### Documentation
- Public API without doc comment → minor.
- Non-obvious algorithm without a "why" comment → minor.
- TODO without owner and ticket → minor.

### Project-specific
Read `shared/project/guidelines/coding-standards.md` and `shared/project/overrides/tech-debt-review.md`. Apply.

## Procedure

1. Load project layer.
2. `git diff origin/main...HEAD`.
3. Walk the checklist. Post inline comments for major and blocker only. Minor and nit go into a single summary comment.
4. Summary:

```
Tech debt review complete.
Blockers: N
Major: N (inline)
Minor: N (listed below — do not block merge)
Nits: N (listed below)
```

5. Standard handoff block.
