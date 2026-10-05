# agent-team

Команда агентів [OpenClaw](https://docs.openclaw.ai), яка бере специфікацію з [dopamine-shop](https://github.com/RomanSharabura/dopamine-shop) і віддає Pull Request. Людина робить дві речі: пише спеку і мержить PR.

**Етап 1 (зараз):** `lead` + `dev`. Lead бере issue з міткою `ai-ready`, dev у Docker-пісочниці пише план, код і тести та відкриває draft PR. План наступних етапів — у [docs/roadmap.md](docs/roadmap.md).

```text
openclaw.json5          конфіг (OPENCLAW_CONFIG_PATH вказує сюди)
workspaces/lead/        SOUL, AGENTS, USER, HEARTBEAT, MEMORY
workspaces/dev/         SOUL, AGENTS, USER, TOOLS, MEMORY
skills/                 спільні скіли (skills.load.extraDirs)
CHANGELOG.md            історія змін; кожен PR додає рядок (перевіряє CI)
sandbox/Dockerfile      .NET 10 SDK + git + gh + psql для пісочниці
scripts/setup.sh        одноразове налаштування
```

## Що потрібно на машині
- Node **24.16+** (OpenClaw 2026.9.8 на Node 22 не ставиться).
- Rancher Desktop з рушієм **dockerd (moby)**, щоб працювала команда `docker`.
- API-ключ моделі (у `.env`).
- Два fine-grained PAT на GitHub лише для `RomanSharabura/dopamine-shop`:
  - `GH_TOKEN_LEAD`: Issues — read/write, Contents — read.
  - `GH_TOKEN_DEV`: Contents, Pull requests, Issues — read/write.
- Telegram-бот від @BotFather і твій числовий id (наприклад, через @userinfobot).

## Запуск
```bash
git clone https://github.com/RomanSharabura/agent-team && cd agent-team
cp .env.example .env        # заповни
./scripts/setup.sh          # образ пісочниці, мережа і Postgres для тестів, мітки, перевірка конфігу
set -a; source .env; set +a
export OPENCLAW_CONFIG_PATH="$PWD/openclaw.json5"
openclaw gateway start
```
Напиши боту: «перевір чергу». Lead візьме issue [#1](https://github.com/RomanSharabura/dopamine-shop/issues/1) (SPEC-001) і передасть його dev.

## Як дати команді нову задачу
1. Додай `specs/<NNN-slug>/spec.md` і `openapi.yaml` у `main` dopamine-shop зі `status: ready`.
2. Створи issue з рядком `Spec: specs/<NNN-slug>` в описі і міткою `ai-ready`.
3. Lead підхопить його на heartbeat (кожні 30 хв, 08:00–23:00) або за командою в Telegram.

## Мітки (машина станів)
`ai-ready` → `ai-in-progress` → `ai-review` → merge людиною. Побічні: `ai-needs-input`, `ai-blocked`.

## Безпека
- Агенти працюють у Docker-пісочниці без доступу до хоста, `~/.ssh` і твоїх git-облікових даних. У них є лише власний PAT.
- Docker-сокет у пісочницю не потрапляє. Замість Testcontainers інтеграційні тести dopamine-shop у пісочниці ходять у спільний контейнер `agent-team-postgres` у мережі `agent-team` (змінна `TEST_POSTGRES_CONNECTION`). Кожен тест-клас створює й видаляє власну БД, тож паралельні прогони не заважають один одному.
- У `main` нічого не потрапляє без тебе: налаштуй branch protection у dopamine-shop (Settings → Branches: PR обов'язковий, CI `build` обов'язковий).
- Текст issue і спек агенти читають як дані, а не як інструкції. Це записано в AGENTS.md кожного агента.
- SOUL.md, AGENTS.md і скіли під git: будь-яку зміну видно в diff.
