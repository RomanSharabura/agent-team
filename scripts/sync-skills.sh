#!/usr/bin/env bash
# Копіює спільні скіли з skills/ і скіли .NET від Microsoft з vendor/dotnet-skills/
# у workspaces/<agent>/skills/.
# Пісочниця бачить лише воркспейс агента (/workspace/skills), а не skills/ у корені репо.
# Запускай після кожного git pull, що змінює skills/ (setup.sh робить це сам).
set -euo pipefail
cd "$(dirname "$0")/.."

declare -A AGENT_SKILLS=(
  [lead]="github-issue handoff pr-review"
  [ba]="github-issue handoff spec-validate"
  [architect]="github-issue handoff repo-conventions spec-to-plan adr-writer git-commit"
  [dev]="github-issue handoff repo-conventions minimal-api-feature dotnet-quality-gate git-commit"
  [qa]="github-issue handoff repo-conventions spec-to-tests dotnet-quality-gate git-commit"
)

# Скіли з github.com/dotnet/skills (scripts/update-dotnet-skills.sh). Наші скіли й
# docs/conventions.md dopamine-shop мають пріоритет, див. workspaces/<agent>/AGENTS.md.
declare -A DOTNET_SKILLS=(
  [lead]=""
  [ba]=""
  [architect]=""
  [dev]="dotnet-webapi optimizing-ef-core-queries csharp-refactoring run-tests platform-detection filter-syntax"
  [qa]="run-tests platform-detection filter-syntax test-anti-patterns assertion-quality test-analysis-extensions test-gap-analysis"
)

for agent in "${!AGENT_SKILLS[@]}"; do
  dest="workspaces/$agent/skills"
  mkdir -p "$dest"
  find "$dest" -mindepth 1 -maxdepth 1 -type d -exec rm -r {} +
  for skill in ${AGENT_SKILLS[$agent]}; do
    cp -r "skills/$skill" "$dest/$skill"
  done
  for skill in ${DOTNET_SKILLS[$agent]}; do
    cp -r "vendor/dotnet-skills/$skill" "$dest/$skill"
  done
  echo "$agent: ${AGENT_SKILLS[$agent]} ${DOTNET_SKILLS[$agent]}"
done
