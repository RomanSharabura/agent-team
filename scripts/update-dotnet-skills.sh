#!/usr/bin/env bash
# Updates the .NET skills from Microsoft (github.com/dotnet/skills, MIT) in vendor/dotnet-skills/.
# Takes only the skills useful to dopamine-shop (ASP.NET Core Minimal API, EF Core, xUnit).
# Usage: ./scripts/update-dotnet-skills.sh [commit|branch]   (default: main)
# After updating: review the diff, commit, and run ./scripts/sync-skills.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

REF="${1:-main}"
# <plugin>/<skill> in the dotnet/skills repo
SKILLS=(
  dotnet/csharp-refactoring
  dotnet-aspnetcore/dotnet-webapi
  dotnet-data/optimizing-ef-core-queries
  dotnet-test/run-tests
  dotnet-test/platform-detection
  dotnet-test/filter-syntax
  dotnet-test/test-anti-patterns
  dotnet-test/assertion-quality
  dotnet-test/test-analysis-extensions
  dotnet-test/test-gap-analysis
)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git clone -q --filter=blob:none https://github.com/dotnet/skills "$tmp/src"
git -C "$tmp/src" checkout -q "$REF"
commit="$(git -C "$tmp/src" rev-parse HEAD)"

dest=vendor/dotnet-skills
find "$dest" -mindepth 1 -maxdepth 1 -type d -exec rm -r {} + 2>/dev/null || true
mkdir -p "$dest"
for entry in "${SKILLS[@]}"; do
  cp -r "$tmp/src/plugins/${entry%%/*}/skills/${entry##*/}" "$dest/${entry##*/}"
done
cp "$tmp/src/LICENSE" "$dest/LICENSE"

{
  echo "# .NET skills from Microsoft"
  echo
  echo "Unmodified copy of skills from https://github.com/dotnet/skills (MIT, see LICENSE)."
  echo "Update: \`./scripts/update-dotnet-skills.sh [commit]\`, then \`./scripts/sync-skills.sh\`."
  echo
  echo "Commit: \`$commit\`"
  echo
  echo "| Skill | Plugin |"
  echo "|---|---|"
  for entry in "${SKILLS[@]}"; do echo "| \`${entry##*/}\` | \`${entry%%/*}\` |"; done
} > "$dest/SOURCE.md"

echo "dotnet/skills@$commit → $dest (${#SKILLS[@]} skills)"
