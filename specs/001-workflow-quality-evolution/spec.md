# Feature: Improve SDD workflow quality and controlled evolution

## Background

The current Skill connects repository setup, requirements, implementation, checks, and PR creation, but its gates are too high level. In recent use, repository identity/branch handling, requirements and legacy repair, final review/acceptance, and delivery overhead were reported as weak. This feature strengthens those decisions and defines bounded learning without giving the Skill silent authority to rewrite itself.

## User stories

### US1 — Safe, predictable GitHub setup

As a maintainer, I want repository identity, access, branch state, and destination established separately so that work cannot silently land under the wrong account or branch.

**Acceptance**

- SSH account identity is matched to the repository owner; actual read/write access and admin authority are verified separately.
- Dirty or ambiguous local state is preserved and resolved before checkout changes.
- `main` is the default base; another base requires an exact name.
- Feature branches start from the fetched base and unrelated branches are not silently reused.

### US2 — Better requirements and brownfield repair

As a user, I want the Skill to understand current behavior and evidence before changing old code, so that a fix restores intended behavior without speculative rewrites.

**Acceptance**

- Requirements separate background, current behavior, outcome, scope/non-goals, constraints, and observable acceptance.
- Assumptions are labeled, and questions are limited to material ambiguity.
- Legacy defects are reproduced or clearly marked unconfirmed; root cause is evidenced before a fix.
- A fix is scoped, preserves contracts, and includes regression verification when a suitable test layer exists.

### US3 — Evidence-based review and acceptance

As a user, I want acceptance criteria tied to final-state evidence, so that completion claims match what was actually checked.

**Acceptance**

- Each acceptance criterion has a verification method and a satisfied/unverified status.
- Relevant checks are rerun after the last code change; failures and unrun checks are explicit.
- Final review examines both requirement coverage and the complete diff.
- Independent review is claimed only if an independent reviewer actually ran.

### US4 — Efficient owner delivery

As a verified repository owner/admin, I want completed and locally verified work delivered without a redundant open PR when repository rules permit direct updates.

**Acceptance**

- Verified admin + no explicit PR-only request + unprotected direct-update path may update the selected base directly.
- When rules require a PR, the Skill waits for required checks and approvals and merges only when all gates pass.
- Explicit PR-only requests leave the PR open; unknown/non-admin actors use a PR.
- No path bypasses branch protection or required review.

### US5 — Controlled Skill evolution

As the Skill maintainer, I want general and specialized learning separated and constrained, so that one-off failures cannot broaden the default workflow.

**Acceptance**

- General promotion requires explicit generalization intent or independent evidence from at least two unrelated repositories/workflows, plus user approval and regression cases.
- Specialized rules require approval and an exact context trigger; absent/mismatched context does not activate them.
- A single observation remains a candidate; the Skill does not self-edit during a product task.
- Evaluations cover both activation and nearby non-activation boundaries.

## Non-goals

- Automatic merging when the user explicitly requests an open PR.
- Bypassing branch protections, required checks, or human review.
- Automatically storing project-specific observations in a target product repository.
- Creating a universal rule from a single task failure.
- Rewriting unrelated legacy code or adopting external projects' workflows wholesale.

## Constraints

- Use SSH for Git where a matching configured identity exists; never expose private key data.
- Keep the installed Skill entrypoint concise and place conditional detail in linked references.
- Preserve the repository's existing Skill metadata and installation experience.
