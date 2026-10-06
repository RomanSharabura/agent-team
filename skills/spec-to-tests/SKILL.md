---
name: spec-to-tests
description: Turn a dopamine-shop spec (EARS requirements, Gherkin scenarios, openapi.yaml) into independent HTTP and contract tests and a qa-report.md.
metadata: { "openclaw": { "requires": { "bins": ["dotnet", "git"] } } }
---
# Spec → tests

The source of expectations is `spec.md` and `openapi.yaml`, not the code. Example of the test shape: `tests/DopamineShop.IntegrationTests/Modules/Users/ListUsersTests.cs` (SPEC-001).

## Where to write
- HTTP scenarios: `tests/DopamineShop.IntegrationTests/Modules/<M>/<F>Tests.cs`. If dev has already created the file, add classes to it; do not rewrite others' classes.
- Contract: `tests/DopamineShop.IntegrationTests/Modules/<M>/<F>ContractTests.cs`.
- Do not create new projects, packages or helpers in `Infrastructure/`. Available: `ApiFactory`, `factory.SeedAsync<TDbContext>(...)`, `factory.CreateClient()`, FluentAssertions and xUnit.

## 1. Scenario → test
For every Gherkin scenario:
- name `REQ_00x_<scenario_in_english_snake_case>` and `[Trait("Req", "REQ-00x")]`;
- `Given` → data seeding through domain factories (`User.Register(...)`), `When` → one HTTP request, `Then` → assertions;
- put tests that count records (`totalCount`, number of `items`) in a separate class with its own `IClassFixture<ApiFactory>`: each class has its own empty DB;
- check everything `Then` says: code, order, count, specific values, not just "not empty".

## 2. Contract from openapi.yaml
Dev's tests deserialize the response into the application's own DTO, so they will not notice a field renamed on both sides. You read the raw JSON:

```csharp
var json = await response.Content.ReadAsStringAsync();
using var doc = JsonDocument.Parse(json);
var root = doc.RootElement;
root.EnumerateObject().Select(p => p.Name).Should().Contain(["items", "page", "pageSize", "totalCount"]);
root.GetProperty("page").ValueKind.Should().Be(JsonValueKind.Number);
```

For every path and method in `openapi.yaml`:
- every documented response code is reachable, and `Content-Type` matches (`application/json`, `application/problem+json`);
- all `required` fields are present, names in camelCase exactly as in the schema, types match (`integer`, `string`, `array`, `format: date-time`, `format: uuid`);
- `enum` in responses contains only allowed values;
- parameters: default values (`default`), limits (`minimum`, `maximum`, `maxLength`) — a test at the limit and one past it;
- 400: body is `ValidationProblemDetails`, `status: 400`, the keys in `errors` are the request parameter names.

## 3. Requirements beyond the scenarios
Go through every EARS requirement (`WHEN ... THE SYSTEM SHALL ...`, `IF ... THEN ...`). If a condition has a case not in the Gherkin (empty result, boundary, combination of filters), add a test with the same `Trait`.

## 4. Findings
A test is red → first check yourself: reread the requirement, the seeding, the URL. The code is wrong → leave the test red and record a finding:

```text
REQ-004 — status=blocked returns only blocked users — returns all (3 instead of 1) — REQ_004_filter_returns_only_blocked_users
```

## UI specs (`web/admin`)
Spec about the admin UI → page tests on Vitest + Testing Library instead of HTTP tests (for the test shape and helpers see skill `admin-ui-feature`, section "Tests").
- File `src/features/<module>/<feature>/<Name>.qa.test.tsx` next to dev's tests: do not rewrite their files.
- `describe('<Name> — qa (SPEC-NNN)')`, every `it` starts with the REQ-ID and the scenario name: `it('REQ-004 empty name', ...)`.
- `Given` → `mockApi` with data, `When` → `userEvent` actions, `Then` → everything the scenario says: exact text, role (`alert`, `status`), button state, number of requests, method and body (`await request.clone().json()`).
- Contract instead of item 2: the request body has only the fields from the `requestBody` schema in `openapi.yaml`, with the same limits; the UI handles every code from `responses` (a test for each).
- A finding has the same format; the test is the `it` name.
- Gate: `admin-ui-gate` (and `dotnet-quality-gate` if the diff touches .NET). In the report, the "Contract" section covers the UI's requests to the API, "Quality gate" — `npm run check`.

## 5. qa-report.md
In the spec folder, in English. If the file already exists (dev might have left it), rewrite it completely.

```markdown
# QA report — SPEC-NNN

Date: YYYY-MM-DD. Branch: ai/<issue>-<slug>. Attempt: N. Verdict: PASS | FAIL.

## Matrix REQ → scenario → test → status
| REQ | Scenario | Tests | Author | Status |
| --- | --- | --- | --- | --- |
| REQ-001 | <name from Gherkin> | REQ_001_... | qa / dev | PASS / FAIL |

## Contract (openapi.yaml)
| Check | Test | Status |
| --- | --- | --- |
| GET /admin/users 200: required fields and types | Contract_list_users_200_shape | PASS |

## Findings
- REQ-00x — expected — actual — test (or "none")

## Quality gate
build, format, test: result and number of tests (total / new from qa / red).
```

A REQ without a single green test = FAIL. The `Author` field shows whose test covers the requirement: this makes it visible that the check is independent.
