---
name: adr-writer
description: Draft an Architecture Decision Record in dopamine-shop docs/adr (English, MADR-like format used by the repo) with status proposed, for a human to accept in the PR.
metadata: { "openclaw": { "requires": { "bins": ["git"] } } }
---
# ADR writer

An ADR is needed when the plan introduces a decision that is not yet in `docs/adr` or `docs/conventions.md`: a new module, a new package, a new cross-cutting item (decorator, cache, transactions), a change to BuildingBlocks, a deviation from an existing ADR.
A regular slice that follows the reference does not need an ADR.

## File
`docs/adr/NNNN-slug.md`, where `NNNN` is the next number after the largest in `docs/adr/`, `slug` is in English, kebab-case.
Format — as in the existing ADRs (for example `0004-no-mediatr.md`):
```markdown
# NNNN. <Decision in one sentence>

- Status: proposed
- Date: YYYY-MM-DD
- Spec: SPEC-NNN

## Context
Which spec requirement or constraint forces the decision. Why the existing ADRs and conventions are not enough.

## Options
- **A** — <gist>. Pros / cons.
- **B** — <gist>. Pros / cons.

## Decision
The chosen option and why. What exactly changes in the code and the rules.

## Consequences
- What becomes easier, what becomes harder.
- Which architecture test or `docs/conventions.md` item should be added to keep the decision in place.
```
Up to 40 lines. At least two options, one of them "leave as is" if possible.

## Rules
- Status is always `proposed`. Only a human sets `accepted`, when merging the PR.
- Do not edit existing ADRs. A new decision supersedes an old one → the new ADR has a line `- Supersedes: NNNN`; do not touch the old one.
- Separate commit `docs(adr): NNNN <decision>` with a body: which REQ forced it and what was decided.
- Link to the ADR — in `plan.md` (line `ADR:`) and in the `notes` of the envelope for lead.
