# sdd-guo Constitution

## Core Principles

### I. Preserve User Intent and State
Respect the requested outcome, constraints, and delivery choice. Inspect repository and local state before changing it. Never discard unexplained work, guess a base branch, or broaden a task silently.

### II. Evidence Before Change
Observe current behavior and inspect relevant code, callers, tests, docs, and history. For defects, establish reproduction and root cause before fixing. Label assumptions and unresolved evidence.

### III. Acceptance Must Be Observable
Express the requested result as checkable criteria, map criteria to verification, and run relevant checks on the final tree. Report passed, failed, and unverified evidence accurately.

### IV. Least Scope and Least Authority
Make the smallest coherent change. Verify repository permissions before remote writes, distinguish SSH identity from access/admin rights, and honor branch protection and required review. Never expose credentials.

### V. Learning Is Scoped and Reviewable
Keep general and specialized guidance separate. One occurrence stays a candidate. Require evidence, an exact trigger for specialized rules, regression cases, and user approval before promoting persistent guidance.

## Constraints

- `main` is the default target base; an alternative must be named exactly.
- A verified owner/admin may use direct delivery only when the user has not requested an open PR and repository rules permit it.
- Required CI, review, or branch protection cannot be bypassed.
- Project-specific behavior belongs to the exact approved context and must not leak into general rules.

## Development workflow

1. Establish repository identity, access, base, and checkout state.
2. Clarify material requirements and document acceptance.
3. Inspect the current system and plan the smallest change.
4. Implement and verify against acceptance criteria.
5. Review final scope/evidence, then deliver via the authorized branch/PR path.

## Governance

This constitution guides development of the `sdd-guo` Skill. Amendments require a documented reason, clear scope, evaluation coverage, and user approval. A change to a specialized rule does not authorize changing a general rule.

**Version**: 1.0.0 | **Ratified**: 2026-09-24 | **Last Amended**: 2026-09-24
