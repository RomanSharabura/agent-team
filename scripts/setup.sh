#!/usr/bin/env bash
# Одноразове налаштування на машині Roman. Запуск з кореня репо: ./scripts/setup.sh
set -euo pipefail

cd "$(dirname "$0")/.."
[[ -f .env ]] || { echo "Створи .env з .env.example"; exit 1; }
set -a; source .env; set +a

node -e 'const [a,b]=process.versions.node.split(".").map(Number); if(!((a===24&&b>=16)||a>=26)){console.error("Потрібен Node >=24.16 (зараз "+process.version+")");process.exit(1)}'
command -v docker >/dev/null || { echo "Немає docker (Rancher Desktop: увімкни dockerd/moby)"; exit 1; }
command -v openclaw >/dev/null || npm i -g openclaw@2026.9.8

for var in AGENT_TEAM_DIR LEAD_MODEL BA_MODEL ARCHITECT_MODEL DEV_MODEL QA_MODEL \
  GH_TOKEN_LEAD GH_TOKEN_BA GH_TOKEN_ARCHITECT GH_TOKEN_DEV GH_TOKEN_QA \
  SLACK_APP_TOKEN SLACK_BOT_TOKEN SLACK_OWNER_ID; do
  [[ -n "${!var:-}" ]] || { echo "У .env порожня змінна $var (див. .env.example)"; exit 1; }
done

for var in LEAD_FALLBACK_MODEL BA_FALLBACK_MODEL ARCHITECT_FALLBACK_MODEL DEV_FALLBACK_MODEL QA_FALLBACK_MODEL; do
  [[ -n "${!var:-}" ]] || echo "Увага: порожня $var — на rate limit хід агента обірветься без запасної моделі"
done

echo "== Будую пісочницю"
docker build -t agent-team/dotnet-sandbox:10 sandbox/

echo "== Мережа і Postgres для пісочниці"
docker network inspect agent-team >/dev/null 2>&1 || docker network create agent-team
if ! docker container inspect agent-team-postgres >/dev/null 2>&1; then
  docker run -d --name agent-team-postgres --network agent-team --restart unless-stopped \
    -e POSTGRES_PASSWORD="${AGENT_PG_PASSWORD:-postgres}" postgres:17-alpine
fi

echo "== Мітки в dopamine-shop"
./scripts/labels.sh

echo "== Скіли у воркспейси агентів"
./scripts/sync-skills.sh

echo "== Плагін Slack"
# plugins install теж переписує конфіг, тому ставимо на тимчасову копію; plugins.entries.slack уже в openclaw.json5.
if ! OPENCLAW_CONFIG_PATH="$PWD/openclaw.json5" openclaw plugins list --json 2>/dev/null | grep -q '"id": *"slack"'; then
  tmpdir="$(mktemp -d)"
  cp openclaw.json5 "$tmpdir/openclaw.json5"
  OPENCLAW_CONFIG_PATH="$tmpdir/openclaw.json5" openclaw plugins install @openclaw/slack@2026.9.8
  rm -rf "$tmpdir"
fi

echo "== Ключі моделей в auth-профілі агентів"
# OpenClaw бере ключ для агентів не зі змінної оточення, а з auth-профілю кожного агента.
# paste-api-key переписує конфіг, тому даємо йому тимчасову копію, щоб не чіпати openclaw.json5.
[[ -n "${OPENAI_API_KEY:-}${ANTHROPIC_API_KEY:-}" ]] || { echo "У .env немає ні OPENAI_API_KEY, ні ANTHROPIC_API_KEY"; exit 1; }
tmpdir="$(mktemp -d)"
cp openclaw.json5 "$tmpdir/openclaw.json5"
for agent in lead ba architect dev qa; do
  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    printf "%s\n" "$OPENAI_API_KEY" | OPENCLAW_CONFIG_PATH="$tmpdir/openclaw.json5" openclaw models auth paste-api-key --provider openai --agent "$agent"
  fi
  if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    printf "%s\n" "$ANTHROPIC_API_KEY" | OPENCLAW_CONFIG_PATH="$tmpdir/openclaw.json5" openclaw models auth paste-api-key --provider anthropic --agent "$agent"
  fi
done
rm -f "$tmpdir"/openclaw.json5*
rmdir "$tmpdir"

echo "== Перевіряю конфіг"
export OPENCLAW_CONFIG_PATH="$PWD/openclaw.json5"
openclaw config validate

cat <<MSG

Готово. Додай у ~/.zshrc (або запускай перед openclaw):
  set -a; source $PWD/.env; set +a
  export OPENCLAW_CONFIG_PATH="$PWD/openclaw.json5"

Далі: openclaw gateway --verbose, а в іншому терміналі
  openclaw agent --agent lead --message "перевір чергу"
(або напиши боту в Slack в особисті).
MSG
