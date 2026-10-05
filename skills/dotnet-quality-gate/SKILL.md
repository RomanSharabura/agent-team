---
name: dotnet-quality-gate
description: Run build (warnings as errors), format check and all tests for dopamine-shop; must be green before any push.
metadata: { "openclaw": { "requires": { "bins": ["dotnet"] } } }
---
# .NET quality gate

З кореня репозиторію, по черзі, кожна команда має завершитись з кодом 0:

```bash
dotnet restore
dotnet build --no-restore
dotnet format --verify-no-changes --no-restore || { dotnet format --no-restore; echo "format applied, re-run gate"; exit 1; }
dotnet test --no-build
```

- Warnings — це помилки (`TreatWarningsAsErrors`). Виправляй причину; `#pragma warning disable` лише з коментарем-причиною і згадкою в PR.
- Інтеграційні тести працюють на справжньому PostgreSQL. У пісочниці сервер задано змінною `TEST_POSTGRES_CONNECTION`; якщо вона порожня і Docker недоступний, інтеграційні тести впадуть — це проблема оточення: поверни `BLOCKED` з текстом помилки, не вимикай тести.
- Архітектурні тести (`tests/DopamineShop.ArchitectureTests`) входять у `dotnet test`. Червоний архітектурний тест означає, що код порушує правило з `docs/conventions.md`: змінюй код.
- Тести не пропускаються (`Skip`), не видаляються і не послаблюються, щоб стати зеленими.
- Вивід команд скорочуй: показуй лише рядки з `error`, `Failed` і підсумок.

Результат у конверт: `gate: green` або `gate: red` з першими 20 рядками помилок.
