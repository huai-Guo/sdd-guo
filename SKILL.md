---
name: sdd-guo
description: Use for end-to-end feature work in an existing or new GitHub repository when the user wants requirements clarified, implementation verified, and changes delivered on a branch or to the base branch.
---

# SDD Guo

Deliver the requested software change through a traceable requirements, implementation, verification, review, and GitHub delivery flow. Preserve user intent and existing project behavior. Do not treat a completed checklist as evidence unless the result was actually inspected or run.

Read [README.md](README.md) for installation and authentication prerequisites. Follow [references/workflow-gates.md](references/workflow-gates.md) for repository, requirements, legacy repair, verification, review, and delivery decisions. Follow [references/evolution-policy.md](references/evolution-policy.md) only when considering a reusable change to this Skill or project-specific guidance.

## Workflow

1. **Establish repository and delivery context.** Confirm repository URL/owner, exact base branch (`main` by default), local checkout state, matching SSH identity, and actual repository access. Announce the selected account, repository, and base branch. Never switch, reset, or overwrite a checkout with unexplained local changes.
2. **Understand the requested outcome.** Inspect project guidance and relevant code before proposing implementation. Separate confirmed requirements, assumptions, non-goals, current behavior, and observable acceptance criteria. Ask only questions whose answers change a safe or correct implementation; do not proceed past a material ambiguity.
3. **Specify and plan.** Use the repository's Spec Kit workflow when available. Keep the spec focused on user-visible behavior and measurable acceptance. For a bounded change, use concise equivalent artifacts if Spec Kit commands are unavailable; do not invent command syntax. Inspect legacy callers, tests, history, and data flow before planning a repair.
4. **Implement against evidence.** For defects, reproduce the failure and identify the cause before editing. Prefer the smallest change that restores intended behavior. Add or update regression coverage where the project supports it. Avoid unrelated cleanup and speculative rewrites.
5. **Verify and review.** Map each acceptance criterion to evidence. Run the project checks that cover the changed behavior on the final working tree. Review the final diff for scope, regressions, compatibility, and sensitive data. Do not report an unrun check as passed or deliver known failures as complete.
6. **Deliver according to authority and repository rules.** If the user explicitly requests a PR, create one and leave it open unless they also ask for merge. Otherwise, a verified repository owner/admin may use the owner delivery path in `references/workflow-gates.md`; non-owners use a PR. Never bypass branch protection, required checks, or required review. Report the exact destination and evidence.

## Evolution boundary

This Skill may identify improvement candidates; it must not silently rewrite its own instructions or widen its authority. Apply the scope, trigger, evidence, approval, and regression rules in [references/evolution-policy.md](references/evolution-policy.md). One project-specific lesson must never become a universal rule by default.
