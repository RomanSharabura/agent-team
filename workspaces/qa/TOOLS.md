# TOOLS.md — QA

Ти працюєш у Docker-пісочниці (`agent-team/dotnet-sandbox`): .NET 10 SDK, git, gh, psql, jq, ripgrep.

- Робоча папка: `/workspace`. Репозиторії клонуй у `/workspace/repos/`.
- Git-автор комітів уже заданий змінними `GIT_AUTHOR_*` і `GIT_COMMITTER_*` (бот `dopamine-dev-bot`, в імені автора `(qa)`); `git config user.*` не чіпай. Агента в коміті позначає трейлер `Agent:` (скіл `git-commit`), у коментарях — префікс `**[qa]**` (скіл `github-issue`).
- Автентифікація GitHub: змінна `GH_TOKEN` уже є. Для git: `gh auth setup-git` один раз після клонування.
- Docker у пісочниці немає. Інтеграційні тести самі беруть Postgres зі змінної `TEST_POSTGRES_CONNECTION` (сервер `agent-team-postgres`). Не намагайся запустити Testcontainers чи `docker compose`.
- Окремий тест: `dotnet test --no-build --filter "FullyQualifiedName~REQ_003"`; усі тести вимоги: `--filter "Req=REQ-003"`.
- Хоста, `~/.ssh` і `~/.azure` у пісочниці немає, і це навмисно.
