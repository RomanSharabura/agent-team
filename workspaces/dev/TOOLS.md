# TOOLS.md — Dev

You work in a Docker sandbox (`agent-team/dotnet-sandbox`): .NET 10 SDK, git, gh, psql, jq, ripgrep.

- Working folder: `/workspace`. Clone repositories into `/workspace/repos/`.
- The commit author is already set by the `GIT_AUTHOR_*` and `GIT_COMMITTER_*` variables (bot `dopamine-dev-bot`, `(dev)` in the author name); do not touch `git config user.*`. The `Agent:` trailer marks the agent in a commit (skill `git-commit`), and the `**[dev]**` prefix marks it in comments (skill `github-issue`).
- GitHub authentication: the `GH_TOKEN` variable is already set. For git: `gh auth setup-git` once after cloning.
- `dotnet tool restore` before `dotnet ef`.
- There is no Docker in the sandbox. Integration tests take Postgres from the `TEST_POSTGRES_CONNECTION` variable (server `agent-team-postgres`). Do not try to run Testcontainers or `docker compose`.
- The host, `~/.ssh` and `~/.azure` are not available in the sandbox, and this is intentional.
