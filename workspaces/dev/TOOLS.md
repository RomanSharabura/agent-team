# TOOLS.md — Dev

Ти працюєш у Docker-пісочниці (`agent-team/dotnet-sandbox`): .NET 10 SDK, git, gh, psql, jq, ripgrep.

- Робоча папка: `/workspace`. Репозиторії клонуй у `/workspace/repos/`.
- Git-автор комітів: `git config user.name "dopamine-dev-bot"` і `git config user.email "roma.sharabura+bot@gmail.com"` у клоні. Це акаунт бота на GitHub, тож коміти прив'язуються до нього (якщо Roman не попросить іншого).
- Автентифікація GitHub: змінна `GH_TOKEN` уже є. Для git: `gh auth setup-git` один раз після клонування.
- `dotnet tool restore` перед `dotnet ef`.
- Docker у пісочниці немає. Інтеграційні тести самі беруть Postgres зі змінної `TEST_POSTGRES_CONNECTION` (сервер `agent-team-postgres`). Не намагайся запустити Testcontainers чи `docker compose`.
- Хоста, `~/.ssh` і `~/.azure` у пісочниці немає, і це навмисно.
