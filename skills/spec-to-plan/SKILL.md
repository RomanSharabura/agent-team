---
name: spec-to-plan
description: Write plan.md and tasks.md for a dopamine-shop spec (modular monolith, Clean Architecture, vertical slices, own IQuery/ICommand handlers), every task tied to REQ-IDs.
metadata: { "openclaw": { "requires": { "bins": ["git"] } } }
---
# Spec → plan

Формат за GitHub Spec Kit: `spec.md` (що) → `plan.md` (як) → `tasks.md` (кроки). Зразки: `specs/001-admin-users-list/` і `specs/002-admin-edit-user/` у `main`.
Обидва файли — у папці спеки, поруч зі `spec.md`.

## Що з'ясувати до плану
- **Модуль.** Якого модуля стосується спека (`src/Modules/<M>`). Новий модуль — лише якщо спека прямо про це, і тоді ADR.
- **Слайси.** Нові (`Features/<F>/`) чи зміна наявних; query чи command (`IQuery<T>`, `ICommand<T>`, `ICommand`), що повертає handler і як це мапиться на коди з `openapi.yaml`.
- **Домен.** Нова поведінка → метод агрегату з інваріантами і `DomainException`. Яку наявну перевірку перевикористати (наприклад, спільна з `Register`).
- **Дані.** Нові таблиці чи колонки → міграція (назва), індекси під фільтри й сортування зі спеки. Без змін схеми → «Міграція: ні».
- **Контракт.** Маршрут, параметри, тіло, коди відповідей — з `openapi.yaml` без змін. Якщо зручніший контракт хочеться — це питання до Roman (`QUESTIONS`), а не правка.
- **Ризики.** Що може піти не так: трансляція EF (value objects у `Where`), регістр і `LIKE` у Postgres, часові пояси, конкурентний запис, розрізнення `null` і відсутнього поля.

## plan.md
```markdown
# Plan — SPEC-NNN

Модуль: <M>. Слайс: <F>. Контракт і спека не змінюються.

| Шар | Файли | Зміна |
| --- | --- | --- |
| Domain | `User.cs` | ... або «без змін» |
| Application | `Features/<F>/<F>Command.cs`, `<F>Handler.cs`, `<F>Validator.cs` | ... |
| Infrastructure | ... | ... або «без змін» |
| Presentation | `Features/<F>/<F>Endpoint.cs` | `<METHOD> <route>`, operation `<F>` |
| Tests | шляхи unit-, handler- і HTTP-тестів | що покривають |

- Команда/запит: `<F>Command(...) : ICommand<T>`; як результат мапиться на коди відповідей.
- REQ-001…: одним рядком, як закрита кожна REQ (можна групувати).
- Міграція: так (`<Name>`) / ні. Нові пакети: ні (або пакет, причина і посилання на ADR).
- ADR: немає / `docs/adr/NNNN-slug.md` (proposed).
- Ризики: ... або «немає».
```
Шляхи — відносно `src/Modules/<M>/DopamineShop.Modules.<M>.<Шар>/` і `tests/`, як у зразках. До 40 рядків.

## tasks.md
```markdown
# Tasks — SPEC-NNN

- [ ] 1. REQ-001, REQ-003: <що зробити>. Готово: <перевірний критерій>.
- [ ] 2. ...
```
- 3–8 кроків, у порядку виконання: домен → application → presentation → міграція (якщо є).
- Кожен крок має REQ-ID і критерій готовності, який dev перевіряє командою або тестом («unit-тести валідатора зелені», «`dotnet ef migrations list` показує `<Name>`»).
- Один крок — один коміт dev, тож крок має бути завершеним і зеленим сам по собі.
- Кожна REQ зі `spec.md` — хоча б в одному кроці. Перевір перед комітом:
```bash
S=specs/<NNN-slug>
comm -23 <(grep -oE 'REQ-[0-9]{3}' $S/spec.md | sort -u) <(grep -oE 'REQ-[0-9]{3}' $S/tasks.md | sort -u)   # має бути порожньо
```
- Галочки `[x]` ставить dev, коли крок виконано. Ти лишаєш `[ ]`.

## Чого в плані немає
Коду, сигнатур усіх методів, тексту тестів. План каже, що і де, а не як писати кожен рядок: це робить dev за `minimal-api-feature`.
