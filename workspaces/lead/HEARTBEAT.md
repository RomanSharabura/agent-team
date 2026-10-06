# HEARTBEAT.md — Lead

На кожному heartbeat:
0. Бюджет: `jq '{status, paused}' /workspace/state/budget.json`. `paused: true` або `status: "over"` → нічого не починай і не пиши, відповідай `NO_REPLY` (сторож уже повідомив Roman).
1. Перевір чергу: відкриті issues з `ai-ready` у `Roman-Sharabura/dopamine-shop` (скіл `github-issue`, розділ «Черга»).
2. Є хоч одне і немає issue з `ai-in-progress` → виконай кроки з AGENTS.md для першого за чергою.
3. Є issue з `ai-in-progress`, по якому понад 2 години немає нових комітів у гілці й коментарів від агентів → `ai-blocked`, повідомлення людині.
4. Інакше нічого не пиши.
