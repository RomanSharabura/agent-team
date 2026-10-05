# Changelog

Усі помітні зміни в команді агентів. Формат — [Keep a Changelog](https://keepachangelog.com/uk/1.1.0/).

Кожен PR додає рядок у `## [Unreleased]`. Без нього CI червоний; виняток — мітка `no-changelog`.
Коміти: тема ≤ 72 символів і тіло зі списком змін (шаблон `.gitmessage`).

## [Unreleased]

### Added
- Етап 1: агенти `lead` і `dev`, конфіг `openclaw.json5` (перевірено на OpenClaw 2026.9.8).
- Скіли `github-issue`, `handoff`, `repo-conventions`, `minimal-api-feature`, `dotnet-quality-gate`.
- Docker-пісочниця з .NET 10 SDK, git, gh і psql; `scripts/setup.sh` і `scripts/labels.sh`.
- Спільний PostgreSQL `agent-team-postgres` у мережі `agent-team` для інтеграційних тестів у пісочниці dev, без Docker-сокета. (#1)
- CHANGELOG і CI-перевірки: запис у CHANGELOG і опис у кожному коміті PR. (#1)
- dev додає рядок у CHANGELOG dopamine-shop і пише коміти з тілом. (#1)

### Changed
- Скіли й інструкції dev описують модульний моноліт dopamine-shop: слайси, власні handler'и, DDD, архітектурні тести. (#1)
- `gh` у пісочниці ставиться з репозиторію Ubuntu замість cli.github.com. (#1)

### Fixed
- Шлюз не стартував: у конфіг додано `gateway.mode: "local"`; README і `setup.sh` запускають `openclaw gateway` замість `gateway start` (той лише для встановленої служби) і описують перший тест без Telegram. (#2)
