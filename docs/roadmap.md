# Roadmap

We build incrementally: a working version with two agents beats six that never reach a PR.

| Stage | Agents and skills | Result |
| --- | --- | --- |
| 1 ✅ | lead + dev; github-issue, handoff, repo-conventions, minimal-api-feature, dotnet-quality-gate, git-commit; Docker sandbox | Issue `ai-ready` → draft PR with code and tests for SPEC-001 |
| 2 ✅ | + qa (spec-to-tests with openapi.yaml contract check), qa → dev loop (max 2); code review by lead (pr-review) | Tests are written by an independent agent, qa-report.md; the PR reaches the human already reviewed |
| 3 ✅ | + ba (spec-validate), architect (spec-to-plan, adr-writer); spec-trace and pr-create are not separate (qa keeps the REQ matrix, dev opens the PR, lead reviews) | Full Spec → PR flow: spec validated before work, plan with REQ-IDs in the branch before code |
| 4 ◐ | Queue without manual start ✅ (heartbeat + `pipeline-resume`, sprint goal via milestone); budgets ✅ (`budget.json`, `budget-guard`, heartbeat pause); lead morning briefing ✅. Next: Stryker; memory MCP in C# | The team works from the queue, cost is visible |
| 5 ◐ | Admin UI ✅: Node 24 in the sandbox, skills `admin-ui-feature` and `admin-ui-gate`, UI sections in `spec-validate`, `spec-to-plan`, `spec-to-tests`, `pr-review`. Next: MV3 Chrome extension | Admin UI (first spec: SPEC-003) and web client through the same flow |

## Differences from the original design
- GitHub instead of Azure DevOps: issues and labels instead of work items and tags, `gh` instead of ADO MCP.
- The OpenClaw 2026.9.8 config uses `agents.entries` (not `agents.list`) and `subagents.allowAgents` for delegation.
- dopamine-shop is a modular monolith (Clean Architecture + vertical slices + DDD) without MediatR; the rules are enforced by architecture tests, so agents don't need to keep them in the prompt.
- In stage 1 dev writes plan.md, tasks.md, tests, and the draft PR itself. From stage 2 qa writes qa-report.md and the scenario and contract tests; from stage 3 architect writes plan.md and tasks.md in the branch before dev, and dev only checks off items in tasks.md.
- There is no separate `xunit-tests` skill: dev writes unit tests for the domain and validators per `minimal-api-feature`, and qa checks behavior via HTTP and the contract (`spec-to-tests`). Stryker moved to stage 4.
- There is no separate reviewer agent: lead does the review using the `pr-review` skill. Lead doesn't write code anyway, so it is independent of dev, and an extra agent means one more token, model, and handoff. If lead's review turns out superficial, we'll move the skill into a separate agent with a stronger model without changing the loop.
- Review is always posted as `COMMENT`: agents write as one bot, and GitHub doesn't allow approving or "request changes" on your own PR. Approve and merge are up to the human.
- qa pushes to the same `ai/*` branch as dev and doesn't change `src/`. qa's red tests stay in the branch as evidence of the finding until dev fixes the code.
- ba doesn't post to the issue itself: lead publishes its verdict and questions (a "Spec validation" comment and the `ai-needs-input` label). This way ba needs only a read token, and all issue state changes are made by one agent.
- `clean-arch-plan` is not a separate skill: the layer map comes from dopamine-shop `docs/conventions.md`, ADRs, and architecture tests, and architect reads them via `repo-conventions`. architect adds draft ADRs with status `proposed` to the same branch; the human accepts them together with the PR.
- Paperclip replaced by OpenClaw's native tracking (`openclaw gateway usage-cost`) and the budget guard: Paperclip sees and limits only runs it starts itself, while our agent chain runs inside OpenClaw. The "company" with a sprint goal is replaced by a GitHub milestone, the dashboard by the Control UI (Usage) and the morning briefing. The budget is enforced to the granularity of an agent step: the guard does not interrupt a step already running.
- The qa and review loops return the task only to dev: architect is not called after dev. If the plan turns out wrong, dev returns `BLOCKED`, and the decision is up to the human.
