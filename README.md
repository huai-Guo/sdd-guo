# SDD Guo

`sdd-guo` is a Codex Skill for completing a feature in a GitHub repository with GitHub Spec Kit. It guides the work from repository and branch setup through requirements, implementation, local checks, pushing a feature branch, and opening a pull request.

## What it covers

- Identify the current GitHub repository or clone a repository URL.
- Sync a selected base branch and create a feature branch.
- Clarify the requested change and use Spec Kit to specify, plan, break down, analyze, and implement it.
- Run the project's relevant local checks and review the resulting diff.
- Commit and push the feature branch, then create a PR targeting the selected base branch.

The base branch is `main` by default. If the work should target another branch, provide its exact name in the request. The Skill does not merge PRs. It stops before updating a checkout with uncommitted changes, and it does not push or create a PR when relevant checks have failed. An empty repository has no base commit, so GitHub cannot accept a PR yet. If you explicitly ask to create a project in that empty repository, the Skill may seed the base branch with a minimal README commit, explain that setup, and put the implementation on a feature branch for the PR.

## Requirements

- **Codex:** the `sdd-guo` Skill installed and available in the current Codex session.
- **Git:** installed and able to clone/fetch/push the repository.
- **Spec Kit CLI:** installed with `uv tool install specify-cli` (`uv` is required). The target repository also needs the Codex integration, initialized with `specify init --here --integration codex` if it is not already set up. If the CLI requires `--force` because the directory contains a README, use it only after confirming the installed paths do not conflict with existing files; do not overwrite existing work.
- **GitHub repository access:** read permission to clone/fetch, and write permission to push a feature branch and open a PR. For a private repository, the signed-in GitHub account must have access to that repository.
- **Pull request authentication:** either GitHub CLI (`gh`) authenticated for the repository, or an authorized GitHub integration available in Codex.

The Skill relies on the target project's own build and test tools. Install any project-specific dependencies described by that repository before asking it to run checks.

## GitHub login and credentials

You do **not** need to stay signed in to github.com in a browser for each run if Git and GitHub CLI credentials are already configured. The browser is used once when completing the GitHub CLI's web authentication flow, if needed.

### Recommended: SSH for Git, GitHub CLI for PRs

**This Windows environment has two GitHub SSH identities configured.** The OpenSSH alias `github.com` uses `C:\Users\gjy\.ssh\id_ed25519_github` and authenticates as `GuoStudent`. The alias `github-huai` uses `C:\Users\gjy\.ssh\id_ed25519_github_huai` and authenticates as `huai-Guo`. The Skill should inspect the local SSH config first, match the greeting to the requested repository owner, and tell the user which identity and key path it selected before accessing the repository. For `huai-Guo` repositories, use a remote such as `git@github-huai:huai-Guo/REPO.git`. Do not send or paste private key material into chat. On another computer, inspect its own SSH config and use an identity configured for the requested GitHub account.

1. Verify the candidate SSH alias authenticates as the intended GitHub account. For `huai-Guo`, use:

   ```powershell
   ssh -T git@github-huai
   ```

   A successful response should greet `huai-Guo`. GitHub may return a non-zero process status for this greeting; check the response text. If the greeting is for the wrong account, inspect the other configured GitHub aliases and try the one that matches the requested owner. This verifies the account; the actual clone/fetch verifies repository access. On another computer, configure an SSH key for the desired GitHub account before using this Skill.

2. Install GitHub CLI and authenticate it if it is not already logged in:

   ```powershell
   gh auth status
   gh auth login --web
   ```

   Run `gh auth login --web` only when `gh auth status` reports that no valid login is configured. Complete the browser prompt, then verify again with `gh auth status`. The account needs permission to create a PR in the repository.

Git uses the SSH key for clone, fetch, and push. `gh` uses its own stored login to create the PR. Configuring one does not configure the other.

### Alternative: HTTPS credentials or Codex GitHub integration

- With an HTTPS remote, Git must already have a working credential manager or other approved credential method for clone/fetch/push. GitHub CLI or an authorized Codex GitHub integration can create the PR.
- An authorized Codex GitHub integration can create the PR, but it does not by itself provide Git clone/push credentials. Configure Git access separately.
- Never paste a password, personal access token, or private SSH key into the chat. If authentication is missing, complete the appropriate local login flow yourself and then resume.

## How to use

Run the Skill from the repository directory, or include a GitHub repository URL and the requested feature:

```text
$sdd-guo Add CSV export to the order list. Use main as the base branch.
```

If the intended base is not `main`, state the exact branch name:

```text
$sdd-guo Add CSV export to the order list. Use release/2.x as the base branch.
```

If no repository is open in the current directory, include its GitHub URL. The Skill checks access and local state, creates a feature branch from the selected base, follows the Spec Kit workflow, runs relevant checks, and then pushes and opens the PR. If a required credential, permission, dependency, clarification, or passing check is missing, it reports the blocker and stops at that step.

## References

- [GitHub Spec Kit](https://github.com/github/spec-kit)
- [GitHub CLI authentication](https://cli.github.com/manual/gh_auth_login)
