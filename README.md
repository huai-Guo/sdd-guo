# sdd-guo

`sdd-guo` is a Codex Skill for taking a software change from an existing GitHub repository through requirements, implementation, local verification, review, and delivery. It uses GitHub Spec Kit when available and keeps the work tied to observable acceptance criteria.

The Skill is designed to improve decisions at each stage: verify account identity separately from repository permissions; establish the actual base and branch state before switching; understand current behavior before repairing legacy logic; verify the final tree against acceptance criteria; and use a direct owner delivery path only when repository rules allow it.

## Install and prerequisites

- Install this folder as a Codex Skill named `sdd-guo` (for example, under `~/.codex/skills/sdd-guo`).
- Install Git and GitHub Spec Kit: `uv tool install specify-cli`. A target repository needs the Codex integration (`specify init --here --integration codex`) if it does not already have it. Before initializing a non-empty repository, inspect generated target paths; only use `--force` when no existing files will be overwritten.
- Configure GitHub access with an SSH key registered to the GitHub account that owns or can access the target repository. For PR and permission operations, install GitHub CLI (`gh`) and authenticate it, or use an authorized GitHub integration.
- The target repository's own documentation/configuration determines project-specific test and build dependencies.

## SSH setup

Use a host alias for each account when multiple GitHub accounts are configured. Example OpenSSH config (replace the alias and key path with your own local values):

```sshconfig
Host github-owner
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github_owner
    IdentitiesOnly yes
```

Verify which account GitHub recognizes:

```sh
ssh -T git@github-owner
```

The greeting must match the intended authorized account (owner or verified collaborator). GitHub may return a non-zero exit code for this greeting even when authentication succeeded; inspect the greeting text. This confirms the SSH identity only. Then verify repository read access with `git ls-remote git@github-owner:OWNER/REPO.git` or by cloning/fetching. A matching greeting does not prove write permission or admin role. If SSH and your GitHub integration use different accounts, verify the writing account's role. Never paste a private key or token into chat.

For PR and owner-delivery operations, check GitHub CLI authentication and permission:

```sh
gh auth status
gh repo view OWNER/REPO --json viewerPermission --jq .viewerPermission
```

`ADMIN` is required for the owner delivery path. If `gh` is not authenticated, run `gh auth login --web` locally, complete the browser flow, then check again. Git SSH credentials and `gh` credentials are separate. A browser session is not required for clone/fetch/push when SSH is set up; use the matching account in the browser when you need to view or operate the PR interface.

## Delivery behavior

The default base branch is `main`. If another base is intended, name it exactly in the request. The Skill does not infer it from a feature branch or remote default.

- A user who explicitly requests a PR gets a PR; it remains open unless they also ask for a merge.
- A verified repository owner/admin who asks for end-to-end delivery can update the selected base directly when local checks pass and repository rules allow it. This avoids creating a redundant PR.
- If branch protection requires a PR, the Skill creates one and merges only after required checks and approvals pass. It never bypasses those gates.
- If admin authority is absent or unclear, the Skill pushes a feature branch and opens a PR. It does not merge on that path unless the user asks.

An empty repository has no base for a PR. The Skill seeds a minimal base commit only when the user explicitly asks to create and deliver a new project there; otherwise it stops before making a base commit.

The Skill does not discard unexplained local changes or force-reset a checkout. It reports checks as passed, failed, or not run. Read [SKILL.md](SKILL.md), [workflow gates](references/workflow-gates.md), and the [evolution policy](references/evolution-policy.md) for details.

## Evolution

The Skill can propose evidence-backed improvements but does not rewrite itself during a product task. General improvements require independent evidence from unrelated projects (or an explicit request to generalize), evaluation cases, and user approval. Project-specific guidance requires an exact trigger, stays within that context, and also requires approval. See the [evolution policy](references/evolution-policy.md) and [behavioral evaluation cases](evals/behavioral-cases.md).

## Resumable local workflow

Multi-task changes can use the bundled PowerShell 7 helpers without installing a CLI engine or a YAML parser. Run the installed `scripts/workflow.ps1` with `-Root` pointing at your project. Keep `.sdd-guo/` ignored; specifications, reports and review evidence live in `specs/<feature>/` and remain reviewable. Small edits can still use concise equivalent notes.

```powershell
& /path/to/sdd-guo/scripts/workflow.ps1 -Action doctor -Root /path/to/repo
& /path/to/sdd-guo/scripts/workflow.ps1 -Action init -Root /path/to/repo -Feature 002-user-auth
& /path/to/sdd-guo/scripts/workflow.ps1 -Action overview -Root /path/to/repo -Feature 002-user-auth
& /path/to/sdd-guo/scripts/workflow.ps1 -Action resume -Root /path/to/repo -Feature 002-user-auth
```

Stages are context, specify, plan, validate, implement, verify and deliver. The validate stage records semantic readiness before coding. Helpers reject skipped stages, missing structures, blocked/reportless tasks and stale confirmations. A structural pass does not prove requirements are correct or tests have run. Resume checks documents, HEAD and tracked/untracked working code; ignored files are outside the snapshot. State is local, bound to one checkout and written by one main agent.

Explicit confirmation points are opt-in; existing authorization drives ordinary progress. Events stay local with no remote telemetry. Doctor reports missing optional tools without blocking supported GitHub connector/concise-artifact workflows. Initial baseline creation is optional; once established, full/incremental synchronization is required. Code, incremental declarations and resulting baseline land together, including in PRs; the base's current baseline changes only on merge. See [runtime workflow](references/runtime-workflow.md), [task protocol](references/implement-protocol.md), [baseline workflow](references/baseline-workflow.md) and [source/adaptation notes](references/design-sources.md).

For an established `specs/baseline/`, use `baseline-snapshot`, `baseline-check -Mode preview`, `baseline-sync` and `baseline-check -Mode applied`. The helpers retain the original inputs, apply declared ADDED/MODIFIED/REMOVED blocks, preserve unaffected content, reject conflicts/scenario loss and make repeated synchronization a no-op. The agent still reviews semantic meaning; the helpers never invent requirement prose. Archive records verified delivery instead of merging the baseline a second time.

## Local verification

```powershell
pwsh -NoProfile -File tests/run-unit-tests.ps1
```

The dependency-free suite tests helper functions against isolated temporary fixtures. It uses no network, browser, remote repository or E2E tests. Run the Skill Creator `quick_validate.py` when available, and review [behavioral cases](evals/behavioral-cases.md) separately; helper tests do not certify all agent decisions. Respect the user's requested verification scope when applying the Skill to another project.

## Design references

The workflow was informed by concrete practices in these public projects, read on 2026-09-24. Popularity is context, not proof of quality; the Skill adopts only the practices suited to its scope:

- [obra/superpowers](https://github.com/obra/superpowers) — intent and design before implementation, evidence-first debugging, diff review, and final-state verification.
- [github/spec-kit](https://github.com/github/spec-kit) — staged specification/clarification/planning/tasks/analysis/implementation and repository-local workflow artifacts.
- [SpillwaveSolutions/sdd-skill](https://github.com/SpillwaveSolutions/sdd-skill) — brownfield investigation and explicit mapping of success criteria to verification.
- [tikalk/adlc-team-skills](https://github.com/tikalk/adlc-team-skills) — evaluation goldsets and regression graders as a way to test instruction changes.
