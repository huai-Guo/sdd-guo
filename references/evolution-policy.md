# Controlled evolution policy

“Self-evolution” means identifying evidence-backed candidates and improving this Skill through a reviewable, reversible change. It does not mean the Skill silently edits its own instructions during a customer task.

## Learning lanes

| Lane | Trigger | Scope | Promotion rule |
| --- | --- | --- | --- |
| General | The user explicitly asks to generalize a lesson, or the same material failure is independently observed in at least two unrelated repositories/workflows. | The shared `sdd-guo` workflow. | Keep it minimal, prove it applies outside the originating case, pass the applicable evaluation cases, and get explicit user approval before changing active general guidance. |
| Specialized | The user explicitly asks to retain a lesson for a named repository, stack, environment, or workflow, or asks to propose such a scoped rule. | Only the exact named context and explicit trigger. | Store separately from general rules; require a positive match for every trigger condition. If context is absent or differs, do not apply it. User approval is required before adding the scoped rule. |

A repeated issue in one repository is specialized evidence, not proof of a general rule. A single occurrence is a candidate only. User corrections constrain the current task immediately but do not, by themselves, authorize broader persistence.

## Candidate record

Before proposing a persistent change, record:

1. **Observed failure or improvement** — what happened, with a concrete example or artifact.
2. **Evidence and frequency** — repository/workflow context, whether reproduced, and whether independent cases exist.
3. **Lane and exact trigger** — general or specialized; for specialized rules, state the repository/context predicate precisely.
4. **Proposed smallest rule** — the behavior to change and the behavior explicitly left alone.
5. **Risks and boundaries** — especially any effect on permissions, remote writes, branch/merge behavior, privacy, or destructive actions.
6. **Evaluation cases** — at least one case that should pass and one nearby case that must not trigger the rule.

Keep candidates separate from active instructions until reviewed. If the user only asked to complete product work, do not edit the Skill or project policy as a side effect; offer the candidate in the completion summary only when it is useful.

## Promotion and rollback gates

- Change only the lane the user approved. Never move a specialized rule into general guidance without satisfying the general trigger and receiving approval for that scope change.
- Do not evolve invariants: never expose credentials, discard unexplained user changes, guess a base branch, claim checks that were not run, bypass required review/protection, or merge without the authority described in the workflow policy.
- Add the evaluation cases before or with the rule. Check both intended activation and non-activation boundaries. Run the Skill Creator validator and relevant behavioral checks after changes.
- Review the final diff for unrelated guidance, broadened permissions, accidental personal data, and contradictory instructions. Keep changes small and reversible. If a promoted rule causes a regression, revert or narrow it rather than adding a chain of exceptions.
- Report the evidence, lane, trigger, evaluations run, and any remaining uncertainty whenever an evolution is proposed or promoted.
