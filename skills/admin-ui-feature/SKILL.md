---
name: admin-ui-feature
description: Add or change a page in the dopamine-shop admin UI (web/admin, React + TS + Vite, TanStack Query, openapi-fetch) with Vitest + Testing Library tests per REQ.
metadata: { "openclaw": { "requires": { "bins": ["node", "npm", "git"] } } }
---
# Admin UI feature (web/admin)

Правила — `docs/conventions.md`, розділ «Фронтенд адмінки», і ADR 0007. Зразки: `src/features/users/list-users` (SPEC-001) і `src/features/users/get-user-by-id` (SPEC-000).
Усі команди — з `web/admin`. Перший раз у гілці: `npm ci`.

## Структура
- Слайс: `src/features/<module>/<feature>/`, назва — фіча бекенду в kebab-case (`UpdateUser` → `update-user`).
  Хук `use<Feature>.ts`, компоненти `<Name>.tsx`, тести `<Name>.test.tsx` поруч.
- Нова сторінка → рядок у `src/App.tsx`. Доповнення наявної сторінки (кнопка, форма) → компонент у своєму слайсі, сторінка іншого слайсу лише рендерить його.
- `src/shared/` — лише те, що не знає про конкретну фічу.

## API
- Лише `api` з `src/api/client.ts`: `api.GET/PATCH/POST('/admin/...', { params, body, signal })` і `unwrap()`. Ручних `fetch` і ручних типів відповідей немає.
- Типи — з `src/api/generated` (короткі імена в `src/api/types.ts`). Змінився `openapi.yaml` у спеці → `npm run gen:api` і закоміть `src/api/generated`. Руками ці файли не редагуй.
- Читання — `useQuery` з ключем `['<module>', 'detail' | 'list', ...]`, як у зразках.
- Зміна — `useMutation`. Після успіху: `queryClient.setQueryData` для картки з тіла відповіді і `invalidateQueries({ queryKey: ['<module>', 'list'] })`, щоб список не показував старе. Оптимістичних оновлень не роби, якщо спека прямо не просить.
- Помилка: `unwrap` кидає `ApiError` зі `status` і `problem`. 400 → `problem.errors[<поле>][0]` під полем; 404 і решта — тексти зі спеки з `role="alert"`. Мережева помилка — не `ApiError`.

## Форми
- Контрольований `<input>` з `<label>` (тест шукає поле через `getByLabelText`). Кнопки — `<button type="submit">` / `type="button"`.
- Валідація до запиту — ті самі межі, що в `openapi.yaml` (`minLength`, `maxLength`) і в спеці, на значенні після `trim()`. Помилка під полем, `aria-invalid` на полі.
- Поки йде запит, кнопка збереження `disabled={mutation.isPending}`.
- Тексти інтерфейсу — точно як у спеці (українською, той самий апостроф). Своїх формулювань не вигадуй.

## Тести (Vitest + Testing Library)
- `describe('<Name> (SPEC-NNN)')`, назва `it` починається з REQ-ID: `it('REQ-002 зберігає нове ім’я', ...)`. Хоча б один тест на кожну REQ.
- Рендер усієї адмінки: `renderApp('/users/<id>')` з `src/test/render.tsx`. Дії — `userEvent.setup()`, пошук — за роллю, підписом і текстом (`getByRole('button', { name: 'Зберегти' })`), а не за класами.
- API: `mockApi(handler)` повертає `[статус, тіло]`. Для кількох запитів (GET картки, потім PATCH) розрізняй їх; якщо `handler` не бачить методу чи тіла, розшир `mockApi` у `src/test/render.tsx` сумісно (додатковий аргумент `Request`), наявні тести не міняй.
  Метод і тіло запиту для перевірки: `fetchMock.mock.calls` → `Request`; `request.method`, `await request.clone().json()`.
- Мережева помилка: `vi.spyOn(globalThis, 'fetch').mockRejectedValue(new TypeError('Failed to fetch'))`.
- «Запиту не було» перевіряй явно: жодного виклику з методом `PATCH`.
- Асинхронне — `findBy*` / `waitFor`, без `setTimeout`.

## Перед комітом
`admin-ui-gate`. Червоне → виправ код, не послаблюй lint, типи й тести (`// eslint-disable`, `any`, `@ts-ignore` — лише з коментарем-причиною і згадкою в PR).
Нові npm-пакети — лише з пунктом у `plan.md`; тоді `npm install <pkg>` і закоміть `package-lock.json`.
