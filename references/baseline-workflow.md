# Full baseline and incremental changes

Use this path whenever the repository already has `specs/baseline/spec.md` and `design.md`. Synchronization is required for its multi-task changes, including PR delivery. Repositories without a baseline retain feature-only work; establish an initial baseline only from inspected, evidenced current behavior with an explicitly stated scope. Do not call one feature's spec a full-system baseline. A half-present/unsupported baseline needs inspection rather than a guessed replacement.

## Current versus proposed

The selected base branch's baseline describes delivered behavior. The feature branch's baseline describes that branch's proposed behavior. Include the incremental artifacts, resulting baseline and implementation in the same commit/PR. A pending PR has not changed the base's current baseline. After a merge/rebase, recheck the base and all affected acceptance; never land stale baseline content over a newer change. Archive follows verified base delivery and does not perform a second semantic merge.

## Snapshot, delta, check and sync

1. Read the current baseline before writing the feature spec. Initialize the flow; capture exact baseline inputs with `baseline-snapshot`. `baseline-inputs.json` stores the original normalized text, hashes and Git commit. It travels with the branch without workstation paths. Never overwrite an existing snapshot silently.
2. Draft the normal feature spec/plan/tasks and `baseline-delta.json`. The delta explicitly covers both baseline documents; use empty `operations` and a concrete `reason` when a document is unaffected. Read [the template](../assets/workflow/baseline-delta-template.json), then replace its examples with actual complete blocks. Requirement IDs are stable across changes. Design sections can use existing exact names or stable IDs such as `DES-001`.
3. Run `baseline-check -Mode preview` before plan/validate confirmation. It constructs the full proposed text in memory without changing files. Review semantic accuracy, acceptance coverage, removals and preserved scenarios alongside the normal GO/NO-GO analysis.
4. Implement and refine the delta if necessary, reopening plan/readiness when inputs change. Run `baseline-sync` as an implementation task, review the resulting diff and commit it with code. Run `baseline-check -Mode applied` before final verification. Repeated synchronization of the same manifest/output is a no-op.
5. Verify the final implementation and full baseline together. Deliver through the existing owner/PR rules. After actual direct/merged delivery, record destination, exact base commit and check status, then archive with the reviewed sync evidence. An open PR cannot authorize archived/current status.

```powershell
& $workflow -Action baseline-snapshot -Root /path/to/repo -Feature 003-session-change
& $workflow -Action baseline-check -Root /path/to/repo -Feature 003-session-change -Mode preview
& $workflow -Action baseline-sync -Root /path/to/repo -Feature 003-session-change
& $workflow -Action baseline-check -Root /path/to/repo -Feature 003-session-change -Mode applied
```

## Declared operations

The helper preserves untouched content after CRLF-to-LF normalization. Requirements may use `- FR-001: ...`, `- **FR-001**: ...` or `### FR-001: Title` / `### Requirement: FR-001: Title`. Canonical scenarios use `#### Scenario: Name`. A design block begins at `## Section name` or `## DES-001: Title`. Fenced examples are not managed IDs. Unsupported authored formats require explicit inspection/migration, not a destructive universal converter.

| Operation | Contract |
| --- | --- |
| ADDED | New ID, complete `after` block and an existing `afterId` insertion anchor. An existing ID is a conflict; it is never silently treated as modification. |
| MODIFIED | Existing ID, exact complete `before` block from snapshot and full resulting `after` block with the same ID. Preserve all surviving scenarios; list intentional scenario removals in `removedScenarios`. |
| REMOVED | Existing ID, exact `before` block and explicit `reason`. Do not supply replacement text. Removing the final managed block is refused; capability retirement is a separate scoped decision. |

Only one operation per ID per document. Stable ID renaming is excluded: modify its display title/body, or declare a reviewed remove/add migration with its reference updates. Operations are ordered; insertion anchors must exist when used. The script does not infer missing MODIFIED targets, invent prose or approve semantic correctness.

## Conflicts, rollback and review evidence

`baseline-check` rejects baseline text that differs from the captured inputs or the already-recorded output of this exact delta. `baseline-sync` preflights both documents before writing and rechecks inputs immediately before each write. A later write/record failure restores already-written documents if they still contain this operation's output; intervening edits are preserved and require manual recovery. One main agent remains the writer. There is no force flag or cross-process locking guarantee.

Commit `baseline-inputs.json`, `baseline-delta.json` and `baseline-sync.json` with the feature. The sync record pins original/delta/result hashes; it is synchronization evidence, not a remote-delivery receipt. A crash that leaves outputs without a valid record is a recoverable conflict: inspect the diff/snapshot, preserve incomplete outputs, restore the captured inputs or explicitly reconstruct reviewed evidence, then rerun. Do not fabricate a record to bypass review.

When another change wins the base, inspect its requirements and merge/rebase code normally. Preserve the old snapshot/delta in history, capture the newly reviewed base and regenerate the delta. Re-run affected consistency/acceptance checks. Updating the snapshot does not grant authority to overwrite another feature's intended behavior.

Existing baseline flows cannot confirm plan/validate without a valid snapshot/delta or confirm implement/verify/deliver without actual synchronized output. Freshness includes the delta inputs and final baseline, preventing a stale DONE/build report from authorizing newer spec content. Without an established baseline, these extra gates do not apply. Optional initial bootstrap is distinct from required ongoing synchronization.
