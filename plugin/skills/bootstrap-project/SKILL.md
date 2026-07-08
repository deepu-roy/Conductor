---
name: bootstrap-project
description: One-time project onboarding. Detects stack, repo kind, CI pipeline, repo host, notification config, and generates the project overrides layer as a draft for human review. Run once when adopting the Conductor system in a new repo.
allowed-tools: Read, Write, Glob, Grep, Bash(git:*), Bash(ls:*), Bash(cat:*), Bash(find:*), Bash(jq:*)
disable-model-invocation: true
---

# Bootstrap project

You are onboarding this repo to the Conductor system. You run **once**, invoked manually by a human.

## Hard rules

1. **Detect, don't assume.** Every claim in the draft must cite a file and line. If you cannot cite, write `[NEEDS HUMAN INPUT]`.
2. **Draft only.** Write `shared/project/PROFILE.draft.md`. Never write `PROFILE.md` directly. Never commit or push.
3. **No silent skill enabling.** List recommended skills; the human decides.
4. **Do not edit master skills** (`plugin/skills/**`). Hooks will block this.
5. **Do not write to `.azure-pipelines/**`, secrets, or other protected paths.**

## Procedure

### Phase 1 — Inventory

Glob and Grep the repo for signal files. Build an evidence list.

**Manifests and frameworks:**
- `package.json` at any depth → read it. Look in `dependencies` and `devDependencies` for: `react`, `@angular/core`, `vue`, `next`, `nuxt`, `svelte`, `vite`, `@nestjs/core`, `express`, `fastify`.
- `*.csproj`, `global.json`, `Directory.Build.props` → .NET stack; TargetFramework tells you the version.
- `pyproject.toml`, `requirements.txt`, `setup.py`, `Pipfile` → Python.
- `go.mod` → Go.
- `pom.xml`, `build.gradle`, `build.gradle.kts` → JVM.
- `Cargo.toml` → Rust.
- `Gemfile` → Ruby.

**Repo kind:**
- `pnpm-workspace.yaml`, `lerna.json`, `turbo.json`, `nx.json` → monorepo.
- Multiple top-level manifests in sibling folders → likely monorepo.
- One manifest at root → single.

**CI and infra (pipeline_tool detection):**
- `.azure-pipelines/` present or `azure-pipelines.yml` at root → `pipeline_tool: azure-pipelines`
- `.github/workflows/` present → `pipeline_tool: github-actions`
- Both present → `pipeline_tool: [NEEDS HUMAN INPUT: azure-pipelines | github-actions]`
- Neither → `pipeline_tool: [NEEDS HUMAN INPUT]`
- `.gitlab-ci.yml` → GitLab CI (not yet supported; note as [NEEDS HUMAN INPUT]).
- `Jenkinsfile` → Jenkins (not yet supported; note as [NEEDS HUMAN INPUT]).
- `Dockerfile*`, `docker-compose*.yml` → container present.
- `*.tf`, `terraform/` → Terraform.
- `*.bicep`, `infra/bicep/` → Bicep.
- `helm/`, `*.yaml` under `k8s/` or `charts/` → Kubernetes.

**Repo host detection:**
Run `git remote get-url origin` (or read `.git/config`). Parse the URL:
- `github.com` in URL → `repo_host: github`
- `dev.azure.com` or `visualstudio.com` in URL → `repo_host: azure-repos`
- Cannot determine → `repo_host: [NEEDS HUMAN INPUT: github | azure-repos]`

**Work item source:**
- If `az` CLI is configured and a DevOps URL is detectable → record it as `work_items.org_url`.
- Otherwise → `org_url: [NEEDS HUMAN INPUT]`, `project: [NEEDS HUMAN INPUT]`.

**Notifications:**
Cannot be auto-detected from source. Always set:
```
notifications.type: [NEEDS HUMAN INPUT: slack | teams | webhook]
notifications.webhook_url: [NEEDS HUMAN INPUT]
```

**Test frameworks:**
- `vitest.config.*`, `jest.config.*`, `playwright.config.*`, `cypress.config.*` for JS.
- `*Tests.csproj`, `xunit` refs, `nunit` refs for .NET.
- `pytest.ini`, `pyproject.toml` with `[tool.pytest]` for Python.
- `go test` (implicit via `go.mod`) for Go.

**Quality tooling:**
- `.eslintrc*`, `eslint.config.*`, `.prettierrc*`, `.editorconfig`.
- `Directory.Build.props` with `TreatWarningsAsErrors`, `stylecop.json`.
- `ruff.toml`, `.flake8`, `pyproject.toml` with `[tool.ruff]`.

### Phase 2 — Classify

For each detected piece of evidence, write an entry like:

```
frontend.framework: react     # source: apps/web/package.json:14 (react@18.2.0)
orchestration.pipeline_tool: github-actions  # source: .github/workflows/ directory present
orchestration.repo_host: github              # source: git remote origin = github.com/org/repo
```

If ambiguous, list alternatives with evidence:

```
backend.test: xunit | nunit   # source: ambiguous — both referenced in tests/SomeTests.csproj:7-9
                              # [NEEDS HUMAN INPUT]
```

### Phase 3 — Recommend skills

Based on the classification, produce three lists in the draft:

```yaml
recommended_skills:
  always: [requirements-analysis, technical-slicing, implement-slice, pr-review, security-review, tech-debt-review]
  stack_specific: [<derived from PROFILE>]
  not_applicable: [<opposite stacks>]
```

Stack rules:
- React detected → recommend `react-patterns` stack file.
- Angular detected → recommend `angular-patterns`.
- .NET detected → recommend `dotnet-patterns`.
- Neither → recommend a minimal `nodejs-patterns` or `python-patterns`.

