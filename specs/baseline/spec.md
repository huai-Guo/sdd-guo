# Current sdd-guo behavior

This baseline describes the Skill distributed by the containing base-branch commit. Feature directories retain the rationale and incremental specifications. It covers the Skill's supported workflow, not every downstream application's behavior.

## Requirements

- BASE-001: Identify the intended GitHub account, repository, exact base (default main), checkout state and access separately. Preserve unexplained local changes. An authorized collaborator is valid, but cannot inherit ADMIN from a different writing identity.
- BASE-002: Establish current behavior, user intent, constraints and observable acceptance before planning. For legacy defects, inspect reproduction, callers, history and root cause; avoid speculative rewrites.
- BASE-003: Use existing Spec Kit integration or concise equivalents. Validate requirement/plan/task coverage, contradictions, dependencies and measurable acceptance before implementation; record GO/NO-GO for multi-task work.
- BASE-004: Multi-task flows support versioned repository-bound local state, ordered named stages, structural artifact checks, freshness diagnostics and explicit downstream reopening. Small single edits may use concise notes.
- BASE-005: Tasks preserve standard checkboxes, single-writer progress, evidence-backed DONE/BLOCKED reports and checkpoints. Blocked tasks and their dependents remain incomplete. Delegation requires authorization.
- BASE-006: Verify the final tree against acceptance and review both requirements and diff. Respect user-requested local unit-test scope, including E2E exclusions. Unrun checks are never passed; unresolved material findings block delivery.
- BASE-007: Explicit PR requests stay open unless merge is authorized. Verified ADMIN may deliver directly only when repository rules allow it. Non-admin/unknown permission uses a PR. Required checks, protections and reviews are never bypassed.
- BASE-008: Confirmation points are opt-in, honor existing authorization and do not expand permissions. Runtime events stay local; doctor distinguishes optional tools from blocking configuration/state errors.
- BASE-009: General and specialized evolution remain evidence-backed and scoped. An explicit source optimization request authorizes its named revision; other installed copies remain untouched. Config/check/template changes obey the same evolution boundary.
- BASE-010: Optional baselines describe verified delivered behavior. Reviewed deltas preserve history and surface conflicts. Pending PR changes remain proposals; archive receipts require actual direct/merged delivery evidence.

## Acceptance

Runtime invariants are covered by local function-level tests. Agent decision boundaries are defined in `evals/behavioral-cases.md` and assessed separately; script tests do not certify all natural-language decisions. Structural validation does not prove semantic consistency, test execution, SSH identity or remote authority.
