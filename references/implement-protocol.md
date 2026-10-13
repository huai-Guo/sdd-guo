# Task execution and reports

Read only the relevant spec acceptance criteria, plan decisions, task dependencies and affected callers for the next task. Tasks use `[ ]` pending, `[→]` in progress, `[x]` done and `[⚠]` blocked; existing `[X]` and `[✓]` are also readable. Emit canonical `[x]` for Spec Kit compatibility. One task is actively marked at a time by the main writer. `[P]` means independent work may be possible; it is not permission to delegate.

Before execution, check dependencies rather than blindly choosing the first pending row. Set in-progress, implement, run the relevant local verification and return a structured `[REPORT]` in the update, backed by a JSON report file in the feature directory. Use [task-report-template.json](../assets/workflow/task-report-template.json) as the schema example. `DONE` requires every declared check to be passed with concrete evidence; include inspection evidence when a low-impact task does not warrant a new test. Never hide a failed/unrun required check by omitting it. Reports supplement observed behavior; they cannot substitute for final-tree verification.

```powershell
& $workflow -Action task -Root /path/to/repo -Feature 002-user-auth -Id T012 -Status in_progress
& $workflow -Action task -Root /path/to/repo -Feature 002-user-auth -Id T012 -Status done -ReportPath specs/002-user-auth/reports/T012.json
```

For `BLOCKED`, provide `reason` and `resumeHint` and mark blocked using the same command with `-Status blocked`. Record a checkpoint in tasks.md using [checkpoint-template.md](../assets/workflow/checkpoint-template.md). Stop the blocked task and its dependents. Independent tasks may continue within authorization. When the blocker is actually resolved, change to pending and retry; a blocked report is never completion evidence. Script updates atomically replace each file, but tasks/state are two files: after interruption inspect any mismatch and re-record the report after verifying the row. Keep report files in Git for review; runtime state/events are ignored.

When delegation is explicitly authorized by the user or applicable project instructions, give the subagent only the task, ownership boundaries, dependencies, artifact paths, acceptance IDs and report format. Let it read design/spec sections on demand. It must not change shared state or deliver remotely. Inspect its diff and checks before recording DONE; an agent's success claim alone is insufficient. Otherwise the main agent executes the same protocol directly. No mandatory subagent or cross-tool integration is introduced.
