# Plan

## Technical Context

PowerShell 7, dependency-free JSON and existing workflow helpers. Keep semantic authorship in the agent. A feature snapshot stores baseline texts/hashes. A small incremental manifest declares exact before/after blocks, preserving untouched content deterministically. spec.md supports existing bullet IDs and canonical ID headings; design.md supports existing level-two named sections and stable IDs. Snapshot pins the original full baseline; sync metadata pins original/delta/output hashes.

## Project Structure

- `scripts/Baseline.ps1`: snapshot, parsing, preview/check, guarded sync and rollback helpers, loaded inside Workflow.psm1.
- `scripts/workflow.ps1`, `Workflow.psm1`: command routing, stage gates and freshness.
- `references/baseline-workflow.md`: operational lifecycle, bootstrap and PR semantics.
- `assets/workflow/baseline-delta-template.json`: explicit delta schema.
- `tests/run-unit-tests.ps1`: existing tests plus function-level baseline cases in an included file.

## Decisions

Adapt OpenSpec's full-versus-delta separation, explicit operations, idempotency and preflight/rollback. Preserve Spec Kit feature directories and acceptance artifacts. Keep stable IDs immutable; renaming displayed text is MODIFIED. Do not adopt silent ADDED-to-MODIFIED coercion, archive-without-sync, whole directory moves, or a new CLI runtime. Small changes without baselines remain lightweight. Existing baselines require synchronization even for PRs: the branch is a proposal and merge updates code/spec together.

## Verification

Only local unit tests. Validate sources/links/JSON/workflow structure separately. Review requirements and final diff. The user explicitly requested researching and modifying this shared Skill; no further blanket approval is needed. Backup/reinstall the active copy after verified source delivery, preserving earlier replacement authorization.
