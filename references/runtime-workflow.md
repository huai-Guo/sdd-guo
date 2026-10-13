# Local workflow runtime

Use for multi-task changes and interrupted work. PowerShell 7 and Git are required for helpers; concise notes remain supported for small edits or unavailable tooling. Run the installed Skill's scripts by absolute path with `-Root` pointing to the target repository; do not copy scripts into every project. Add `.sdd-guo/` to the target `.gitignore` before creating state. One main agent writes progress; delegated agents return reports without writing shared state.

## Commands and stages

```powershell
$workflow = '/absolute/path/to/sdd-guo/scripts/workflow.ps1'
& $workflow -Action doctor -Root /path/to/repo
& $workflow -Action init -Root /path/to/repo -Feature 002-user-auth
& $workflow -Action overview -Root /path/to/repo -Feature 002-user-auth
& $workflow -Action check -Root /path/to/repo -Feature 002-user-auth -Stage specify
& $workflow -Action confirm -Root /path/to/repo -Feature 002-user-auth -Stage specify -Evidence 'Inspected FR/SC coverage; structural check passed'
& $workflow -Action resume -Root /path/to/repo -Feature 002-user-auth
& $workflow -Action reopen -Root /path/to/repo -Feature 002-user-auth -Stage specify -Evidence 'Changed requirements require renewed analysis'
```

The seven stage names are `context -> specify -> plan -> validate -> implement -> verify -> deliver`. `currentStage` is the first unconfirmed stage; all confirmed means `complete`. `confirm` checks predecessors, current artifacts, freshness, configured confirmation points and task/review blockers before recording evidence. The script does not run tests or verify GitHub authority; the agent must inspect evidence first. `check` is read-only structural validation, and never changes state or grants semantic acceptance.

The default rules are in [checks.json](../assets/workflow/checks.json). Required headings accept standard Spec Kit suffixes; fenced examples do not satisfy checks. Supported checks: `file_not_empty`, `must_contain_heading`, `must_match_regex`, `must_not_match_regex`. Rules are JSON rather than YAML so PowerShell needs no parser dependency. Target-local `.sdd-guo/checks.json` may override defaults only within authorized scope; preserve coverage when customizing headings/language. Unknown check types and escaped paths fail. Semantic readiness belongs in [validation-template.md](../assets/workflow/validation-template.md).

## State and resumption

`.sdd-guo/state.json` records schema version, repository path, feature, flow ID, current stage, stage evidence/hashes, HEAD, task reports, findings and history. State files are machine-managed with atomic replacement; a corrupt/mismatched state is an error, never an implicit new flow. Local `events.jsonl` contains event type/subject/time and flow ID; state history is authoritative if logging is interrupted. There is no network reporting. Do not put credentials in evidence or reports.

On reentry, inspect overview and resume. Continue a matching, fresh flow without asking again when authorization persists. Resume detects HEAD and artifact changes, including uncommitted tracked/untracked code after implementation. Checkbox progress alone does not stale the plan. HEAD change is evidence to inspect, not automatic permission to discard work. Reopen the earliest affected stage, preserve artifacts, and revalidate downstream confirmations. A changed HEAD requires reopening context and renewed identity/base/rules inspection, including after the agent's own commit. Prior report files remain available but their active DONE records are invalidated when implementation inputs are reopened; re-record only after checking applicability and rerunning affected checks. Final-tree evidence remains mandatory.

Resume's next task is a candidate, not a dependency scheduler. Inspect its declared dependencies and blocking reports before execution. All `[x]` tasks still need matching reports before implementation is confirmed; all blocked tasks are never treated as done. If the flow is from a different request, preserve it separately only after determining the intended context; do not automatically clear it. No reset command is supplied.

## Confirmation, findings and doctor

[config.json](../assets/workflow/config.json) defaults to `confirmationPoints: []`: existing authorization drives ordinary progress. If the user wants explicit checkpoints, use a target-local config such as `{"version":1,"confirmationPoints":["plan","deliver"]}`. A configured point needs `-Acknowledgement` containing the actual approval source. Never invent approval; do not repeatedly request already granted approval. Neither autonomous mode nor acknowledgement overrides remote-write authority, user constraints or required repository reviews.

These settings control the helper's confirmations, not Spec Kit's native workflow-engine gates. When using that engine, honor its actual gates and supported syntax; do not synthesize an approve response from this config.

```powershell
& $workflow -Action finding -Root /path/to/repo -Feature 002-user-auth -Id REVIEW-01 -Severity error -Evidence 'SC-002 fails in local unit test'
& $workflow -Action finding -Root /path/to/repo -Feature 002-user-auth -Id REVIEW-01 -Severity error -Evidence 'Fixed; targeted test passes' -Resolved
```

Unresolved `error` findings block verify/deliver. `warn` findings remain in the delivery summary until resolved; do not downgrade a material failure to evade the gate. Doctor is read-only: check Git HEAD, config/state, and installed integration JSON if present. Missing gh/Spec Kit are optional findings because a GitHub connector and equivalent artifacts are supported. Doctor cannot authenticate SSH, prove permissions or infer branch rules; inspect those separately under [workflow-gates.md](workflow-gates.md).

## Baseline and archive

Keep feature directories and reviewable history. For recurring changes, maintain optional `specs/baseline/spec.md` for current delivered requirements and `design.md` for current technical decisions. Do not manufacture an all-system baseline from one incomplete feature. Mark delta requirements ADDED/MODIFIED/REMOVED; merge by stable IDs and explicit semantics. Missing MODIFIED targets, duplicate IDs and conflicting current behavior require investigation; ask only when an unresolved choice needs user input. Never append contradictory requirements or silently replace an entire baseline.

Prepare the reviewed baseline update and `specs/<feature>/ARCHIVED.md` in the delivery diff when the owner path is known; for a PR, keep baseline proposals out of the current delivered baseline until actual merge. The archive marker lists merged IDs/decisions, conflict resolutions, destination and evidence. Once delivery is verified, write `delivery-receipt.json` with `method` (`direct` or `merged-pr`), `baseCommit` (full SHA) and `destination`. Then:

```powershell
& $workflow -Action archive -Root /path/to/repo -Feature 002-user-auth -Evidence 'Verified merged/base commit and reviewed baseline delta'
```

Archive requires complete stages and nonempty baseline/marker/receipt artifacts. Open PR receipts are refused. It records local archived status; it neither merges prose nor writes GitHub. Receipt format checks do not independently prove remote delivery: inspect the actual remote commit/check status first. A feature can be delivered without opting into a baseline or archive.
