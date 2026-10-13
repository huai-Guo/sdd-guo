# Evidence and adopted practices

Read on 2026-10-13 using GitHub repository metadata and source documents. Stars are a snapshot for discovery, not a quality gate. The local user-supplied optimization guide is a proposal, not an installed dependency; its CodeSpec source/version claims were not independently validated here.

| Project / observed stars | Source inspected | Adopted practice | Boundary |
| --- | --- | --- | --- |
| github/spec-kit / 140,989 | [analyze command](https://github.com/github/spec-kit/blob/main/templates/commands/analyze.md) | Cross-artifact coverage, contradictions and dependency analysis before implementation; targeted artifact reads | Preserve existing integration; structural checks cannot replace semantic analysis |
| obra/superpowers / 298,217 | [verification-before-completion](https://github.com/obra/superpowers/blob/main/skills/verification-before-completion/SKILL.md) | Fresh observed checks before completion claims; inspect delegated results | Honor requested local unit-test scope; do not import mandatory testing ceremony |
| Fission-AI/OpenSpec / 71,751 | [concepts](https://github.com/Fission-AI/OpenSpec/blob/main/docs/concepts.md) | Lightweight behavior specs, change deltas and current baseline separation | Optional baseline; preserve feature history; no automatic prose merge or new CLI |

The guide's 13 suggestions are addressed by: state (01), structural rules (02), overview (03), opt-in confirmation (04), reports (05), compatible task statuses/checkpoints (06), freshness/resume (07), authorized scoped delegation (08), named pre-implementation validate stage (09), persistent findings (10), read-only doctor (11), local flow/events (12), reviewed optional baseline/archive (13). Preserve delivery authority, controlled evolution and evaluation cases throughout.

Deliberate adaptations: use dependency-free JSON instead of YAML; use seven named stages rather than ambiguous step 4.5; emit `[x]` for existing Spec Kit tooling; continue already-authorized fresh work without a redundant resume question; do not treat blocked tasks as complete; do not require gh/Spec Kit when supported alternatives exist. Remote telemetry and a large workflow engine are outside scope.
