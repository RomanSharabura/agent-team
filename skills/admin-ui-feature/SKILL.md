---
name: admin-ui-feature
description: Add or change a page in the dopamine-shop admin UI (web/admin, React + TS + Vite, TanStack Query, openapi-fetch) with Vitest + Testing Library tests per REQ.
metadata: { "openclaw": { "requires": { "bins": ["node", "npm", "git"] } } }
---
# Admin UI feature (web/admin)

Rules — `docs/conventions.md`, the admin frontend section (`web/admin`), and ADR 0007. Examples: `src/features/users/list-users` (SPEC-001) and `src/features/users/get-user-by-id` (SPEC-000).
All commands run from `web/admin`. First time in the branch: `npm ci`.

## Structure
- Slice: `src/features/<module>/<feature>/`, named after the backend feature in kebab-case (`UpdateUser` → `update-user`).
  Hook `use<Feature>.ts`, components `<Name>.tsx`, tests `<Name>.test.tsx` next to them.
- New page → a line in `src/App.tsx`. Extending an existing page (button, form) → a component in its own slice; the other slice's page only renders it.
- `src/shared/` — only what does not know about a specific feature.

## API
- Only `api` from `src/api/client.ts`: `api.GET/PATCH/POST('/admin/...', { params, body, signal })` and `unwrap()`. No manual `fetch` and no hand-written response types.
- Types come from `src/api/generated` (short names in `src/api/types.ts`). `openapi.yaml` changed in the spec → `npm run gen:api` and commit `src/api/generated`. Do not edit these files by hand.
- Reads — `useQuery` with the key `['<module>', 'detail' | 'list', ...]`, as in the examples.
- Writes — `useMutation`. On success: `queryClient.setQueryData` for the detail card from the response body and `invalidateQueries({ queryKey: ['<module>', 'list'] })` so the list does not show stale data. No optimistic updates unless the spec explicitly asks for them.
- Errors: `unwrap` throws `ApiError` with `status` and `problem`. 400 → `problem.errors[<field>][0]` under the field; 404 and the rest — texts from the spec with `role="alert"`. A network error is not an `ApiError`.

## Forms
- Controlled `<input>` with a `<label>` (the test finds the field via `getByLabelText`). Buttons — `<button type="submit">` / `type="button"`.
- Validation before the request — the same limits as in `openapi.yaml` (`minLength`, `maxLength`) and in the spec, applied to the value after `trim()`. Error under the field, `aria-invalid` on the field.
- While the request is in flight, the save button is `disabled={mutation.isPending}`.
- UI texts — exactly as in the spec (same wording, same apostrophe character). Do not invent your own wording.

## Tests (Vitest + Testing Library)
- `describe('<Name> (SPEC-NNN)')`, the `it` name starts with the REQ-ID: `it('REQ-002 saves the new name', ...)`. At least one test per REQ.
- Render the whole admin UI: `renderApp('/users/<id>')` from `src/test/render.tsx`. Actions — `userEvent.setup()`; queries — by role, label and text (`getByRole('button', { name: 'Save' })`), not by classes.
- API: `mockApi(handler)` returns `[status, body]`. For several requests (GET of the card, then PATCH) tell them apart; if `handler` cannot see the method or body, extend `mockApi` in `src/test/render.tsx` compatibly (an extra `Request` argument), do not change existing tests.
  Request method and body for assertions: `fetchMock.mock.calls` → `Request`; `request.method`, `await request.clone().json()`.
- Network error: `vi.spyOn(globalThis, 'fetch').mockRejectedValue(new TypeError('Failed to fetch'))`.
- Check "no request was made" explicitly: not a single call with method `PATCH`.
- Async — `findBy*` / `waitFor`, no `setTimeout`.

## Before committing
`admin-ui-gate`. Red → fix the code, do not weaken lint, types or tests (`// eslint-disable`, `any`, `@ts-ignore` — only with a comment giving the reason and a mention in the PR).
New npm packages — only with an item in `plan.md`; then `npm install <pkg>` and commit `package-lock.json`.
