# Workflow gates

Use these gates to make each phase observable. Scale the depth of artifacts to change risk; keep the decision criteria intact.

## 1. Repository, identity, and branch

- Confirm the intended repository from the open checkout or an explicit URL. Record the repository owner and the requested base branch; default to `main`. If another base branch is needed, use its exact user-provided name.
- Prefer SSH. Read SSH configuration and inspect only public identity metadata and key-file existence, never key contents. Match `ssh -T git@<alias>`'s greeting to the intended authorized account, which may be the owner or a verified collaborator. This verifies identity only. A successful `git ls-remote` or clone/fetch verifies read access; a successful write check or authorized GitHub permission lookup verifies write access. If SSH and the GitHub integration use different accounts, verify the actual writing account's role before relying on the owner path.
- Before changing an existing checkout, inspect `git status`, current branch, remotes, local/remote base refs, and any related open PR. If there are user changes, ambiguous remotes, divergent state, or a missing base, preserve state and resolve the ambiguity before switching or fetching into that checkout.
- Fetch the intended base and confirm its ancestry. Create a uniquely named feature branch from the current fetched base. Resume an existing feature branch only when the user asked to continue it or it is clearly the same active task; inspect its diff and PR first. Never force-reset, overwrite, or silently reuse a branch with unrelated work.
- If the repository has no commit or base ref, a PR cannot be opened yet. Only when the user explicitly asks to create and deliver a new project there, seed the selected base with a minimal README/bootstrap commit, explain why this one setup commit goes directly to the base, then continue implementation on a feature branch (or use the verified owner path once a base exists). Otherwise stop and ask how to establish the base.
- Tell the user which account/repository/base are selected before remote writes. Do not claim SSH account matching proves repository access or admin authority.

## 2. Requirements and clarification

Before planning, capture the smallest useful brief:

| Item | What to establish |
| --- | --- |
| Background | Who encounters the problem and in what workflow? |
| Current behavior | What does the product/code do now? Cite observed files, behavior, or error evidence. |
| Desired outcome | What user-visible result should change? |
| Scope and non-goals | What is included and explicitly excluded? |
| Constraints | Compatibility, platform, security, performance, accessibility, or operational limits that matter here. |
| Acceptance | Observable conditions that can be checked after implementation. |

Mark assumptions as assumptions; do not convert them into requirements. Ask a concise question only when different answers would materially change design, compatibility, data handling, or acceptance. If the answer is not blocking, record a conservative assumption and continue. For a higher-risk architectural change, show the proposed design/spec and wait for the approval required by the user's request and the available workflow.

Inspect existing product guidance (`AGENTS.md`, docs, constitution), implementation, callers, tests, and relevant history before deciding what to change. Do not infer intended behavior from a single stale comment when code and tests disagree; report the conflict and seek stronger evidence.

## 3. Existing code and legacy repairs

For a bug or suspected old logic defect:

1. Capture the exact failing behavior, inputs, environment, and expected behavior. Reproduce it where feasible; if it cannot be reproduced, state what evidence is missing and avoid claiming a confirmed root cause.
2. Trace the value/control flow through the relevant caller, implementation, persistence/API boundary, and UI or output. Compare nearby known-good behavior, tests, commit history, and compatibility constraints.
3. State the root cause and evidence before changing code. Distinguish the triggering condition from the underlying defect.
4. Make the smallest coherent repair. Preserve existing contracts and unrelated old files. Do not replace or “modernize” legacy paths based only on style or an assumed intent.
5. Add a regression check that fails on the old behavior and passes on the repair when the project has an appropriate test layer. Run neighboring checks to detect compatibility regressions.

If historical behavior is ambiguous or the repair risks data loss, a public interface change, or broad compatibility effects, stop at the evidence/design boundary and ask the user before implementation.

## 4. Plan, implement, and validate

