#!/usr/bin/env bash
# Team schedule in the OpenClaw scheduler (stage 4). Requires a running gateway.
# Run from the repo root: ./scripts/automations.sh. Re-running updates the same jobs (--declaration-key).
#   budget-guard     every 10 min: spend tracking and heartbeat pause per budget.json, no model call
#   morning-briefing Mon–Fri at BRIEFING_CRON (default 09:00 Europe/Kyiv): lead briefing in Slack
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f .env ]] && { set -a; source .env; set +a; }
export OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-$PWD/openclaw.json5}"
[[ -n "${SLACK_OWNER_ID:-}" ]] || { echo "Variable SLACK_OWNER_ID is empty in .env"; exit 1; }

# The command runs in the gateway process, so paths are absolute: the gateway PATH may lack nvm.
node_bin="$(command -v node)"
openclaw_bin="$(command -v openclaw)"
slack=(--announce --channel slack --to "user:${SLACK_OWNER_ID}")

echo "== Budget guard"
openclaw automations create "*/10 * * * *" \
  --name "Budget guard" \
  --description "Agent spend tracking and lead heartbeat pause per budget.json (scripts/budget-guard.mjs)" \
  --agent lead \
  --declaration-key agent-team/budget-guard \
  --command-argv "[\"$node_bin\",\"$PWD/scripts/budget-guard.mjs\"]" \
  --command-env "OPENCLAW_BIN=$openclaw_bin" \
  --command-env "OPENCLAW_CONFIG_PATH=$OPENCLAW_CONFIG_PATH" \
  "${slack[@]}" >/dev/null

echo "== Morning briefing"
openclaw automations create "${BRIEFING_CRON:-0 9 * * 1-5}" \
  "Morning briefing for Roman using the morning-briefing skill." \
  --name "Morning briefing" \
  --description "Lead: what is done, what is in progress, what is waiting on Roman, spend" \
  --agent lead \
  --declaration-key agent-team/morning-briefing \
  --tz "${BRIEFING_TZ:-Europe/Kyiv}" \
  --exact \
  --session isolated \
  "${slack[@]}" >/dev/null

openclaw automations list --agent lead
cat <<MSG

Check now:        node scripts/budget-guard.mjs --report
Manual briefing:  openclaw automations run <id of "Morning briefing" from the list above>
MSG
