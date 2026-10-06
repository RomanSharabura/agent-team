---
name: pipeline-resume
description: Lead resumes a stalled Spec to PR flow from GitHub state alone - read the issue comments, work out the next step and spawn the right agent without a human.
metadata: { "openclaw": { "requires": { "bins": ["gh", "jq"] }, "primaryEnv": "GH_TOKEN" } }
---
# Відновлення зупиненого потоку

Увесь стан потоку живе в GitHub, тож будь-який твій хід може відновити роботу, навіть якщо ти не пам'ятаєш, що робив раніше. Цей скіл — про те, як з коментарів issue зрозуміти, на якому кроці все стоїть, і продовжити.

Потік зупиняється, коли хід, у якому прийшла відповідь агента, не має `sessions_spawn` (OpenClaw лишає інструменти з моменту `sessions_spawn` лише ходу, що продовжується після `sessions_yield`). Тоді ти пишеш коментар-блокер і зупиняєшся. Наступний твій хід — heartbeat або повідомлення людини — має повні інструменти і може продовжити сам.

## Коли застосовувати
- На кожному heartbeat-ході.
- Коли людина пише «Issue #N: продовж».

## 1. Знайти зупинені issues
```bash
R=Roman-Sharabura/dopamine-shop
gh issue list --repo $R --state open --label ai-in-progress --json number,updatedAt --jq 'sort_by(.updatedAt)'
gh issue list --repo $R --state open --label ai-blocked --json number,updatedAt --jq 'sort_by(.updatedAt)'
```
Порожньо в обох → нічого не пиши, заверши хід (`NO_REPLY` на heartbeat).

## 2. Зрозуміти крок
```bash
gh issue view <N> --repo $R --json comments --jq '.comments[] | "\(.createdAt) \(.body)"'
```
Читай знизу вгору. Останній коментар-блокер містить конверт у блоці ```json — це і є задача, яку не вдалося передати. Бери його як є.

Якщо конверта немає (старий блокер або передача обірвалася без коментаря), склади конверт за скілом `handoff` з останнього, що видно в issue:

| Останнє в issue | Наступний крок |
| --- | --- |
| «Взяв у роботу», відповіді ba немає | `to: ba`, `step: validate`, `attempt: 1` |
| «ba: спека PASS» | `to: architect`, `step: plan`, `attempt: 1` |
| «architect: план у гілці `<branch>`» | `to: dev`, `step: implement`, `attempt: 1`, той самий `branch` |
| «dev: draft PR #M, передаю qa» | `to: qa`, `step: test`, `attempt` з коментаря, `pr: M` |
| «qa: PASS, роблю review» | review робиш сам (скіл `pr-review`), без передачі |
| «qa: FAIL, повертаю dev (спроба K з 3)» | `to: dev`, `step: implement`, `attempt: K`, `notes` від qa без змін |

## 3. Перевірити, що крок ще потрібен
Не передавай наосліп: агент міг усе зробити, а загубився лише твій хід.
Спершу інструментом `subagents` подивись, чи немає активної сесії потрібного агента. Далі — що вже є в репозиторії:
```bash
gh pr list --repo $R --head <branch> --state all --json number,isDraft,title
gh api "repos/$R/contents/<spec>/qa-report.md?ref=<branch>" >/dev/null 2>&1 && echo "qa вже відпрацював"
```
- Є активна сесія потрібного агента → заверши хід без змін.
- Крок уже видно зробленим (є PR для `implement`, є `qa-report.md` для `test`) → переходь до наступного кроку, а не повторюй цей.

## 4. Продовжити
`sessions_spawn` з конвертом, одразу за ним `sessions_yield` (скіл `handoff`), і далі звичайні кроки з AGENTS.md.
Перед передачею: мітка `ai-in-progress` замість `ai-blocked`, якщо вона була, і коментар одним рядком, що ти продовжуєш і з якого кроку.

`sessions_spawn` недоступний і в цьому ході → нічого не пиши в issue вдруге (блокер уже є) і заверши хід. Наступний heartbeat спробує знову.

## Ніколи
- Не запускай двох агентів на одне issue одночасно.
- Не починай нове issue з `ai-ready`, поки є зупинене з `ai-in-progress`: спершу доводь почате.
- Не повторюй коментар-блокер: один блокер на одну зупинку.