- Use Spec Kit's available `specify`, `clarify`, `plan`, `tasks`, `analyze`, and `implement` stages when installed. Keep project constitution changes limited to genuine project-wide principles. If commands are unavailable, follow the installed integration documentation or maintain concise equivalent spec/plan/checklist notes; never fabricate a command invocation.
- Link each acceptance criterion to an implementation location and a verification method. Include negative cases and edge cases that are material to the requested behavior. Resolve contradictions between spec, plan, tasks, and existing contracts before coding.
- For multi-task work, record the semantic consistency/coverage analysis and GO/NO-GO in `validation.md` before implementation. Structural checks only validate document shape. Use [runtime-workflow.md](runtime-workflow.md) for ordered confirmations and freshness; use [implement-protocol.md](implement-protocol.md) for reports and blocked recovery.
- Determine test/build/lint/type-check commands from project configuration and documentation. Run targeted checks first, then broader checks when change risk warrants them. For UI behavior, validate the actual rendered state at relevant viewport/input settings, not just source markup. Refresh/rebuild after asset or identifier changes so stale browser caches do not masquerade as current results.
- Respect the user's explicit test scope. When local unit tests are requested and E2E is excluded, do not add or run E2E tests. Disclose material acceptance surfaces not covered by the agreed checks; do not silently expand the testing assignment.
- On a failed check, read the complete failure, reproduce or isolate it, find its cause, fix within scope, and rerun affected checks. If blocked by environment or external services, report the exact blocker and do not call the acceptance criterion verified.
- Verify on the final tree after the last code edit. Report each required check as passed, failed, or not run, with evidence. Separate test evidence from code review findings.

## 5. Review and acceptance

Review in two passes:

1. **Requirements pass:** For each acceptance criterion, inspect the behavior or test evidence and mark satisfied, not satisfied, or unverified. Check stated non-goals and compatibility constraints.
2. **Change pass:** Inspect the final diff and relevant callers for correctness, error paths, boundary cases, unintended files, secrets, generated artifacts, and regressions. Re-check the final commit/tree rather than relying on an earlier state.

Use an available independent review capability for high-risk changes when it is genuinely available. Otherwise perform a fresh, adversarial pass against the acceptance criteria and diff; do not imply an independent reviewer participated. Fix material findings before delivery or disclose why they remain. Acceptance is evidence-based: identify what passed and any material untested surface without claiming broader coverage than observed.

Keep requirements evidence and change findings in `verification.md`. Runtime findings retain severity, evidence and resolution. Material unresolved failures block delivery; nonblocking warnings are disclosed. A DONE report or a successful build does not replace acceptance evidence.

## 6. Owner delivery vs PR

Determine authority using repository metadata from an authenticated GitHub CLI/integration (for example, `viewerPermission`) or an equivalent explicit source. `ADMIN` is required for owner/admin delivery. Matching an SSH greeting, having clone access, or being able to push proves neither ownership nor admin authority. If authority is missing or ambiguous, use the PR path.

- **Explicit PR request:** create a PR and leave it open unless the user also requested merge.
- **Verified owner/admin and no explicit PR-only request:** after final local checks and diff review, inspect branch protection/rulesets and repository workflow. If direct updates are allowed and no required review gate is being skipped, update the selected base directly and verify the pushed commit and resulting CI status. Do not create a redundant PR.
- **Owner/admin but branch rules require a PR:** open a PR, wait for required checks and required approvals, then merge when all repository gates are satisfied. Use the repo's normal merge method. Never bypass protections or manufacture an approval. If a required human review is pending, leave the PR open and tell the user what remains.
- **Not owner/admin or permission unknown:** push the feature branch and open a PR targeting the selected base. Do not merge unless the user asks.

After any merge, verify the resulting base commit and required CI status. Do not auto-delete branches or discard local state unless the user asked or repository policy clearly requires it. If push, PR, or merge fails, report the exact operation and error; do not claim delivery succeeded.

Record permission, rules, destination and observed check status in `delivery.md`. An open PR is a delivered proposal, not deployed/current behavior. Promote an optional current baseline only after verified base delivery; preserve feature history and review delta conflicts under [runtime-workflow.md](runtime-workflow.md).
