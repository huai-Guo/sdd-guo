---
name: sdd-guo
description: "Use for end-to-end feature work in a GitHub repository with Spec Kit: sync a target branch, clarify requirements, implement and test locally, then push a feature branch and create a pull request."
---

# SDD Guo

Use this workflow when the user asks for a feature or change to be developed in a GitHub repository through Spec Kit, including delivery as a pull request. Keep the work scoped to the requested change. For installation and authentication prerequisites, see [README.md](README.md).

## 1. Identify the repository and base branch

- Use the current repository if it is the intended project. Otherwise ask for its GitHub URL and a local destination if needed.
- The base branch defaults to `main`. Tell the user which base branch will be used. If they want another base branch, require them to state its exact name; never infer it from a feature branch or remote default.
- Prefer SSH for Git. Before access, inspect the OpenSSH config for GitHub hosts and resolve each relevant `IdentityFile`; check that candidate files exist without reading or displaying their contents. Match the SSH greeting from `ssh -T git@<alias>` to the GitHub owner/account requested by the user. If the default host authenticates as a different account, try the other configured GitHub aliases and use the matching alias in the remote URL (for example, `git@github-huai:OWNER/REPO.git`). Tell the user which account and key path will be used. Never ask the user to paste private key material. If no configured key matches, ask them to configure one locally or explicitly choose another transport. See [README.md](README.md) for details.
- Before pushing, verify that the SSH identity has write access; a separate GitHub integration's repository permissions do not prove the SSH identity can push. For PR creation, use authenticated GitHub CLI (`gh auth status`) or an authorized GitHub integration. A browser login to github.com is not required when credentials are already configured; if `gh` needs login, use `gh auth login --web` and wait for the user to complete its browser flow.
- Before switching or updating an existing checkout, inspect `git status`, current branch, remotes, and whether the target base exists on `origin`. If the worktree has uncommitted changes, the remote is ambiguous, or the target branch is missing, stop before changing checkout state and explain the issue.
- Fetch the target branch and fast-forward the local base to `origin/<base>`. Do not force-reset, discard changes, or resolve divergence by guessing. Create a new feature branch from that updated base; do not develop directly on the base branch.
- For a repository that is not cloned, clone the selected base branch, then create the feature branch.
- If the repository is empty and the requested base has no commit or ref, a pull request cannot be created until that base exists. When the user explicitly asks to create and deliver a project in that empty repository, seed the selected base with only a minimal README or equivalent bootstrap commit, tell the user this direct base-branch setup is required, and put the requested implementation on a feature branch for the PR. Otherwise stop and ask before creating a base-branch commit.

## 2. Prepare Spec Kit

- Inspect the repository's existing instructions (`AGENTS.md`, contribution guidance, build/test docs) and its current Spec Kit setup before changing files.
- If the `specify` CLI is unavailable, install it with `uv tool install specify-cli`, then resume. If the project lacks the Codex integration, inspect the paths the CLI will install. Initialize with `specify init --here --integration codex`; if the CLI requires `--force` only because the directory is non-empty, use it only after confirming no existing files will be overwritten. If initialization would replace or conflict with existing files, stop and describe the conflict.
- Use the project's existing constitution when present. Create or update one only when needed to guide this requested change; do not invent project-wide rules from incomplete evidence.

## 3. Run the SDD workflow

Use the available Spec Kit Codex commands (normally `$speckit-<command>`) and keep the artifacts focused on this feature:

1. `constitution` (only if needed): capture project-wide engineering principles when the repository has none; keep existing principles intact.
2. `specify`: capture the user need, scope, and observable acceptance criteria.
3. `clarify`: identify material ambiguities and ask the user only the questions that block a sound specification. Incorporate the answers before planning.
4. `plan`: inspect the codebase and select an implementation approach consistent with its stack and conventions.
5. `checklist` and `tasks`: turn the plan into verifiable requirements and an ordered implementation list.
6. `analyze`: resolve inconsistencies across the specification, plan, and tasks before coding.
7. `implement`: complete the approved scope and update relevant documentation.

If a command is unavailable, follow the installed integration's documented equivalent rather than fabricating command syntax.

## 4. Test and review locally

- Determine the relevant test, lint, type-check, and build commands from the repository's own configuration and documentation. Run the checks that cover the change and report exactly what ran and whether it passed.
- On failure, diagnose and fix issues within scope, then rerun the affected checks. Do not claim success when checks were skipped or failed. Do not push or create a PR until the relevant checks pass. If an external dependency or environment prevents testing, report the blocker and pause.
- Review the final diff for scope, accidental secrets, generated artifacts, and unrelated changes. Do not stage or commit unrelated user changes.

## 5. Push and create the pull request

After local verification passes:

1. Commit the feature changes on the feature branch with a concise message.
2. Push with upstream tracking, for example `git push -u origin <feature-branch>`.
3. Create a pull request targeting the selected base branch. Use `gh pr create` when GitHub CLI is available; otherwise use an available authenticated GitHub integration. Include a concise summary and the checks that passed.
4. Do not merge the PR. Return its URL and a short completion summary.

If authentication, repository permissions, network access, or PR tooling prevents a push or PR, stop at that boundary and report the exact failed step and error. Never claim that a PR exists until its URL or GitHub response confirms creation.
