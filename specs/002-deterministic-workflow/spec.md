# Deterministic, resumable SDD workflow

## User Scenarios

An interrupted agent can inspect the current feature, completed stages, pending task and stale evidence without deleting earlier work. A developer can reject incomplete specifications before implementation and use local unit tests without being forced into browser or end-to-end testing.

## Requirements

- FR-001: Keep repository-bound, versioned local state, ordered stages, history and a flow ID. Reject skipped stages, mismatched features and corrupt state; never silently reset.
- FR-002: Check document headings, regex requirements/prohibitions and nonempty files with actionable errors. A structural pass is not semantic acceptance.
- FR-003: Before implementation, record requirement/acceptance/task coverage, dependencies, contradictions and a GO/NO-GO decision.
- FR-004: Preserve Spec Kit `[ ]`/`[x]` compatibility, support in-progress/blocked markers, require a structured task report and evidence for completion, and retain blocked reasons and recovery hints.
- FR-005: Detect HEAD, document and working code changes on resume; stale evidence requires revalidation. Show the workflow and next task without unnecessary confirmation.
- FR-006: Confirmation points are opt-in and never expand authorization. Record review findings and local events. Doctor reports optional dependencies separately from blockers.
- FR-007: Maintain optional current baselines and immutable feature history. Open PRs do not become delivered baselines; conflicts cannot silently overwrite existing requirements.
- FR-008: Preserve owner/PR authority and controlled evolution boundaries. Use local unit verification only for this change; no E2E, remote telemetry, JS engine or mandatory delegation.

## Success Criteria

- SC-001: Unit tests reject stage skipping, feature mismatch, corrupt state, invalid paths, missing headings and NO-GO without mutating valid prior state (FR-001/002/003).
- SC-002: Unit tests verify checkbox compatibility, single active task, evidence-backed reports, blocked recovery, and stale HEAD/document/code detection (FR-004/005).
- SC-003: Unit tests verify configurable confirmation points, blocking review findings, local event flow IDs and read-only doctor behavior (FR-006).
- SC-004: Documentation specifies safe baseline promotion and pending PR handling; tests reject archive without confirmed delivery or baseline/marker artifacts (FR-007).
- SC-005: Skill validator and local unit suite pass; final diff preserves delivery and evolution policy, and publishes no runtime state or credentials (FR-008).
