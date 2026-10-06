---
name: minimal-api-feature
description: Add a vertical slice to a dopamine-shop module (modular monolith, Clean Architecture, own IQuery/ICommand handlers, DDD).
metadata: { "openclaw": { "requires": { "bins": ["dotnet", "git"] } } }
---
# Minimal API feature (vertical slice)

Example: `GetUserById` in the Users module (SPEC-000). Copy its shape, do not invent your own.
The rules are checked by the architecture tests. A red architecture test = change the code, not the test.

Let `M` be the module (for example `Users`), `F` the feature (for example `ListUsers`).

1. **Domain** (`src/Modules/M/DopamineShop.Modules.M.Domain`): only if the feature changes behavior.
   New behavior — an aggregate method that checks invariants and throws `DomainException`. Do not add public setters.
2. **Application** (`.../DopamineShop.Modules.M.Application/Features/F/`):
   - `FQuery.cs` or `FCommand.cs`: `public sealed record ... : IQuery<T>` / `ICommand<T>` / `ICommand`.
   - `FHandler.cs`: `internal sealed class FHandler(IMDbContext db) : IQueryHandler<FQuery, T>`; `AsNoTracking()` for reads; `CancellationToken` in every async call.
   - `FValidator.cs`: `internal sealed class : AbstractValidator<FQuery>`.
   - DTOs needed by several slices go in `Common/`. Do not use types from other slices.
3. **Presentation** (`.../DopamineShop.Modules.M.Presentation/Features/F/FEndpoint.cs`):
   `internal sealed class FEndpoint : IEndpoint`; in `MapEndpoint` — `app.MapGet(...)` with `.WithName("F").WithTags(Tags.<...>)`.
   The handler is injected as a parameter: `IQueryHandler<FQuery, T> handler`. Return `Results<...>` via `TypedResults`.
   Query parameters — separate nullable parameters or an `[AsParameters]` record; default values — as in openapi.yaml.
   Domain types and EF are forbidden in Presentation: only Query/Command and DTOs.
4. **Registration** is automatic (handlers, validators, endpoints). Do not touch `Program.cs`.
5. **Infrastructure**: only if a new table or EF config is needed. Then
   `dotnet ef migrations add <Name> -p src/Modules/M/DopamineShop.Modules.M.Infrastructure -s src/Bootstrapper/DopamineShop.Api -c MDbContext -o Persistence/Migrations`.
6. Logging: Serilog via `ILogger<T>`, structured properties, no string interpolation.
7. Do not add NuGet packages, create modules or change BuildingBlocks without an explicit item in the plan. MediatR is forbidden.
8. Run `dotnet-quality-gate`. Red → fix, do not skip.

## Tests
- Unit (`tests/Modules/M/...UnitTests`): only the domain and validators, no DB.
- Handlers: `tests/DopamineShop.IntegrationTests/Modules/M/Handlers/F/`, the handler is resolved from DI via `factory.InScopeAsync<IQueryHandler<FQuery, T>, T>(...)`.
- HTTP scenarios: `tests/DopamineShop.IntegrationTests/Modules/M/FTests.cs`, names `REQ_00x_<scenario>`.
- DB — a real PostgreSQL; each test class (`IClassFixture<ApiFactory>`) gets its own empty DB.

## Known pitfalls
- The database is PostgreSQL, module schema (`users`), names in snake_case. Tables and columns are created by migrations, not by hand.
- Search by email: `Email` is a value object with a converter, so EF does not translate `u.Email.Value`. Write `((string)u.Email).Contains(term)`. `LIKE` in Postgres is case-sensitive, so lowercase `term` (email in the DB is already lowercase). Verified on EF Core 10 + Npgsql.
- Dates — `timestamptz` in UTC. Do not pass a `DateTimeOffset` with a non-zero offset into queries.
- Strongly typed id: compare `u.Id == new UserId(guid)`, not `u.Id.Value == guid`.
- Put tests that count records in a separate test class: other classes' data will not get there.
