# Changelog

Усі помітні зміни в команді агентів. Формат — [Keep a Changelog](https://keepachangelog.com/uk/1.1.0/).

Кожен PR додає рядок у `## [Unreleased]`. Без нього CI червоний; виняток — мітка `no-changelog`.
Коміти: тема ≤ 72 символів і тіло зі списком змін (шаблон `.gitmessage`).

## [Unreleased]

### Added
- Етап 2: агент `qa` і скіл `spec-to-tests`. qa незалежно пише HTTP- і контрактні тести за спекою, веде `qa-report.md` і повертає задачу dev при FAIL, не більше двох разів.
- Етап 1: агенти `lead` і `dev`, конфіг `openclaw.json5` (перевірено на OpenClaw 2026.9.8).
- Скіли `github-issue`, `handoff`, `repo-conventions`, `minimal-api-feature`, `dotnet-quality-gate`.
- Docker-пісочниця з .NET 10 SDK, git, gh і psql; `scripts/setup.sh` і `scripts/labels.sh`.
- Спільний PostgreSQL `agent-team-postgres` у мережі `agent-team` для інтеграційних тестів у пісочниці dev, без Docker-сокета. (#1)
- CHANGELOG і CI-перевірки: запис у CHANGELOG і опис у кожному коміті PR. (#1)
- dev додає рядок у CHANGELOG dopamine-shop і пише коміти з тілом. (#1)
- Скіли .NET від Microsoft з [dotnet/skills](https://github.com/dotnet/skills) у `vendor/dotnet-skills/`: dev отримує `dotnet-webapi`, `optimizing-ef-core-queries`, `csharp-refactoring`, `run-tests`; qa — `run-tests`, `test-anti-patterns`, `assertion-quality`, `test-gap-analysis`. Правила dopamine-shop мають пріоритет. Оновлення — `scripts/update-dotnet-skills.sh`.

### Changed
- dev підписує коміти поштою GitHub-акаунта `dopamine-dev-bot`, щоб PR і коміти агентів ішли від бота, а Roman міг їх апрувити.
- dopamine-shop переїхав в організацію `Roman-Sharabura`: оновлено скіли, інструкції агентів, `labels.sh`, README і `.env.example`. (#3)
- Скіли й інструкції dev описують модульний моноліт dopamine-shop: слайси, власні handler'и, DDD, архітектурні тести. (#1)
- `gh` у пісочниці ставиться з репозиторію Ubuntu замість cli.github.com. (#1)

### Fixed
- Скіли були недоступні dev у пісочниці: `skills.load.extraDirs` не потрапляє в контейнер. `scripts/sync-skills.sh` копіює потрібні скіли у `workspaces/<agent>/skills`, які пісочниця бачить як `/workspace/skills`; `setup.sh` викликає його сам. (#5)
- Агенти не бачили ключа моделі («No route-compatible authentication source»): `setup.sh` кладе `OPENAI_API_KEY`/`ANTHROPIC_API_KEY` в auth-профілі lead і dev; OpenAI за API-ключем іде через рантайм `openclaw`. (#4)
- Шлюз не стартував: у конфіг додано `gateway.mode: "local"`; README і `setup.sh` запускають `openclaw gateway` замість `gateway start` (той лише для встановленої служби) і описують перший тест без Telegram. (#2)
- README і `.env.example` описують запуск на Windows через WSL2. (#2)
