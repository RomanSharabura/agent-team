# Changelog

Усі помітні зміни в команді агентів. Формат — [Keep a Changelog](https://keepachangelog.com/uk/1.1.0/).

Кожен PR додає рядок у `## [Unreleased]`. Без нього CI червоний; виняток — мітка `no-changelog`.
Коміти: тема ≤ 72 символів і тіло зі списком змін (шаблон `.gitmessage`).

## [Unreleased]

### Added
- Етап 5, адмінка: агенти працюють і з `web/admin` dopamine-shop (React + Vite). Node 24 у пісочниці; скіли `admin-ui-feature` (слайс, форми, мутації, тести сторінки на Vitest) для architect, dev і qa та `admin-ui-gate` (`npm run check`) для dev і qa. ba перевіряє спеки лише для UI проти наявного `openapi.yaml`, architect планує UI-шар, qa пише тести сторінки в `*.qa.test.tsx`, lead перевіряє UI в review. Після оновлення треба перебудувати образ пісочниці.
- Етап 3: агенти `ba` і `architect`, скіли `spec-validate`, `spec-to-plan` і `adr-writer`. ba перевіряє спеку до роботи і повертає PASS або питання (lead ставить `ai-needs-input` з коментарем «Spec validation»); architect створює гілку з `plan.md` і `tasks.md`, де кожен крок має REQ-ID, і за потреби чернетку ADR. dev виконує готовий план замість того, щоб писати його сам. Нові змінні `.env`: `BA_MODEL`, `ARCHITECT_MODEL`, `GH_TOKEN_BA`, `GH_TOKEN_ARCHITECT`.
- Code review від lead: скіл `pr-review` (чекліст за спекою, архітектурою, безпекою й тестами). Після PASS від qa lead лишає в PR review з коментарями до рядків; 🔴 blocking повертає dev у спільній петлі з qa (разом не більше двох повернень), 🟡 nit лишає людині. Чистий PR lead переводить з draft у ready і додає Roman у рев'юери; мержить лише людина.
- Етап 2: агент `qa` і скіл `spec-to-tests`. qa незалежно пише HTTP- і контрактні тести за спекою, веде `qa-report.md` і повертає задачу dev при FAIL, не більше двох разів.
- Етап 1: агенти `lead` і `dev`, конфіг `openclaw.json5` (перевірено на OpenClaw 2026.9.8).
- Скіли `github-issue`, `handoff`, `repo-conventions`, `minimal-api-feature`, `dotnet-quality-gate`.
- Docker-пісочниця з .NET 10 SDK, git, gh і psql; `scripts/setup.sh` і `scripts/labels.sh`.
- Спільний PostgreSQL `agent-team-postgres` у мережі `agent-team` для інтеграційних тестів у пісочниці dev, без Docker-сокета. (#1)
- CHANGELOG і CI-перевірки: запис у CHANGELOG і опис у кожному коміті PR. (#1)
- dev додає рядок у CHANGELOG dopamine-shop і пише коміти з тілом. (#1)
- Скіли .NET від Microsoft з [dotnet/skills](https://github.com/dotnet/skills) у `vendor/dotnet-skills/`: dev отримує `dotnet-webapi`, `optimizing-ef-core-queries`, `csharp-refactoring`, `run-tests`; qa — `run-tests`, `test-anti-patterns`, `assertion-quality`, `test-gap-analysis`. Правила dopamine-shop мають пріоритет. Оновлення — `scripts/update-dotnet-skills.sh`.

### Fixed
- lead втрачав `sessions_spawn` у ході, що приходив після відповіді агента (на SPEC-003 зупинився перед architect і перед dev). Тепер lead після кожного `sessions_spawn` чекає через `sessions_yield`, а `sessions_spawn`, `sessions_yield` і `subagents` дозволено йому явно.
- lead не міг передати задачу architect: Tool Search ховав `sessions_spawn`, і пошук його не знаходив. `tools.toolSearch: false` — агенти бачать усі свої інструменти напряму.
- Автор комітів dev і qa задано змінними `GIT_AUTHOR_*` і `GIT_COMMITTER_*` у пісочниці: qa на SPEC-002 не зміг закомітити `qa-report.md` без `git config`.

### Changed
- Чат з lead перенесено з Telegram у Slack (Socket Mode, плагін `@openclaw/slack`, ставить `setup.sh`). Маніфест застосунку в `slack/app-manifest.json`, нові змінні `.env`: `SLACK_APP_TOKEN`, `SLACK_BOT_TOKEN`, `SLACK_OWNER_ID`. Telegram лишився закоментованим у конфігу.
- dev підписує коміти поштою GitHub-акаунта `dopamine-dev-bot`, щоб PR і коміти агентів ішли від бота, а Roman міг їх апрувити.
- dopamine-shop переїхав в організацію `Roman-Sharabura`: оновлено скіли, інструкції агентів, `labels.sh`, README і `.env.example`. (#3)
- Скіли й інструкції dev описують модульний моноліт dopamine-shop: слайси, власні handler'и, DDD, архітектурні тести. (#1)
- `gh` у пісочниці ставиться з репозиторію Ubuntu замість cli.github.com. (#1)

### Fixed
- Скіли були недоступні dev у пісочниці: `skills.load.extraDirs` не потрапляє в контейнер. `scripts/sync-skills.sh` копіює потрібні скіли у `workspaces/<agent>/skills`, які пісочниця бачить як `/workspace/skills`; `setup.sh` викликає його сам. (#5)
- Агенти не бачили ключа моделі («No route-compatible authentication source»): `setup.sh` кладе `OPENAI_API_KEY`/`ANTHROPIC_API_KEY` в auth-профілі lead і dev; OpenAI за API-ключем іде через рантайм `openclaw`. (#4)
- Шлюз не стартував: у конфіг додано `gateway.mode: "local"`; README і `setup.sh` запускають `openclaw gateway` замість `gateway start` (той лише для встановленої служби) і описують перший тест без Telegram. (#2)
- README і `.env.example` описують запуск на Windows через WSL2. (#2)
