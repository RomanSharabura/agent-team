---
name: spec-to-plan
description: Write plan.md and tasks.md for a dopamine-shop spec (modular monolith, Clean Architecture, vertical slices, own IQuery/ICommand handlers), every task tied to REQ-IDs.
metadata: { "openclaw": { "requires": { "bins": ["git"] } } }
---
# Spec → plan

Format follows GitHub Spec Kit: `spec.md` (what) → `plan.md` (how) → `tasks.md` (steps). Examples: `specs/001-admin-users-list/` and `specs/002-admin-edit-user/` in `main`.
Both files go in the spec folder, next to `spec.md`. Write them in English.

## What to figure out before the plan
- **Module.** Which module the spec concerns (`src/Modules/<M>`). A new module — only if the spec is explicitly about it, and then an ADR.
- **Slices.** New (`Features/<F>/`) or changes to existing ones; query or command (`IQuery<T>`, `ICommand<T>`, `ICommand`), what the handler returns and how that maps to the codes in `openapi.yaml`.
- **Domain.** New behavior → an aggregate method with invariants and `DomainException`. Which existing check to reuse (for example, one shared with `Register`).
- **Data.** New tables or columns → a migration (name), indexes for the filters and sorting from the spec. No schema changes → "Migration: no".
- **Contract.** Route, parameters, body, response codes — from `openapi.yaml` unchanged. If a more convenient contract seems desirable, that is a question for Roman (`QUESTIONS`), not an edit.
- **UI** (`web/admin`). Spec about the admin UI → slice `src/features/<module>/<feature>/` (skill `admin-ui-feature`), which page it appears on, which query keys to update after a change. UI-only spec → backend layers in the table are "no changes".
- **Risks.** What can go wrong: EF translation (value objects in `Where`), case and `LIKE` in Postgres, time zones, concurrent writes, distinguishing `null` from a missing field.

## plan.md
```markdown
# Plan — SPEC-NNN

Module: <M>. Slice: <F>. Contract and spec do not change.

| Layer | Files | Change |
| --- | --- | --- |
| Domain | `User.cs` | ... or "no changes" |
| Application | `Features/<F>/<F>Command.cs`, `<F>Handler.cs`, `<F>Validator.cs` | ... |
| Infrastructure | ... | ... or "no changes" |
| Presentation | `Features/<F>/<F>Endpoint.cs` | `<METHOD> <route>`, operation `<F>` |
| UI | `web/admin/src/features/<module>/<feature>/...` | ... or "no changes" |
| Tests | paths of unit, handler and HTTP tests | what they cover |

- Command/query: `<F>Command(...) : ICommand<T>`; how the result maps to response codes. With more than one outcome, `T` is a `readonly union <F>Result(<Dto>, <Marker>, ...)` with one case per response code (`docs/conventions.md`, "Handler results").
- REQ-001…: one line on how each REQ is covered (can be grouped).
- Migration: yes (`<Name>`) / no. New packages: no (or the package, the reason and a link to the ADR).
- ADR: none / `docs/adr/NNNN-slug.md` (proposed).
- Risks: ... or "none".
```
Paths are relative to `src/Modules/<M>/DopamineShop.Modules.<M>.<Layer>/` and `tests/`, as in the examples; for UI — from the repo root. Up to 40 lines.

## tasks.md
```markdown
# Tasks — SPEC-NNN

- [ ] 1. REQ-001, REQ-003: <what to do>. Done when: <verifiable criterion>.
- [ ] 2. ...
```
- 3–8 steps, in execution order: domain → application → presentation → migration (if any).
- Every step has a REQ-ID and a done criterion that dev verifies with a command or a test ("validator unit tests are green", "`dotnet ef migrations list` shows `<Name>`", for UI — "`REQ-00x` tests in `<Name>.test.tsx` are green, `npm run check` is green").
- One step is one dev commit, so a step must be complete and green on its own.
- Every REQ from `spec.md` is in at least one step. Check before committing:
```bash
S=specs/<NNN-slug>
comm -23 <(grep -oE 'REQ-[0-9]{3}' $S/spec.md | sort -u) <(grep -oE 'REQ-[0-9]{3}' $S/tasks.md | sort -u)   # must be empty
```
- dev ticks `[x]` when a step is done. You leave `[ ]`.

## What the plan does not contain
Code, signatures of all methods, test text. The plan says what and where, not how to write every line: dev does that following `minimal-api-feature`.
