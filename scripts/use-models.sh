#!/usr/bin/env bash
# Switch the team (or some agents) to a model preset from models/<preset>.env.
#   ./scripts/use-models.sh anthropic          all five agents
#   ./scripts/use-models.sh openai dev qa      only dev and qa
# Rewrites the *_MODEL and *_FALLBACK_MODEL lines in .env and puts the provider's key from .env into the
# agents' auth profiles. Then restart the gateway after `source .env` (models are read at gateway start).
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
done
for provider in "${!providers[@]}"; do
  key_var="${provider^^}_API_KEY"
  [[ -n "${!key_var:-}" ]] || { echo "$key_var is empty in .env: fill it in first"; exit 1; }
done

# paste-api-key rewrites the config, so give it a temporary copy to leave openclaw.json5 untouched.
tmpdir="$(mktemp -d)"
cp openclaw.json5 "$tmpdir/openclaw.json5"
for agent in "${agents[@]}"; do
  for provider in "${!providers[@]}"; do
    key_var="${provider^^}_API_KEY"
    # Quiet on success: it warns that the gateway must restart, which the message below already says.
    out="$(printf "%s\n" "${!key_var}" | OPENCLAW_CONFIG_PATH="$tmpdir/openclaw.json5" \
      openclaw models auth paste-api-key --provider "$provider" --agent "$agent" 2>&1)" || { echo "$out"; rm -rf "$tmpdir"; exit 1; }
  done
done
rm -rf "$tmpdir"

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
No sandbox recreate needed. Check: openclaw models status --agent <id>
MSG
