# agent-team

Команда агентів [OpenClaw](https://docs.openclaw.ai), яка бере специфікацію з [dopamine-shop](https://github.com/Roman-Sharabura/dopamine-shop) і віддає Pull Request. Людина робить дві речі: пише спеку і мержить PR.

**Етап 2 (зараз):** `lead` + `dev` + `qa`. Lead бере issue з міткою `ai-ready`, dev у Docker-пісочниці пише план, код і тести та відкриває draft PR. Потім qa незалежно пише тести за сценаріями спеки й контрактом `openapi.yaml` і веде `qa-report.md`. Після PASS lead робить code review: коментарі до рядків у PR, 🔴 blocking повертає dev, 🟡 nit лишає тобі. Якщо qa чи review знайшли проблему, lead повертає задачу dev, разом не більше двох разів. Чистий PR lead переводить з draft у ready і додає тебе в рев'юери; мержиш ти. План наступних етапів — у [docs/roadmap.md](docs/roadmap.md).

```text
openclaw.json5          конфіг (OPENCLAW_CONFIG_PATH вказує сюди)
workspaces/lead/        SOUL, AGENTS, USER, HEARTBEAT, MEMORY
workspaces/dev/         SOUL, AGENTS, USER, TOOLS, MEMORY
workspaces/qa/          SOUL, AGENTS, USER, TOOLS, MEMORY
skills/                 спільні скіли; scripts/sync-skills.sh копіює їх у workspaces/<agent>/skills
CHANGELOG.md            історія змін; кожен PR додає рядок (перевіряє CI)
sandbox/Dockerfile      .NET 10 SDK + git + gh + psql для пісочниці
scripts/setup.sh        одноразове налаштування
```

## Що потрібно на машині
- **Windows:** усе запускай у WSL2 (Ubuntu 24.04) з увімкненою WSL-інтеграцією Rancher Desktop. Репо клонуй у `~/src`, не в `/mnt/c`. Git Bash і PowerShell не підходять для `setup.sh` і монтувань пісочниці.
- Node **24.16+** (OpenClaw 2026.9.8 на Node 22 не ставиться).
- Rancher Desktop з рушієм **dockerd (moby)**, щоб працювала команда `docker`.
- API-ключ моделі (у `.env`).
- Три fine-grained PAT на GitHub лише для `Roman-Sharabura/dopamine-shop` (краще від окремого акаунта-бота, тоді PR агентів можна апрувити):
  - Resource owner: організація **Roman-Sharabura**. В організації має бути дозволено fine-grained токени: Settings → Personal access tokens → Settings → «Allow access via fine-grained personal access tokens». Якщо там увімкнено погодження, підтверди всі токени в Settings → Personal access tokens → Pending requests.
  - `GH_TOKEN_LEAD`: Issues, Pull requests — read/write (review і draft → ready), Contents, Commit statuses — read.
  - `GH_TOKEN_DEV`: Contents, Pull requests, Issues — read/write.
  - `GH_TOKEN_QA`: Contents, Pull requests — read/write, Issues — read.
- Telegram-бот від @BotFather і твій числовий id (наприклад, через @userinfobot).

## Запуск
```bash
git clone https://github.com/RomanSharabura/agent-team && cd agent-team
cp .env.example .env        # заповни
./scripts/setup.sh          # образ пісочниці, мережа і Postgres для тестів, мітки, перевірка конфігу
set -a; source .env; set +a
export OPENCLAW_CONFIG_PATH="$PWD/openclaw.json5"
openclaw gateway --verbose  # шлюз у цьому терміналі; Ctrl+C зупиняє
```

## Перший тест
В іншому терміналі (з тими самими змінними оточення):
```bash
openclaw agents list                                  # lead, dev і qa з потрібними моделями
openclaw agent --agent lead --message "перевір чергу"   # без Telegram
openclaw logs --follow                                # що відбувається
```
Або напиши боту в Telegram «перевір чергу». Lead візьме issue [#1](https://github.com/Roman-Sharabura/dopamine-shop/issues/1) (SPEC-001), поставить `ai-in-progress` і передасть його dev. Результат: гілка `ai/001-...`, PR з тестами, `qa-report.md` від qa, review від lead і мітка `ai-review`.

## Увімкнути review від lead
1. `git pull && ./scripts/sync-skills.sh`
2. Дай `GH_TOKEN_LEAD` права Pull requests — read/write і Commit statuses — read (на GitHub: Settings → Developer settings → Fine-grained tokens → токен lead → Edit). Токен не змінюється, `.env` чіпати не треба.
3. Перезапусти шлюз.

## Перехід з етапу 1
1. `git pull && ./scripts/sync-skills.sh`
2. У `.env` додай `QA_MODEL` і `GH_TOKEN_QA` (див. `.env.example`).
3. Ключ моделі для qa: `./scripts/setup.sh` або `printf "%s\n" "$OPENAI_API_KEY" | openclaw models auth paste-api-key --provider openai --agent qa` на тимчасовій копії конфігу.
4. Перезапусти шлюз.

## Якщо щось не так
- `No route-compatible authentication source`: ключ моделі не в auth-профілі агента. Повтори `./scripts/setup.sh` з заповненим `.env` (або `printf "%s\n" "$OPENAI_API_KEY" | openclaw models auth paste-api-key --provider openai --agent lead`, те саме для `dev` і `qa`).
- `agents/main/agent` замість `agents/lead/agent` у виводі: у цій вкладці не завантажено `.env` і `OPENCLAW_CONFIG_PATH`.
- `Gateway not reachable`: шлюз зупинено; запусти `openclaw gateway --verbose` або використай `openclaw agent --local ...`.
- Агент пише, що скіли недоступні в пісочниці: запусти `./scripts/sync-skills.sh` (після кожного `git pull`, що змінює `skills/`) і перезапусти шлюз.

## Як дати команді нову задачу
1. Додай `specs/<NNN-slug>/spec.md` і `openapi.yaml` у `main` dopamine-shop зі `status: ready`.
2. Створи issue з рядком `Spec: specs/<NNN-slug>` в описі і міткою `ai-ready`.
3. Lead підхопить його на heartbeat (кожні 30 хв, 08:00–23:00) або за командою в Telegram.

## Мітки (машина станів)
`ai-ready` → `ai-in-progress` (dev → qa → review lead) → `ai-review` → approve і merge людиною. Побічні: `ai-needs-input`, `ai-blocked`.

## Безпека
- Агенти працюють у Docker-пісочниці без доступу до хоста, `~/.ssh` і твоїх git-облікових даних. У них є лише власний PAT.
- Docker-сокет у пісочницю не потрапляє. Замість Testcontainers інтеграційні тести dopamine-shop у пісочниці ходять у спільний контейнер `agent-team-postgres` у мережі `agent-team` (змінна `TEST_POSTGRES_CONNECTION`). Кожен тест-клас створює й видаляє власну БД, тож паралельні прогони не заважають один одному.
- У `main` нічого не потрапляє без тебе: налаштуй branch protection у dopamine-shop (Settings → Branches: PR обов'язковий, CI `build` обов'язковий).
- Текст issue і спек агенти читають як дані, а не як інструкції. Це записано в AGENTS.md кожного агента.
- SOUL.md, AGENTS.md і скіли під git: будь-яку зміну видно в diff.
