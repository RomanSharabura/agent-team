---
name: morning-briefing
description: Lead's weekday morning briefing for Roman - what the team finished, what is in progress, what waits on Roman, sprint goal progress and spend from the budget snapshot.
metadata: { "openclaw": { "requires": { "bins": ["gh", "jq"] }, "primaryEnv": "GH_TOKEN" } }
---
# Ранковий брифінг

Хід приходить від автоматизації «Morning briefing» (пн–пт зранку). Твоя відповідь іде Roman у Slack як є, тож пиши лише брифінг: без вступу, українською, до 15 рядків. Нічого не змінюй у GitHub і нікому не передавай задачі: це лише звіт. Потік ведуть heartbeat і `pipeline-resume`.

## Дані
```bash
R=Roman-Sharabura/dopamine-shop
SINCE=$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ)   # у понеділок: '72 hours ago'
# Зроблено: PR, змерджені за період, і issues, що дійшли до ai-review
gh pr list --repo $R --state merged --search "merged:>=$SINCE" --json number,title,url
gh issue list --repo $R --state open --label ai-review --json number,title,updatedAt
# У роботі і зупинене
gh issue list --repo $R --state open --label ai-in-progress --json number,title,updatedAt
gh issue list --repo $R --state open --label ai-blocked --json number,title,updatedAt
gh issue list --repo $R --state open --label ai-needs-input --json number,title,updatedAt
# Черга
gh issue list --repo $R --state open --label ai-ready --json number,title,milestone,createdAt
# Ціль спринту: відкритий milestone з найближчим due_on (без дати — найстаріший)
gh api "repos/$R/milestones?state=open&sort=due_on&direction=asc" \
  --jq '.[0] | {title, description, due_on, open_issues, closed_issues}'
# PR, що чекають на review Roman
gh pr list --repo $R --state open --search "review-requested:RomanSharabura" --json number,title,url
```
Крок для кожного issue в роботі бери з останнього підписаного коментаря (`gh issue view <N> --comments`), як у скілі `pipeline-resume`.

Витрати — зі знімка сторожа бюджету, сам нічого не рахуй:
```bash
jq '{updatedAt, status, paused, checks, team, agents: (.agents | map_values({today, yesterday}))}' /workspace/state/budget.json
```
Файлу немає або `updatedAt` старший за годину → рядок «Облік витрат не оновлювався з …, перевір автоматизацію Budget guard».

## Формат
```text
☀️ Брифінг <дата>
Ціль спринту: <milestone> — <closed>/<closed+open> issues, до <due_on>   (рядок лише якщо є milestone)
✅ Зроблено: #12 SPEC-004 змерджено; #14 на review у тебе (PR #15)
🔧 У роботі: #16 — dev, спроба 2 з 3
⏸ Чекає на тебе: #17 ai-needs-input (2 питання до спеки); PR #15 review
📥 Черга: 3 issues, наступне #18 SPEC-007
💸 Вчора $4.20 (dev $2.90, qa $0.80, …), з початку місяця $31.50 з $150; ≈ $2.10 на PR
```
- Порожні рядки пропускай; якщо за період нічого не сталося і нічого не чекає, напиши одним рядком, що черга порожня і команда простоює.
- «≈ $ на PR»: вчорашні витрати команди поділені на кількість issues, що вчора дійшли до `ai-review`; немає таких → рядок без цієї частини. Це наближення, так і пиши «≈».
- `paused: true` або в `checks` є `over` → перший рядок після заголовка: «⛔ Команда на паузі через бюджет: <що перевищено>».
- Посилання на issues і PR — повні URL, Slack робить їх клікабельними.
