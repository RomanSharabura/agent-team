---
name: admin-ui-gate
description: Run the dopamine-shop admin UI checks (generated API types fresh, prettier, eslint, tsc, Vitest, vite build) in web/admin; required before push when web/admin or specs/*/openapi.yaml changed.
metadata: { "openclaw": { "requires": { "bins": ["node", "npm"] } } }
---
# Admin UI gate

Потрібен, коли diff гілки зачіпає `web/admin/` або `specs/*/openapi.yaml` (так само вирішує CI `Admin UI`):
```bash
git diff --name-only origin/main...HEAD | grep -qE '^(web/admin/|specs/.*/openapi\.yaml$)' && echo "потрібен admin-ui-gate"
```

З `web/admin`, кожна команда має завершитись з кодом 0:
```bash
npm ci
npm run check
```
`check` по черзі: `gen:api` і перевірка, що `src/api/generated` не змінився; `prettier --check`; `eslint --max-warnings 0`; `tsc --noEmit`; `vitest run`; `vite build`.

- `src/api/generated` застарів → `npm run gen:api` і закоміть згенероване. Руками не редагуй.
- Prettier червоний → `npm run format`, переглянь diff, закоміть.
- Тести не пропускаються (`it.skip`, `it.todo`), не видаляються і не послаблюються, щоб стати зеленими.
- `npm ci` впав на мережі → поверни `BLOCKED` з текстом помилки: це оточення, а не код.
- Вивід скорочуй: лише рядки з `error`, `✗`/`FAIL` і підсумок.

Для qa: `format`, `lint`, `typecheck` і `build` мають бути зелені перед push, а червоні тести, що показують знахідки, пушаться разом з `verdict: FAIL`.

Результат у конверт: `ui-gate: green` або `ui-gate: red` з першими 20 рядками помилок.
