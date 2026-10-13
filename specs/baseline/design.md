# Current Skill design

## Instruction routing

SKILL.md holds purpose, seven stages and authority/evolution boundaries. workflow-gates.md preserves repository, repair, review and owner/PR decisions. Conditional runtime and implementation references expose mechanics only when needed. No new multi-tool orchestration engine is introduced.

## Local runtime

PowerShell 7 module plus a thin command entrypoint. JSON rules/config avoid additional parser/runtime dependencies. `.sdd-guo/` stores ignored state and JSONL events; feature documents, reports and evidence remain reviewable. Progress has one main writer, atomic per-file replacement and explicit mismatch recovery. State is bound to one checkout and one feature.

## Evidence and compatibility

Named stages avoid fractional numbering. Structural rules support nonempty files, headings and required/prohibited regexes outside fenced examples. Hashes detect document and tracked/untracked working-code changes; ignored files are excluded. Task descriptions participate in plan freshness; progress/checkpoint metadata does not. `[x]` is canonical and `[X]/[✓]` remain readable. A report or fingerprint cannot independently prove semantic acceptance or actual test execution.

## Delivery and learning

Scripts never perform GitHub writes or infer ADMIN from local authentication. Repository permission/rules evidence selects the existing delivery path. Baseline merging is a reviewed agent operation by stable requirement IDs; receipt checks enforce format and pending-PR exclusion without a prose merge engine. Configuration evolution follows the same general/specialized policy as instructions.

## Verification

The local PowerShell unit suite runs isolated temporary fixtures without network/E2E. Skill structure, local reference links and final diffs are checked separately. Behavioral cases remain distinct from executable helper coverage.
