#!/usr/bin/env bash
# Розклад команди в планувальнику OpenClaw (етап 4). Потрібен запущений шлюз.
# Запуск з кореня репо: ./scripts/automations.sh. Повторний запуск оновлює ті самі задачі (--declaration-key).
#   budget-guard     кожні 10 хв: облік витрат і пауза heartbeat за budget.json, без виклику моделі
#   morning-briefing пн–пт о BRIEFING_CRON (типово 09:00 Europe/Kyiv): брифінг lead у Slack
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f .env ]] && { set -a; source .env; set +a; }
export OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-$PWD/openclaw.json5}"
[[ -n "${SLACK_OWNER_ID:-}" ]] || { echo "У .env порожня змінна SLACK_OWNER_ID"; exit 1; }

# Команда виконується в процесі шлюзу, тож шляхи абсолютні: PATH шлюзу може не мати nvm.
node_bin="$(command -v node)"
openclaw_bin="$(command -v openclaw)"
slack=(--announce --channel slack --to "user:${SLACK_OWNER_ID}")

echo "== Сторож бюджету"
openclaw automations create "*/10 * * * *" \
  --name "Budget guard" \
  --description "Облік витрат агентів і пауза heartbeat lead за budget.json (scripts/budget-guard.mjs)" \
  --agent lead \
  --declaration-key agent-team/budget-guard \
  --command-argv "[\"$node_bin\",\"$PWD/scripts/budget-guard.mjs\"]" \
  --command-env "OPENCLAW_BIN=$openclaw_bin" \
  --command-env "OPENCLAW_CONFIG_PATH=$OPENCLAW_CONFIG_PATH" \
  "${slack[@]}" >/dev/null

echo "== Ранковий брифінг"
openclaw automations create "${BRIEFING_CRON:-0 9 * * 1-5}" \
  "Ранковий брифінг для Roman за скілом morning-briefing." \
  --name "Morning briefing" \
  --description "Lead: що зроблено, що в роботі, що чекає на Roman, витрати" \
  --agent lead \
  --declaration-key agent-team/morning-briefing \
  --tz "${BRIEFING_TZ:-Europe/Kyiv}" \
  --exact \
  --session isolated \
  "${slack[@]}" >/dev/null

openclaw automations list --agent lead
cat <<MSG

Перевірити зараз: node scripts/budget-guard.mjs --report
Брифінг вручну:   openclaw automations run <id "Morning briefing" зі списку вище>
MSG
