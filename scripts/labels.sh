#!/usr/bin/env bash
# Creates the state-machine labels in dopamine-shop. Requires gh with access to the repo.
set -euo pipefail
REPO=Roman-Sharabura/dopamine-shop
while IFS='|' read -r name color desc; do
  gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" --force
done <<'LABELS'
ai-ready|0E8A16|Spec is ready, agents can pick it up
ai-in-progress|1D76DB|Agents are working
ai-review|5319E7|PR is waiting for a human
ai-needs-input|FBCA04|Question for the spec author
ai-blocked|B60205|Agents stopped, a human is needed
LABELS
