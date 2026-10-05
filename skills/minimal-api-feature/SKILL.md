---
name: minimal-api-feature
description: Add a feature to dopamine-shop (ASP.NET Core Minimal API, Clean Architecture, MediatR) by copying the reference feature.
metadata: { "openclaw": { "requires": { "bins": ["dotnet", "git"] } } }
---
# Minimal API feature

Зразок: `GetUserById` (SPEC-000). Копіюй його форму, не вигадуй свою.

1. Application: `src/DopamineShop.Application/Features/<Area>/<Feature>/`
   - `<Feature>Query.cs` або `<Feature>Command.cs`: `public sealed record ... : IRequest<T>`.
   - `<Feature>Handler.cs`: `internal sealed class`, primary constructor з `IAppDbContext`; `AsNoTracking()` для читання; `CancellationToken` у кожен async-виклик.
   - `<Feature>Validator.cs`: `internal sealed class : AbstractValidator<T>`. Реєструється автоматично.
   - Спільні DTO кладуться в `Features/<Area>/`.
2. Api: метод у `src/DopamineShop.Api/Endpoints/<Area>Endpoints.cs` у наявній групі `MapGroup`.
   Повертай `Results<...>` через `TypedResults`, приймай `CancellationToken`, передавай його в `sender.Send`.
   Query-параметри — через `[AsParameters]` record або окремі параметри з nullable-типами; значення за замовчуванням — як в openapi.yaml.
3. Валідація: правила лише у валідаторі. Повідомлення з переліком допустимих значень пиши так, щоб воно містило їх через кому (`active, blocked`).
4. Infrastructure: лише якщо потрібна нова таблиця або конфіг EF. Тоді `dotnet ef migrations add <Name> -p src/DopamineShop.Infrastructure -s src/DopamineShop.Api -o Persistence/Migrations`.
5. Логування: Serilog через `ILogger<T>`, структуровані властивості, без string interpolation.
6. Не додавай NuGet-пакети і не змінюй `Program.cs` без явного пункту в плані.
7. Запусти `dotnet-quality-gate`. Червоне → виправ, не пропускай.

## Відомі пастки
- SQLite не сортує `DateTimeOffset`: `CreatedAt` уже зберігається як ticks, тож `OrderByDescending(u => u.CreatedAt)` працює. Не змінюй конвертер.
- `LIKE` у SQLite нечутливий до регістру лише для ASCII. Email нормалізується в lowercase при створенні, тому шукай по `search.ToLowerInvariant()`.
- Тест-класи з різною кількістю даних мають різні `ApiFactory` (кожен клас — свій `IClassFixture`).
