#!/usr/bin/env bash
# One-time setup on Roman's machine. Run from the repo root: ./scripts/setup.sh
set -euo pipefail

cd "$(dirname "$0")/.."
[[ -f .env ]] || { echo "Create .env from .env.example"; exit 1; }
set -a; source .env; set +a

if [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  OPENCLAW_GATEWAY_TOKEN="$(node -e 'console.log(require("crypto").randomBytes(24).toString("hex"))')"
  if grep -q '^OPENCLAW_GATEWAY_TOKEN=' .env; then
    sed -i "s/^OPENCLAW_GATEWAY_TOKEN=.*/OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN/" .env
  else
    printf '\nOPENCLAW_GATEWAY_TOKEN=%s\n' "$OPENCLAW_GATEWAY_TOKEN" >> .env
  fi
  export OPENCLAW_GATEWAY_TOKEN
  echo "== Generated OPENCLAW_GATEWAY_TOKEN in .env"
fi

node -e 'const [a,b]=process.versions.node.split(".").map(Number); if(!((a===24&&b>=16)||a>=26)){console.error("Node >=24.16 required (current: "+process.version+")");process.exit(1)}'
command -v docker >/dev/null || { echo "docker not found (Rancher Desktop: enable dockerd/moby)"; exit 1; }
# 2026.9.9 is the first release that knows Claude Haiku 5.5 (lead and ba). An older install is upgraded in place;
# restart the gateway afterwards so it runs the new version.
OPENCLAW_VERSION=2026.9.9
if [[ "$(openclaw --version 2>/dev/null)" != *"$OPENCLAW_VERSION"* ]]; then
  echo "== Installing OpenClaw $OPENCLAW_VERSION"
  npm i -g "openclaw@$OPENCLAW_VERSION"
fi
# OpenClaw checks a skill's requires.bins on the host, not in the sandbox: without jq on the host
# lead silently loses pr-review, pipeline-resume and morning-briefing.
for bin in gh jq; do
  command -v "$bin" >/dev/null || { echo "$bin not found on the host: sudo apt install $bin (skills that require it are hidden from agents)"; exit 1; }
done

for var in AGENT_TEAM_DIR LEAD_MODEL BA_MODEL ARCHITECT_MODEL DEV_MODEL QA_MODEL \
  GH_TOKEN_LEAD GH_TOKEN_BA GH_TOKEN_ARCHITECT GH_TOKEN_DEV GH_TOKEN_QA \
  SLACK_APP_TOKEN SLACK_BOT_TOKEN SLACK_OWNER_ID; do
  [[ -n "${!var:-}" ]] || { echo "Variable $var is empty in .env (see .env.example)"; exit 1; }
done
# Agents see workspaces/ from AGENT_TEAM_DIR, while the scripts write here. Different folders = agents work from a stale copy.
[[ "$(realpath "${AGENT_TEAM_DIR:-.}")" == "$(realpath .)" ]] || {
  echo "AGENT_TEAM_DIR in .env ($AGENT_TEAM_DIR) is not this repo ($PWD). Set AGENT_TEAM_DIR=$PWD, restart the gateway, recreate the sandboxes."
  exit 1
}

for var in LEAD_FALLBACK_MODEL BA_FALLBACK_MODEL ARCHITECT_FALLBACK_MODEL DEV_FALLBACK_MODEL QA_FALLBACK_MODEL; do
  [[ -n "${!var:-}" ]] || echo "Warning: $var is empty; on a rate limit the agent's turn will abort without a fallback model"
done

echo "== Building the sandbox"
docker build -t agent-team/dotnet-sandbox:11 sandbox/

echo "== Network and Postgres for the sandbox"
docker network inspect agent-team >/dev/null 2>&1 || docker network create agent-team
if ! docker container inspect agent-team-postgres >/dev/null 2>&1; then
  docker run -d --name agent-team-postgres --network agent-team --restart unless-stopped \
    -e POSTGRES_PASSWORD="${AGENT_PG_PASSWORD:-postgres}" postgres:17-alpine
fi

echo "== Labels in dopamine-shop"
./scripts/labels.sh

echo "== Skills into agent workspaces"
./scripts/sync-skills.sh

echo "== Slack plugin"
# plugins install/update also rewrite the config, so install against a temporary copy; plugins.entries.slack is already in openclaw.json5.
slack_version="$(OPENCLAW_CONFIG_PATH="$PWD/openclaw.json5" openclaw plugins list --json 2>/dev/null \
  | jq -r '(if type == "array" then . else .plugins end) | map(select(.id == "slack")) | .[0].version // empty' || true)"
if [[ "$slack_version" != "$OPENCLAW_VERSION" ]]; then
  tmpdir="$(mktemp -d)"
  cp openclaw.json5 "$tmpdir/openclaw.json5"
  if [[ -z "$slack_version" ]]; then
    OPENCLAW_CONFIG_PATH="$tmpdir/openclaw.json5" openclaw plugins install "@openclaw/slack@$OPENCLAW_VERSION"
  else
    OPENCLAW_CONFIG_PATH="$tmpdir/openclaw.json5" openclaw plugins update "@openclaw/slack@$OPENCLAW_VERSION"
  fi
  rm -rf "$tmpdir"
fi

echo "== Model keys into agent auth profiles"
# OpenClaw takes the agents' key not from an environment variable but from each agent's auth profile.
# paste-api-key rewrites the config, so give it a temporary copy to leave openclaw.json5 untouched.
[[ -n "${OPENAI_API_KEY:-}${ANTHROPIC_API_KEY:-}" ]] || { echo "Neither OPENAI_API_KEY nor ANTHROPIC_API_KEY is set in .env"; exit 1; }
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

echo "== Validating config"
export OPENCLAW_CONFIG_PATH="$PWD/openclaw.json5"
openclaw config validate

cat <<MSG

Done. Add to ~/.zshrc (or run before openclaw):
  set -a; source $PWD/.env; set +a
  export OPENCLAW_CONFIG_PATH="$PWD/openclaw.json5"

Next: openclaw gateway --verbose, and in another terminal
  openclaw agent --agent lead --message "check the queue"
(or DM the bot in Slack).
MSG
