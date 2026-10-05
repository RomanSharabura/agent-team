# Roadmap

Збираємо по зростанню: робоча версія з двома агентами краща за шість, що не доходять до PR.

| Етап | Агенти і скіли | Результат |
| --- | --- | --- |
| 1 | lead + dev; github-issue, handoff, repo-conventions, minimal-api-feature, dotnet-quality-gate, git-commit; Docker-пісочниця | Issue `ai-ready` → draft PR з кодом і тестами для SPEC-001 |
| 2 | + qa (spec-to-tests, xunit-tests, контракт з openapi.yaml), петля qa → dev (макс. 2) | Тести пише незалежний агент, qa-report.md |
| 3 | + ba (spec-validate), architect (spec-to-plan, adr-writer), reviewer (spec-trace, pr-review-checklist, pr-create) | Повний потік Spec → PR з матрицею REQ → тест → код |
| 4 | Paperclip: бюджет на агента, $ на PR; Stryker; memory MCP на C# | Команда працює за чергою, вартість видно |
| 5 | Скіли для фронтенду (React + TS, Chrome-розширення MV3) | Адмінка і web-клієнт через той самий потік |

## Відмінності від початкового дизайну
- GitHub замість Azure DevOps: issues і мітки замість work items і тегів, `gh` замість ADO MCP.
- Конфіг OpenClaw 2026.9.8 використовує `agents.entries` (а не `agents.list`) і `subagents.allowAgents` для делегування.
- dopamine-shop — модульний моноліт (Clean Architecture + vertical slices + DDD) без MediatR; правила перевіряють архітектурні тести, тож агентам не треба тримати їх у промпті.
- На етапі 1 dev сам пише plan.md, tasks.md, тести і draft PR. Ці кроки переходять до architect, qa і reviewer пізніше.