### Phase 4 — Scaffold the project layer

Create (only if absent):

- `shared/project/PROFILE.draft.md` — the draft profile.
- `shared/project/CLAUDE.md` — placeholder with a header comment explaining precedence.
- `shared/project/overrides/.gitkeep` — empty.
- `shared/project/guidelines/coding-standards.md` — starter template (see below).
- `shared/project/guidelines/error-handling.md` — starter template.
- `shared/project/guidelines/naming.md` — starter template.
- `shared/project/guidelines/api-contracts.md` — starter template.
- `shared/project/stacks/<detected-stack>.md` — starter per detected stack.

Starter templates should contain section headers and `[NEEDS HUMAN INPUT]` markers — not guessed content.

### Phase 5 — PROFILE.draft.md format

```yaml
# Conductor project profile — DRAFT
# Generated by /bootstrap-project on <ISO date>
# Review each field. Rename to PROFILE.md to activate.

project:
  name: <from package.json or git remote>
  type: <frontend | backend | fullstack | infra | fullstack-monorepo>
  repo_kind: <single | monorepo>

# ── Orchestration ────────────────────────────────────────────────────────────
# Controls which pipeline, repo host, and notification integrations are used.
orchestration:
  pipeline_tool: <github-actions | azure-pipelines>  # source: <detected from / NEEDS HUMAN INPUT>
  repo_host: <github | azure-repos>                  # source: <git remote / NEEDS HUMAN INPUT>
  work_items:
    source: ado
    org_url: <https://dev.azure.com/your-org>        # source: <detected / NEEDS HUMAN INPUT>
    project: <YourProject>                           # source: <NEEDS HUMAN INPUT>
  notifications:
    type: <slack | teams | webhook>                  # [NEEDS HUMAN INPUT]
    webhook_url: <[NEEDS HUMAN INPUT]>
    channel: <#engineering>                          # Slack only; omit for teams/webhook

# ── Stacks ───────────────────────────────────────────────────────────────────
stacks:
  frontend:
    framework: <react | angular | vue | ...>   # source: ...
    meta_framework: <next | nuxt | remix | ...> # source: ...
    language: <typescript | javascript>         # source: ...
    styling: <tailwind | css-modules | ...>     # source: ...
    test: <vitest | jest | ...>                 # source: ...
  backend:
    framework: <dotnet | express | fastify | django | ...>
    language: <csharp | typescript | python | ...>
    orm: <ef-core | prisma | typeorm | ...>
    test: <xunit | jest | pytest | ...>
  infra:
    ci: <azure-pipelines | github-actions>
    iac: <bicep | terraform | none>
    container: <docker | none>

conventions_detected:
  - "<human-readable statement>"      # source: <file>:<line>

recommended_skills:
  always:        [...]
  stack_specific:[...]
  not_applicable:[...]

gates:
  pre_commit: "<command or [NEEDS HUMAN INPUT]>"
  pre_merge:  "<command or [NEEDS HUMAN INPUT]>"

quarantined_paths: []        # add paths here that AI must never auto-edit

# HUMAN CONFIRMATION
# [ ] Evidence reviewed for each field
# [ ] orchestration section filled in (pipeline_tool, repo_host, work_items, notifications)
# [ ] Starter guideline files reviewed and filled in
# [ ] Rename this file to PROFILE.md to activate
```

### Phase 6 — Generate project CLAUDE.md

After PROFILE.draft.md is written, analyse the codebase to populate
`shared/project/CLAUDE.md` with real content (not stubs):

1. Read the 10 most recently modified source files.
2. Read any existing root-level CLAUDE.md or README.
3. Read package.json scripts, Makefile, or equivalent — these reveal
   how the team actually builds, tests, and runs things.
4. Look for existing ADRs, CONTRIBUTING.md, or docs/ markdown.
5. Generate `shared/project/CLAUDE.md` covering:
   - How to build and run the project (exact commands, not guesses)
   - How to run tests (unit, integration, e2e if present)
   - Key architectural patterns you observed (folder structure, DI style,
     error handling patterns, state management approach)
   - Non-obvious gotchas (monorepo workspace hoisting, generated files,
     env var requirements)
   - What NOT to do (antipatterns you spotted)
6. Mark anything uncertain as [VERIFY] not [NEEDS HUMAN INPUT] —
   the distinction matters: VERIFY means "Claude observed this, human
   should confirm", NEEDS HUMAN INPUT means "Claude has no signal".

This file is immediately useful even before the human edits it.
The PROFILE.md is not activated until renamed, but CLAUDE.md can be
committed as a first draft immediately.

### Phase 7 — Handoff

End with:

```
=== BOOTSTRAP SUMMARY ===
Draft written to: shared/project/PROFILE.draft.md
Scaffolds created: <list>
Scaffolds skipped (already existed): <list>
Detected stacks: <short list>
Orchestration detected:
  pipeline_tool: <value or NEEDS HUMAN INPUT>
  repo_host: <value or NEEDS HUMAN INPUT>
  work_items.org_url: <value or NEEDS HUMAN INPUT>
  notifications: [NEEDS HUMAN INPUT]
Ambiguities flagged: <count>

Next steps for the human:
1. Review PROFILE.draft.md. Correct [NEEDS HUMAN INPUT] entries — especially the orchestration section.
2. Fill in guidelines/*.md with real team conventions.
3. Rename PROFILE.draft.md to PROFILE.md.
4. Commit shared/project/ to git.
```

Do not post to Slack or update ADO — this is a local, human-driven step.
