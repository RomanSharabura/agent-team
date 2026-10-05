# TOOLS.md — Dev

Ти працюєш у Docker-пісочниці (`agent-team/dotnet-sandbox`): .NET 10 SDK, git, gh, jq, ripgrep.

- Робоча папка: `/workspace`. Репозиторії клонуй у `/workspace/repos/`.
- Git-автор комітів: `git config user.name "dopamine-dev-bot"` і `user.email "dev-bot@users.noreply.github.com"` у клоні (якщо Roman не попросить іншого).
- Автентифікація GitHub: змінна `GH_TOKEN` уже є. Для git: `gh auth setup-git` один раз після клонування.
- `dotnet tool restore` перед `dotnet ef`.
- Хоста, `~/.ssh` і `~/.azure` у пісочниці немає, і це навмисно.
