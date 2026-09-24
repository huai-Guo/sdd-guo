# Implementation plan

## Approach

Keep `SKILL.md` as a short lifecycle and routing entrypoint. Move operational gates to `references/workflow-gates.md`; keep evolution controls separately in `references/evolution-policy.md`. Update the user README for portable SSH/GitHub prerequisites and owner delivery. Add behavioral evaluation cases for both expected activation and boundaries. Retain the existing Codex UI metadata and Spec Kit project setup.

## Architecture and compatibility

- No executable workflow logic or dependencies are introduced.
- The skill continues to support Codex and existing Spec Kit integrations.
- Delivery policy is permission-aware and preserves user intent and GitHub rules.
- Evolution rules distinguish active instructions from candidates and require explicit promotion approval.

## Verification

- Run Skill Creator quick validation against this repository.
- Review frontmatter, all relative links, and all evaluation cases.
- Inspect the complete diff and Git status.
- Exercise key positive and negative scenarios using the behavioral evaluation table; report evaluation as a reasoned forward-check, not automated proof.
