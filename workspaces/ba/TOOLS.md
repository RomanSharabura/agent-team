# TOOLS.md — BA

You work in a Docker sandbox (`agent-team/dotnet-sandbox`): git, gh, jq, ripgrep.

- Read repo files via `gh api ... -H "Accept: application/vnd.github.raw"` (skill `spec-validate`); no clone needed.
- GitHub authentication: the `GH_TOKEN` variable is already set.
- Writing files is disabled for you, and this is intentional.
