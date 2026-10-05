---
name: git-commit
description: Write commits with a short typed subject and a body listing what changed and why; keep CHANGELOG.md updated per PR.
metadata: { "openclaw": { "requires": { "bins": ["git"] } } }
---
# Git commit

Читач коміту має зрозуміти зміну без diff. CI (`PR hygiene`) перевіряє тему і тіло кожного коміту та запис у CHANGELOG.

## Формат
```text
<тип>(<модуль>): <REQ-ID якщо є> <що зроблено>      ≤ 72 символи

- що змінилось і навіщо (по пункту на кожну помітну зміну)
- назви класів, ендпоінтів, міграцій — як у коді
- що НЕ змінювалось, якщо це неочевидно

Refs: SPEC-NNN, #<issue>
```
Типи: `feat`, `fix`, `refactor`, `test`, `docs`, `build`, `ci`, `chore`.

## Як комітити
Пиши повідомлення у файл і передавай через `-F`, щоб тіло не загубилось:
```bash
cat > /tmp/commit-msg <<'MSG'
feat(users): REQ-003 пошук користувачів за email

- ListUsersHandler фільтрує за підрядком email; term переводиться в lowercase
- ListUsersValidator обмежує search 320 символами, як в openapi.yaml
- інтеграційний тест REQ_003_search_by_email_case_insensitive

Refs: SPEC-001, #1
MSG
git commit -F /tmp/commit-msg
```

## CHANGELOG
- Один рядок на PR у `## [Unreleased]` у розділ `Added` / `Changed` / `Fixed` / `Removed` / `Security`.
- Пиши, що змінилось для користувача API чи розробника, а не як: «Список користувачів в адмінці з пагінацією, пошуком за email і фільтром за статусом. (SPEC-001, #1)».
- Не редагуй старі рядки й розділи релізів.

## Не можна
- Коміт без тіла, `wip`, `fix`, `update` як уся тема.
- `--amend` і force-push після того, як PR відкрито: нові зміни — нові коміти.
