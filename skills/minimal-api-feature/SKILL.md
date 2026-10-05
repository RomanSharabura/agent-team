---
name: minimal-api-feature
description: Add a vertical slice to a dopamine-shop module (modular monolith, Clean Architecture, own IQuery/ICommand handlers, DDD).
metadata: { "openclaw": { "requires": { "bins": ["dotnet", "git"] } } }
---
# Minimal API feature (vertical slice)

Зразок: `GetUserById` у модулі Users (SPEC-000). Копіюй його форму, не вигадуй свою.
Правила перевіряють архітектурні тести. Червоний архітектурний тест = змінюй код, а не тест.

Нехай `M` — модуль (наприклад `Users`), `F` — фіча (наприклад `ListUsers`).

1. **Domain** (`src/Modules/M/DopamineShop.Modules.M.Domain`): лише якщо фіча змінює поведінку.
   Нова поведінка — метод агрегату, що перевіряє інваріанти й кидає `DomainException`. Публічних сеттерів не додавай.
2. **Application** (`.../DopamineShop.Modules.M.Application/Features/F/`):
   - `FQuery.cs` або `FCommand.cs`: `public sealed record ... : IQuery<T>` / `ICommand<T>` / `ICommand`.
   - `FHandler.cs`: `internal sealed class FHandler(IMDbContext db) : IQueryHandler<FQuery, T>`; `AsNoTracking()` для читання; `CancellationToken` у кожен async-виклик.
   - `FValidator.cs`: `internal sealed class : AbstractValidator<FQuery>`.
   - DTO, потрібні кільком слайсам, — у `Common/`. Типи інших слайсів не використовуй.
3. **Presentation** (`.../DopamineShop.Modules.M.Presentation/Features/F/FEndpoint.cs`):
   `internal sealed class FEndpoint : IEndpoint`; у `MapEndpoint` — `app.MapGet(...)` з `.WithName("F").WithTags(Tags.<...>)`.
   Handler інжектиться параметром: `IQueryHandler<FQuery, T> handler`. Повертай `Results<...>` через `TypedResults`.
   Query-параметри — окремі nullable-параметри або `[AsParameters]` record; значення за замовчуванням — як в openapi.yaml.
   Доменні типи й EF у Presentation заборонені: лише Query/Command і DTO.
4. **Реєстрація** автоматична (handler'и, валідатори, endpoint'и). `Program.cs` не чіпай.
5. **Infrastructure**: лише якщо потрібна нова таблиця або EF-конфіг. Тоді
   `dotnet ef migrations add <Name> -p src/Modules/M/DopamineShop.Modules.M.Infrastructure -s src/Bootstrapper/DopamineShop.Api -c MDbContext -o Persistence/Migrations`.
6. Логування: Serilog через `ILogger<T>`, структуровані властивості, без string interpolation.
7. Не додавай NuGet-пакети, не створюй модулі й не змінюй BuildingBlocks без явного пункту в плані. MediatR заборонений.
8. Запусти `dotnet-quality-gate`. Червоне → виправ, не пропускай.

## Відомі пастки
- SQLite не сортує `DateTimeOffset`: `CreatedAt` уже зберігається як ticks, тож `OrderByDescending(u => u.CreatedAt)` працює. Не змінюй конвертер.
- Пошук за email: `Email` — value object з конвертером, тому `u.Email.Value` EF не транслює. Пиши `((string)u.Email).Contains(term)`, де `term` уже в lowercase (email нормалізується при створенні). Перевірено на EF Core 10 + SQLite.
- Строго типізований id: порівнюй `u.Id == new UserId(guid)`, а не `u.Id.Value == guid`.
- Тест-класи з різною кількістю даних мають різні `ApiFactory` (кожен клас — свій `IClassFixture`).
