# Baseline and incremental specification synchronization

## User Scenarios

A developer starts a change against an established baseline, records only the intended requirement/design delta, and delivers the synchronized baseline in the same Git commit/PR as the implementation. An unrelated requirement remains untouched. A second change against an older baseline stops instead of overwriting newer work. Repeated synchronization changes nothing. An open PR remains a proposal until merge.

## Requirements

- FR-001: With an established baseline, capture its exact spec/design inputs before planning and require an explicit incremental manifest, including a reason for documents with no changes.
- FR-002: Support ADDED/MODIFIED/REMOVED operations on stable requirement IDs and named/stable design sections. Preserve every untouched byte after LF normalization; reject duplicate IDs/operations, existing ADDED IDs, missing targets and missing removal reasons. Do not automatically rename stable IDs.
- FR-003: Agent-authored MODIFIED blocks include the entire resulting contract; accidental scenario loss is rejected unless removed scenarios are explicitly declared. The helper applies declared blocks, never invents semantic prose.
- FR-004: Provide read-only preview/check and explicit synchronization. Validate all documents and original hashes before writing. Repeated sync of the same manifest is a no-op. A changed baseline/manifest requires renewed review, not force overwrite. Restore already-written documents on a later write failure without erasing intervening edits.
- FR-005: Gate plan/readiness on valid baseline delta and verify/deliver on synchronized actual baseline. Include delta/baseline inputs in freshness. Changes without an established baseline remain supported; do not claim one partial feature is a full-system baseline.
- FR-006: Commit baseline changes with implementation for both PR and direct delivery. A feature-branch baseline is proposed; the selected base's baseline is current. Archive requires verified direct/merged receipt and verified synchronization; preserve feature history.
- FR-007: Preserve existing local-only telemetry, owner/PR authority, unit-only verification and scoped evolution. Update the installed copy after delivery, carrying forward the user's explicit replacement preference.

## Success Criteria

- SC-001: Unit cases verify mixed add/modify/remove, unchanged content, empty-change reasons, duplicates, missing IDs and explicit scenario removal (FR-001/002/003).
- SC-002: Unit cases verify read-only preview, stale baseline rejection, idempotency, late failure rollback and manifest change detection (FR-004).
- SC-003: Unit cases verify missing snapshot/delta and unsynchronized baseline block stages; no-baseline flows and original 28 runtime cases still work (FR-005/006).
- SC-004: Skill/artifact validators pass, source research records pinned implementations, and actual repo baseline is updated by this mechanism in the delivered diff (FR-007).
