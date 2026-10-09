#!/usr/bin/env bash
# Copies shared skills from skills/ and the .NET skills from Microsoft from vendor/dotnet-skills/
# into workspaces/<agent>/skills/, and creates workspaces/<agent>/MEMORY.md from templates/memory/ if missing.
# The sandbox only sees the agent's workspace (/workspace/skills), not skills/ at the repo root.
# Run after every git pull that changes skills/ (setup.sh does this itself).
set -euo pipefail
cd "$(dirname "$0")/.."

declare -A AGENT_SKILLS=(
  [lead]="github-issue handoff pr-review pipeline-resume morning-briefing"
  [ba]="github-issue handoff spec-validate"
  [architect]="github-issue handoff repo-conventions spec-to-plan adr-writer git-commit admin-ui-feature workspace-lock"
  [dev]="github-issue handoff repo-conventions minimal-api-feature dotnet-quality-gate git-commit admin-ui-feature admin-ui-gate workspace-lock"
  [qa]="github-issue handoff repo-conventions spec-to-tests dotnet-quality-gate git-commit admin-ui-feature admin-ui-gate workspace-lock"
)

# Skills from github.com/dotnet/skills (scripts/update-dotnet-skills.sh). Our skills and
# dopamine-shop docs/conventions.md take precedence, see workspaces/<agent>/AGENTS.md.
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
  # MEMORY.md belongs to the agent once created: copy the template only if it is missing.
  [[ -f "workspaces/$agent/MEMORY.md" ]] || cp "templates/memory/$agent.md" "workspaces/$agent/MEMORY.md"
done
