#!/usr/bin/env bash
# Копіює спільні скіли з skills/ у workspaces/<agent>/skills/.
# Пісочниця бачить лише воркспейс агента (/workspace/skills), а не skills/ у корені репо.
# Запускай після кожного git pull, що змінює skills/ (setup.sh робить це сам).
set -euo pipefail
cd "$(dirname "$0")/.."

declare -A AGENT_SKILLS=(
  [lead]="github-issue handoff pr-review"
  [dev]="github-issue handoff repo-conventions minimal-api-feature dotnet-quality-gate git-commit"
  [qa]="github-issue handoff repo-conventions spec-to-tests dotnet-quality-gate git-commit"
)

for agent in "${!AGENT_SKILLS[@]}"; do
  dest="workspaces/$agent/skills"
  mkdir -p "$dest"
  find "$dest" -mindepth 1 -maxdepth 1 -type d -exec rm -r {} +
  for skill in ${AGENT_SKILLS[$agent]}; do
    cp -r "skills/$skill" "$dest/$skill"
  done
  echo "$agent: ${AGENT_SKILLS[$agent]}"
done
