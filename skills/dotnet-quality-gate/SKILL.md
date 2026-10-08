---
name: dotnet-quality-gate
description: Run build (warnings as errors), format check and all tests for dopamine-shop; dev must be fully green before any push, qa must have green build and format.
metadata: { "openclaw": { "requires": { "bins": ["dotnet"] } } }
---
# .NET quality gate

From the repository root, in order, every command must exit with code 0:

```bash
dotnet restore
dotnet build --no-restore
dotnet format --verify-no-changes --no-restore || { dotnet format --no-restore; echo "format applied, re-run gate"; exit 1; }
dotnet test --no-build
```

- The format step also checks the IDE "can be simplified" rules that dopamine-shop's `.editorconfig` raises to warnings (IDE0046 `if` → return/ternary, collection expressions, primary constructors, `readonly` unions, naming). Some of them, such as IDE0046, show up only here, not in `dotnet build`. `dotnet format` fixes most of them. When it cannot, follow `docs/conventions.md`, section "Code": rename by hand for IDE1006 (private fields `camelCase` without `_`), and move several guard clauses into a `void EnsureValid(...)` method instead of nesting `? throw :` ternaries. After `dotnet format`, read the diff before you commit.
- Warnings are errors (`TreatWarningsAsErrors`). Fix the cause; `#pragma warning disable` only with a comment giving the reason and a mention in the PR.
- Integration tests run on a real PostgreSQL. In the sandbox the server is set by the `TEST_POSTGRES_CONNECTION` variable; if it is empty and Docker is unavailable, the integration tests will fail — this is an environment problem: return `BLOCKED` with the error text, do not disable the tests.
- Architecture tests (`tests/DopamineShop.ArchitectureTests`) are part of `dotnet test`. A red architecture test means the code breaks a rule from `docs/conventions.md`: change the code.
- Tests are not skipped (`Skip`), deleted or weakened to turn green.
- Trim command output: show only lines with `error`, `Failed` and the summary.

For qa: `build` and `format` must be green before push, and red tests that show findings are pushed together with `verdict: FAIL`.

Result in the envelope: `gate: green` or `gate: red` with the first 20 error lines.
