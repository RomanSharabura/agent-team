# TOOLS.md — QA

You work in a Docker sandbox (`agent-team/dotnet-sandbox`): .NET 11 SDK (preview; .NET 10 SDK also installed), git, gh, psql, jq, ripgrep.

- Working folder: `/workspace`. Clone repositories into `/workspace/repos/`.
- The commit author is already set by the `GIT_AUTHOR_*` and `GIT_COMMITTER_*` variables (bot `dopamine-dev-bot`, `(qa)` in the author name); do not touch `git config user.*`. The `Agent:` trailer marks the agent in a commit (skill `git-commit`), and the `**[qa]**` prefix marks it in comments (skill `github-issue`).
- GitHub authentication: the `GH_TOKEN` variable is already set. For git: `gh auth setup-git` once after cloning.
- There is no Docker in the sandbox. Integration tests take Postgres from the `TEST_POSTGRES_CONNECTION` variable (server `agent-team-postgres`). Do not try to run Testcontainers or `docker compose`.
- A single test: `dotnet test --no-build --filter "FullyQualifiedName~REQ_003"`; all tests of a requirement: `--filter "Req=REQ-003"`.
- The host, `~/.ssh` and `~/.azure` are not available in the sandbox, and this is intentional.
