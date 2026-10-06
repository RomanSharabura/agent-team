---
name: admin-ui-gate
description: Run the dopamine-shop admin UI checks (generated API types fresh, prettier, eslint, tsc, Vitest, vite build) in web/admin; required before push when web/admin or specs/*/openapi.yaml changed.
metadata: { "openclaw": { "requires": { "bins": ["node", "npm"] } } }
---
# Admin UI gate

Required when the branch diff touches `web/admin/` or `specs/*/openapi.yaml` (the `Admin UI` CI decides the same way):
```bash
git diff --name-only origin/main...HEAD | grep -qE '^(web/admin/|specs/.*/openapi\.yaml$)' && echo "admin-ui-gate required"
```

From `web/admin`, every command must exit with code 0:
```bash
npm ci
npm run check
```
`check` runs in order: `gen:api` and a check that `src/api/generated` has not changed; `prettier --check`; `eslint --max-warnings 0`; `tsc --noEmit`; `vitest run`; `vite build`.

- `src/api/generated` is stale → `npm run gen:api` and commit the generated files. Do not edit by hand.
- Prettier is red → `npm run format`, review the diff, commit.
- Tests are not skipped (`it.skip`, `it.todo`), deleted or weakened to turn green.
- `npm ci` failed on the network → return `BLOCKED` with the error text: this is the environment, not the code.
- Trim the output: only lines with `error`, `✗`/`FAIL` and the summary.

For qa: `format`, `lint`, `typecheck` and `build` must be green before push, and red tests that show findings are pushed together with `verdict: FAIL`.

Result in the envelope: `ui-gate: green` or `ui-gate: red` with the first 20 error lines.
