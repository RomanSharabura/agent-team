# Roadmap

Збираємо по зростанню: робоча версія з двома агентами краща за шість, що не доходять до PR.

| Етап | Агенти і скіли | Результат |
| --- | --- | --- |
| 1 ✅ | lead + dev; github-issue, handoff, repo-conventions, minimal-api-feature, dotnet-quality-gate, git-commit; Docker-пісочниця | Issue `ai-ready` → draft PR з кодом і тестами для SPEC-001 |
| 2 ✅ | + qa (spec-to-tests з перевіркою контракту openapi.yaml), петля qa → dev (макс. 2); code review від lead (pr-review) | Тести пише незалежний агент, qa-report.md; PR приходить людині вже з review |
| 3 ✅ | + ba (spec-validate), architect (spec-to-plan, adr-writer); spec-trace і pr-create не окремі (матрицю REQ веде qa, PR відкриває dev, review робить lead) | Повний потік Spec → PR: спека перевірена до роботи, план з REQ-ID у гілці до коду |
| 4 | Paperclip: бюджет на агента, $ на PR; Stryker; memory MCP на C# | Команда працює за чергою, вартість видно |
| 5 | Скіли для фронтенду (React + TS, Chrome-розширення MV3) | Адмінка і web-клієнт через той самий потік |

## Відмінності від початкового дизайну
- GitHub замість Azure DevOps: issues і мітки замість work items і тегів, `gh` замість ADO MCP.
- Конфіг OpenClaw 2026.9.8 використовує `agents.entries` (а не `agents.list`) і `subagents.allowAgents` для делегування.
- dopamine-shop — модульний моноліт (Clean Architecture + vertical slices + DDD) без MediatR; правила перевіряють архітектурні тести, тож агентам не треба тримати їх у промпті.
- На етапі 1 dev сам пише plan.md, tasks.md, тести і draft PR. З етапу 2 qa-report.md і тести за сценаріями й контрактом пише qa; з етапу 3 plan.md і tasks.md пише architect у гілці до dev, а dev лише ставить галочки в tasks.md.
- Окремого скіла `xunit-tests` немає: unit-тести на домен і валідатори пише dev за `minimal-api-feature`, а qa перевіряє поведінку через HTTP і контракт (`spec-to-tests`). Stryker перенесено на етап 4.
- Окремого агента reviewer немає: review робить lead за скілом `pr-review`. Lead і так не пише код, тож він незалежний від dev, а зайвий агент — це ще один токен, модель і передача. Якщо review lead виявиться поверховим, винесемо скіл в окремого агента з сильнішою моделлю без змін у петлі.
- Review завжди йде як `COMMENT`: агенти пишуть від одного бота, а GitHub не дає апрувити чи «request changes» власний PR. Апрув і мерж — за людиною.
- qa пушить у ту саму гілку `ai/*`, що й dev, і не змінює `src/`. Червоні тести qa лишаються в гілці як доказ знахідки, поки dev не виправить код.
- ba не пише в issue сам: його вердикт і питання публікує lead (коментар «Spec validation» і мітка `ai-needs-input`). Так ba досить токена на читання, а всі зміни стану issue робить один агент.
- `clean-arch-plan` не окремий скіл: мапу шарів дають `docs/conventions.md`, ADR і архітектурні тести dopamine-shop, а architect читає їх через `repo-conventions`. Чернетки ADR architect додає зі статусом `proposed` у ту саму гілку; приймає їх людина разом з PR.
- Петлі qa і review повертають задачу лише dev: architect після dev не викликається. Якщо план виявився хибним, dev повертає `BLOCKED`, і рішення за людиною.
