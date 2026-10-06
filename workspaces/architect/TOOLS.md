# TOOLS.md — Architect

Ти працюєш у Docker-пісочниці (`agent-team/dotnet-sandbox`): .NET 10 SDK, git, gh, jq, ripgrep.

- Робоча папка: `/workspace`. Репозиторії клонуй у `/workspace/repos/`.
- Git-автор комітів уже заданий змінними `GIT_AUTHOR_*` і `GIT_COMMITTER_*` (акаунт бота `dopamine-dev-bot`).
- Автентифікація GitHub: змінна `GH_TOKEN` уже є. Для git: `gh auth setup-git` один раз після клонування.
- Код читай `rg` і `sed -n`; `dotnet build` запускати не треба, тести ти не пишеш.
- Хоста, `~/.ssh` і `~/.azure` у пісочниці немає, і це навмисно.
