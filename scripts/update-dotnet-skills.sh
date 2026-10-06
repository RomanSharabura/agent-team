#!/usr/bin/env bash
# Оновлює скіли .NET від Microsoft (github.com/dotnet/skills, MIT) у vendor/dotnet-skills/.
# Беремо лише скіли, корисні dopamine-shop (ASP.NET Core Minimal API, EF Core, xUnit).
# Використання: ./scripts/update-dotnet-skills.sh [commit|branch]   (типово main)
# Після оновлення: переглянь diff, закоміть і запусти ./scripts/sync-skills.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

REF="${1:-main}"
# <плагін>/<скіл> у репо dotnet/skills
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
  echo "# Скіли .NET від Microsoft"
  echo
  echo "Копія скілів з https://github.com/dotnet/skills (MIT, див. LICENSE), без змін."
  echo "Оновлення: \`./scripts/update-dotnet-skills.sh [commit]\`, потім \`./scripts/sync-skills.sh\`."
  echo
  echo "Коміт: \`$commit\`"
  echo
  echo "| Скіл | Плагін |"
  echo "|---|---|"
  for entry in "${SKILLS[@]}"; do echo "| \`${entry##*/}\` | \`${entry%%/*}\` |"; done
} > "$dest/SOURCE.md"

echo "dotnet/skills@$commit → $dest (${#SKILLS[@]} скілів)"
