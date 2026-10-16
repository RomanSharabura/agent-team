#!/usr/bin/env bash
# Switch the team (or some agents) to a model preset from models/<preset>.env.
#   ./scripts/use-models.sh anthropic                 all five agents, Anthropic API key
#   ./scripts/use-models.sh claude-subscription       all five agents, Claude subscription (setup token)
#   ./scripts/use-models.sh openai dev qa             only dev and qa
# Rewrites the *_MODEL, *_FALLBACK_MODEL and *_AUTH lines in .env and puts the provider's credential from .env into
# the agents' auth profiles: the API key (AUTH=api-key, the default) or the Claude setup token (AUTH=subscription).
# Both credentials stay saved side by side; the agent's auth order picks one, so switching back and forth never asks
# to sign in again. Then restart the gateway after `source .env` (models are read at gateway start).
# A preset is just a file: copy one to models/<name>.env to keep your own mix.
set -euo pipefail

cd "$(dirname "$0")/.."
[[ -f .env ]] || { echo "Create .env from .env.example"; exit 1; }
preset="${1:-}"
if [[ -z "$preset" || ! -f "models/$preset.env" ]]; then
  echo "Usage: $0 <preset> [agent...]  presets: $(cd models && ls ./*.env | sed 's|^\./||; s|\.env$||' | tr '\n' ' ')"
  exit 1
fi
shift
agents=("$@")
[[ ${#agents[@]} -gt 0 ]] || agents=(lead ba architect dev qa)

set -a; source .env; set +a

auth="$(grep '^AUTH=' "models/$preset.env" | cut -d= -f2- || true)"
auth="${auth:-api-key}"
[[ "$auth" == api-key || "$auth" == subscription ]] || { echo "models/$preset.env: AUTH must be api-key or subscription"; exit 1; }

# Collect the new values and the providers they need before touching .env.
declare -A values=()
declare -A providers=()
for agent in "${agents[@]}"; do
  for var in "${agent^^}_MODEL" "${agent^^}_FALLBACK_MODEL"; do
    value="$(grep "^$var=" "models/$preset.env" | cut -d= -f2- || true)"
    [[ -n "$value" ]] || { echo "models/$preset.env has no $var (agents: lead ba architect dev qa)"; exit 1; }
    values[$var]="$value"
    providers[${value%%/*}]=1
  done
  values[${agent^^}_AUTH]="$auth"
done
for provider in "${!providers[@]}"; do
  if [[ "$auth" == subscription ]]; then
    # Only Anthropic: `claude setup-token` makes a long-lived token for the Claude Pro/Max/Team plan.
    [[ "$provider" == anthropic ]] || { echo "AUTH=subscription works only with anthropic/* models, not $provider"; exit 1; }
    [[ "${ANTHROPIC_SETUP_TOKEN:-}" == sk-ant-oat01-* ]] || {
      echo "ANTHROPIC_SETUP_TOKEN in .env is empty or not a setup token: run \`claude setup-token\` and paste the sk-ant-oat01-... line"
      exit 1
    }
  else
    key_var="${provider^^}_API_KEY"
    [[ -n "${!key_var:-}" ]] || { echo "$key_var is empty in .env: fill it in first"; exit 1; }
  fi
done

# The two Anthropic credentials live in separate auth profiles of each agent: anthropic:manual (API key, the id
# paste-api-key and setup.sh use) and anthropic:subscription (setup token). The per-agent auth order lists only the
# chosen one, so a subscription agent never falls back to the paid API key when the plan's limit runs out.
# paste-api-key and paste-token rewrite the config, so give them a temporary copy to leave openclaw.json5 untouched.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
cp openclaw.json5 "$tmpdir/openclaw.json5"
oc() {
  # Quiet on success: it warns that the gateway must restart, which the message below already says.
  local out
  out="$(OPENCLAW_CONFIG_PATH="$tmpdir/openclaw.json5" openclaw "$@" 2>&1)" || { echo "$out"; exit 1; }
}
for agent in "${agents[@]}"; do
  for provider in "${!providers[@]}"; do
    if [[ "$auth" == subscription ]]; then
      profile="$provider:subscription"
      # A setup token is valid for one year; the expiry lets `openclaw models status` warn before it lapses.
      printf "%s\n" "$ANTHROPIC_SETUP_TOKEN" | oc models auth paste-token --provider "$provider" --agent "$agent" \
        --profile-id "$profile" --expires-in 365d
    else
      profile="$provider:manual"
      key_var="${provider^^}_API_KEY"
      printf "%s\n" "${!key_var}" | oc models auth paste-api-key --provider "$provider" --agent "$agent" --profile-id "$profile"
    fi
    oc models auth order set --provider "$provider" --agent "$agent" "$profile"
  done
done

for var in "${!values[@]}"; do
  if grep -q "^$var=" .env; then
    sed -i "s|^$var=.*|$var=${values[$var]}|" .env
  else
    printf '%s=%s\n' "$var" "${values[$var]}" >> .env
  fi
done

echo "== ${agents[*]} → $preset:"
for var in $(printf '%s\n' "${!values[@]}" | sort); do echo "  $var=${values[$var]}"; done
cat <<'MSG'
Now restart the gateway in its terminal (Ctrl+C), then:
  set -a; source .env; set +a; openclaw gateway --verbose
No sandbox recreate needed. Check: openclaw models auth order get --provider <provider> --agent <id>
MSG
if [[ "$auth" == subscription ]]; then
  echo "Budget guard: dollar limits do not apply to subscription agents; their token limits in budget.json do (README \"Three ways to pay\")."
fi
