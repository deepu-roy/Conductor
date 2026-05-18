---
name: security-review
description: Review a PR diff for security issues — OWASP Top 10, LLM-specific risks, injection, secrets, auth, and data exposure. Posts PR comments; never approves.
argument-hint: "<pr-id>"
allowed-tools: Read, Grep, Glob, Bash(git:*), Bash(az:*), Bash(jq:*), Bash(shared/scripts/*)
---

# Security review

Review PR **$1** for security issues. Be specific, cite the line, assign severity.

## Hard rules

1. **No approvals.** Comments only.
2. **Accuracy over volume.** A wrong security finding costs more trust than a missed one. If you're uncertain, mark as `minor` and note the uncertainty.
3. **Never echo secrets.** If you find one, note the file:line and the type of secret; do not paste the value.

## Checklist (OWASP Top 10 + LLM + project-specific)

### Injection
- SQL built via string concat → blocker.
- Shell built via string concat of user input → blocker.
- HTML rendered without escaping → major unless explicitly safe.
- LLM prompts built from user input without separation → major.

### Auth and session
- New endpoint without authn check → blocker.
- Role/permission check missing on mutating endpoint → blocker.
- JWT/token validation skipped or signature not verified → blocker.
- Password or token in logs → blocker.

### Data exposure
- PII returned in a response where it wasn't before → major.
- Error response includes stack trace → major.
- Error response leaks internal paths or DB schema → major.

### Cryptography
- New use of MD5 or SHA1 for anything non-cosmetic → major.
- Hardcoded IV, salt, or key → blocker.
- `Math.random()` / `random.random()` for security purposes → blocker.

### Secrets
- Any key, token, password, connection string in source → blocker.
- `.env` file committed → blocker (note: hook should have caught this; flag the hook failure too).

### Configuration
- CORS wildcard → major.
- Cookie without `HttpOnly`, `Secure`, `SameSite` → minor to major depending on content.
- Debug or verbose logging enabled for prod path → minor.

### LLM-specific
- Prompt assembled from untrusted content without isolation markers → major.
- Tool-call pattern without permission gate → major.
- Uncontrolled retry loops over LLM calls (cost risk) → minor.

### Project-specific
Read `shared/project/overrides/security-review.md` for project-specific rules (e.g. PII catalog, audit requirements). Apply them.

## Procedure

1. Load project layer (as in pr-review skill).
2. `git diff origin/main...HEAD`.
3. Walk the checklist. For each finding, post an inline comment with severity and exact line.
4. Write to `docs/designs/WI-$1/security-review.md` 

```
Security review complete.
Blockers: N (must resolve before merge)
Major: N
Minor: N
Checklist coverage: <list of categories checked>
```

## Commit the report

```bash
git add docs/designs/WI-$1/security-review.md
git commit -m "WI-$1: security review report"
```

Do not push — caller controls pushes.

### Step 9 — Post to PR (if PR exists)

Read the PR platform from the override file (defaults to `azure-devops`):

```bash
PR_PLATFORM=$(yq -r '.pr_platform // "azure-devops"' shared/project/overrides/security-review.md 2>/dev/null || echo "azure-devops")
BRANCH=$(git branch --show-current)
REPORT_BODY=$(cat "docs/designs/WI-$1/security-review.md")
```

**If `pr_platform: github`** — use `gh` CLI:

```bash
PR_ID=$(gh pr list --head "$BRANCH" --json number -q ".[0].number" 2>/dev/null | tr -d '\n')
if [[ -n "$PR_ID" && "$PR_ID" != "null" ]]; then
  gh pr comment "$PR_ID" --body "$REPORT_BODY" 2>/dev/null && echo "✓ Comment posted" || echo "Could not post comment"
fi
```

**If `pr_platform: azure-devops`** — use `az` CLI:

```bash
PR_ID=$(az repos pr list --source-branch "$BRANCH" \
  --query '[0].pullRequestId' -o tsv 2>/dev/null)
if [[ -n "$PR_ID" ]]; then
  shared/scripts/ado-pr-comment.sh "$PR_ID" active "$REPORT_BODY"
fi
```

If no PR is found for the current branch, skip silently.

