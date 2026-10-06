---
name: spec-to-tests
description: Turn a dopamine-shop spec (EARS requirements, Gherkin scenarios, openapi.yaml) into independent HTTP and contract tests and a qa-report.md.
metadata: { "openclaw": { "requires": { "bins": ["dotnet", "git"] } } }
---
# Spec → tests

Джерело очікувань — `spec.md` і `openapi.yaml`, а не код. Зразок форми тестів: `tests/DopamineShop.IntegrationTests/Modules/Users/ListUsersTests.cs` (SPEC-001).

## Куди писати
- HTTP-сценарії: `tests/DopamineShop.IntegrationTests/Modules/<M>/<F>Tests.cs`. Якщо файл уже є від dev, додавай класи в нього, не переписуй чужі.
- Контракт: `tests/DopamineShop.IntegrationTests/Modules/<M>/<F>ContractTests.cs`.
- Нових проєктів, пакетів і хелперів у `Infrastructure/` не створюй. Є `ApiFactory`, `factory.SeedAsync<TDbContext>(...)`, `factory.CreateClient()`, FluentAssertions і xUnit.

## 1. Сценарій → тест
Для кожного Gherkin-сценарію:
- назва `REQ_00x_<сценарій_англійською_snake_case>` і `[Trait("Req", "REQ-00x")]`;
- `Given` → засів даних через доменні фабрики (`User.Register(...)`), `When` → один HTTP-запит, `Then` → перевірки;
- тести, що рахують записи (`totalCount`, кількість `items`), клади в окремий клас з власним `IClassFixture<ApiFactory>`: у кожного класу своя порожня БД;
- перевіряй усе, що каже `Then`: код, порядок, кількість, конкретні значення, а не лише «не порожньо».

## 2. Контракт з openapi.yaml
Тести dev десеріалізують відповідь у DTO самого застосунку, тож перейменування поля з обох боків вони не помітять. Ти читай сирий JSON:

```csharp
var json = await response.Content.ReadAsStringAsync();
using var doc = JsonDocument.Parse(json);
var root = doc.RootElement;
root.EnumerateObject().Select(p => p.Name).Should().Contain(["items", "page", "pageSize", "totalCount"]);
root.GetProperty("page").ValueKind.Should().Be(JsonValueKind.Number);
```

Для кожного шляху й методу з `openapi.yaml`:
- кожен описаний код відповіді досяжний, і `Content-Type` збігається (`application/json`, `application/problem+json`);
- усі `required` поля є, назви в camelCase точно як у схемі, типи збігаються (`integer`, `string`, `array`, `format: date-time`, `format: uuid`);
- `enum` у відповідях містить лише дозволені значення;
- параметри: значення за замовчуванням (`default`), межі (`minimum`, `maximum`, `maxLength`) — тест на межу і на одиницю за межею;
- 400: тіло `ValidationProblemDetails`, `status: 400`, у `errors` ключі — імена параметрів запиту.

## 3. Вимоги поза сценаріями
Пройдись по кожній EARS-вимозі (`WHEN ... THE SYSTEM SHALL ...`, `IF ... THEN ...`). Якщо умова має випадок, якого немає в Gherkin (порожній результат, межа, комбінація фільтрів), додай тест з тим самим `Trait`.

## 4. Знахідки
Тест червоний → спершу перевір себе: перечитай вимогу, засів, URL. Помиляється код → залиш тест червоним і запиши знахідку:

```text
REQ-004 — status=blocked повертає лише заблокованих — повертає всіх (3 замість 1) — REQ_004_filter_returns_only_blocked_users
```

## UI-спеки (`web/admin`)
Спека про адмінку → тести сторінки на Vitest + Testing Library замість HTTP-тестів (форму тестів і хелпери див. скіл `admin-ui-feature`, розділ «Тести»).
- Файл `src/features/<module>/<feature>/<Name>.qa.test.tsx` поруч з тестами dev: їхні файли не переписуй.
- `describe('<Name> — qa (SPEC-NNN)')`, кожен `it` починається з REQ-ID і назви сценарію: `it('REQ-004 порожнє ім’я', ...)`.
- `Given` → `mockApi` з даними, `When` → дії `userEvent`, `Then` → усе, що каже сценарій: точний текст, роль (`alert`, `status`), стан кнопки, кількість запитів, метод і тіло (`await request.clone().json()`).
- Контракт замість пункту 2: тіло запиту має лише поля зі схеми `requestBody` у `openapi.yaml`, з тими самими межами; UI обробляє кожен код з `responses` (тест на кожен).
- Знахідка має той самий формат, тест — назва `it`.
- Gate: `admin-ui-gate` (і `dotnet-quality-gate`, якщо diff зачіпає .NET). У звіті розділ «Контракт» — запити UI до API, «Quality gate» — `npm run check`.

## 5. qa-report.md
У папці спеки. Якщо файл уже є (його міг лишити dev), перепиши повністю.

```markdown
# QA report — SPEC-NNN

Дата: YYYY-MM-DD. Гілка: ai/<issue>-<slug>. Спроба: N. Вердикт: PASS | FAIL.

## Матриця REQ → сценарій → тест → статус
| REQ | Сценарій | Тести | Автор | Статус |
| --- | --- | --- | --- | --- |
| REQ-001 | <назва з Gherkin> | REQ_001_... | qa / dev | PASS / FAIL |

## Контракт (openapi.yaml)
| Перевірка | Тест | Статус |
| --- | --- | --- |
| GET /admin/users 200: required-поля й типи | Contract_list_users_200_shape | PASS |

## Знахідки
- REQ-00x — очікувано — фактично — тест (або «немає»)

## Quality gate
build, format, test: результат і кількість тестів (усього / нових від qa / червоних).
```

REQ без жодного зеленого тесту = FAIL. Поле `Автор` показує, чий тест закриває вимогу: так видно, що перевірка незалежна.
