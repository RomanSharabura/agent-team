# TOOLS.md — BA

Ти працюєш у Docker-пісочниці (`agent-team/dotnet-sandbox`): git, gh, jq, ripgrep.

- Файли репо читай через `gh api ... -H "Accept: application/vnd.github.raw"` (скіл `spec-validate`), клон не потрібен.
- Автентифікація GitHub: змінна `GH_TOKEN` уже є.
- Запис у файли тобі вимкнено, і це навмисно.
