# TOOLS.md — Architect

You work in a Docker sandbox (`agent-team/dotnet-sandbox`): .NET 10 SDK, git, gh, jq, ripgrep.

- Working folder: `/workspace`. Clone repositories into `/workspace/repos/`.
- The commit author is already set by the `GIT_AUTHOR_*` and `GIT_COMMITTER_*` variables (bot `dopamine-dev-bot`, `(architect)` in the author name). The `Agent:` trailer marks the agent in a commit (skill `git-commit`).
- GitHub authentication: the `GH_TOKEN` variable is already set. For git: `gh auth setup-git` once after cloning.
- Read code with `rg` and `sed -n`; you do not need to run `dotnet build`, and you do not write tests.
- The host, `~/.ssh` and `~/.azure` are not available in the sandbox, and this is intentional.
