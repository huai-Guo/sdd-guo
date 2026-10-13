# Plan

## Technical Context

Keep the repository a Codex Skill. Add one dependency-free PowerShell 7 module and a thin command entrypoint, JSON rules/config, focused references and small templates. State lives in ignored `.sdd-guo/`; artifacts stay in `specs/<feature>/`. PowerShell 7 provides portable JSON dictionaries and UTF-8 behavior. Existing Spec Kit PowerShell scripts remain unchanged.

Use seven named stages: context, specify, plan, validate, implement, verify, deliver. The separate validate stage precedes implementation. Record hashes of relevant documents and tracked/untracked working code; task status changes alone do not invalidate the plan. Reopen invalidates downstream confirmations. Structural rules do not replace agent semantic review or actual tests.

## Project Structure

- `scripts/workflow.ps1`: command interface.
- `scripts/Workflow.psm1`: state, checks, tasks/reports, resume, findings, overview and doctor.
- `assets/workflow/checks.json`, `config.json`: editable defaults, no YAML dependency.
- `assets/workflow/*-template.md`: analysis, reports, checkpoints, baseline guidance.
- `references/runtime-workflow.md`, `implement-protocol.md`, `design-sources.md`: conditional detail.
- `tests/run-unit-tests.ps1`: isolated function-level local tests; no network or E2E.

## Decisions and boundaries

The user's optimization request authorizes this general Skill revision. Do not change the installed active copy as a side effect. Config changes are covered by evolution policy. No script performs GitHub writes or infers ADMIN from local tools. Doctor does not require gh when a connector is available, nor Spec Kit when equivalent artifacts are used. Baseline merging remains a reviewed agent operation; archive checks its artifacts and delivery receipt, without inventing an automatic prose merge engine.

## Verification

Run the PowerShell unit suite, Skill Creator validator, local Markdown link checks and final diff review. Record actual results in verification.md. No end-to-end tests.
