---
name: repo-conventions
description: Read dopamine-shop conventions, ADRs, architecture tests and the reference slice before changing any code.
---
# Repo conventions

Before any code change in `dopamine-shop`:
1. Read `docs/conventions.md` in full. It overrides your habits and general .NET knowledge.
2. Skim the headings of `docs/adr/*.md`; read the ones relevant to the task.
3. Open the reference slice: `specs/000-admin-get-user/` and the code its `plan.md` refers to (Users module, GetUserById feature).
4. Skim `tests/DopamineShop.ArchitectureTests`: it holds the rules for layers, modules, slices and DDD as code. They run with `dotnet test` and are not weakened.
5. Found a pattern in the repo that is not in conventions.md → record it in your `MEMORY.md` and mention it in the PR under "What changed", so the human can decide whether to add it to conventions.

Do not change `docs/conventions.md` or existing `docs/adr/` yourself: the human does that. architect may add a new draft ADR with status `proposed` (skill `adr-writer`); the human accepts it when merging.
