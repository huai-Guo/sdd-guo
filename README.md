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

The greeting must match the intended repository owner/account. GitHub may return a non-zero exit code for this greeting even when authentication succeeded; inspect the greeting text. This confirms the SSH identity only. Then verify repository read access with `git ls-remote git@github-owner:OWNER/REPO.git` or by cloning/fetching. A matching greeting does not prove write permission or admin role. Never paste a private key or token into chat.

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

## Design references

The workflow was informed by concrete practices in these public projects, read on 2026-09-24. Popularity is context, not proof of quality; the Skill adopts only the practices suited to its scope:

- [obra/superpowers](https://github.com/obra/superpowers) — intent and design before implementation, evidence-first debugging, diff review, and final-state verification.
- [github/spec-kit](https://github.com/github/spec-kit) — staged specification/clarification/planning/tasks/analysis/implementation and repository-local workflow artifacts.
- [SpillwaveSolutions/sdd-skill](https://github.com/SpillwaveSolutions/sdd-skill) — brownfield investigation and explicit mapping of success criteria to verification.
- [tikalk/adlc-team-skills](https://github.com/tikalk/adlc-team-skills) — evaluation goldsets and regression graders as a way to test instruction changes.
