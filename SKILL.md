---
name: sdd-guo
description: Use for end-to-end feature work in an existing or new GitHub repository when the user wants requirements clarified, implementation verified, and changes delivered on a branch or to the base branch.
---

# SDD Guo

Deliver the requested software change through a traceable requirements, implementation, verification, review, and GitHub delivery flow. Preserve user intent and existing project behavior. Do not treat a completed checklist as evidence unless the result was actually inspected or run.

Read [README.md](README.md) for installation and authentication prerequisites. Follow [references/workflow-gates.md](references/workflow-gates.md) for repository, requirements, legacy repair, verification, review, and delivery decisions. For multi-task work or resuming interrupted work, use [references/runtime-workflow.md](references/runtime-workflow.md) and the bundled PowerShell helpers. For a small single edit, concise equivalent notes are sufficient; do not create ceremony without a concrete benefit.

## Workflow

1. **Establish repository and delivery context.** Confirm repository URL/owner, exact base branch (`main` by default), local checkout state, intended SSH identity, and actual repository access. Announce the selected account, repository, and base branch. Never switch, reset, or overwrite a checkout with unexplained local changes. Inspect any existing flow before initialization; use doctor/overview/resume to distinguish valid progress, stale evidence and blockers.
2. **Understand the requested outcome.** Inspect project guidance and relevant code before proposing implementation. Separate confirmed requirements, assumptions, non-goals, current behavior, and observable acceptance criteria. Ask only questions whose answers change a safe or correct implementation; do not proceed past a material ambiguity.
3. **Specify and plan.** Use the repository's Spec Kit workflow when available. Keep the spec focused on user-visible behavior and measurable acceptance. For a bounded change, use concise equivalent artifacts if Spec Kit commands are unavailable; do not invent command syntax. Inspect legacy callers, tests, history, and data flow before planning a repair.
4. **Validate readiness before implementation.** Analyze spec, plan and tasks for missing requirement/acceptance coverage, contradictory contracts, dependency cycles and unobservable outcomes. Use Spec Kit analyze when available, or record equivalent findings and a GO/NO-GO decision in `validation.md`. Structural checks support this review; headings alone never establish GO. Fix authorized inconsistencies before coding.
5. **Implement against evidence.** For defects, reproduce the failure and identify the cause before editing. Follow [references/implement-protocol.md](references/implement-protocol.md) for task reports and checkpoints. Preserve `[x]` compatibility. Blocked tasks remain incomplete; execute only tasks whose dependencies are satisfied. Delegate only when authorized, using scoped prompts and on-demand artifact reads. Avoid unrelated cleanup and speculative rewrites.
6. **Verify and review.** Map each acceptance criterion to evidence. Honor the user's test scope: local unit tests are sufficient when requested; do not add an E2E requirement. Run applicable checks on the final working tree and record acceptance evidence plus requirements/change review in `verification.md`. Preserve findings and disclose unresolved warnings. Do not report unrun checks as passed or deliver known material failures as complete.
7. **Deliver according to authority and repository rules.** If the user explicitly requests a PR, create one and leave it open unless they also ask for merge. Otherwise, a verified repository owner/admin may use the owner delivery path in `references/workflow-gates.md`; non-owners use a PR. Never bypass branch protection, required checks, or required review. Record the exact destination, permission/rules evidence and resulting commit/check status. Promote optional baselines only for verified delivered behavior; pending PR changes stay proposed.

## Evolution boundary

This Skill may identify improvement candidates; it must not silently rewrite its own instructions, configuration or checks, or widen its authority. Apply [references/evolution-policy.md](references/evolution-policy.md) when considering a reusable change. An explicit request to update this Skill authorizes that named revision; use existing authorization without repeatedly asking. One project-specific lesson must never become a universal rule by default.
