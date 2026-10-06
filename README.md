# agent-team

Команда агентів [OpenClaw](https://docs.openclaw.ai), яка бере специфікацію з [dopamine-shop](https://github.com/Roman-Sharabura/dopamine-shop) і віддає Pull Request. Людина робить дві речі: пише спеку і мержить PR.

**Етап 3 (зараз):** `lead` + `ba` + `architect` + `dev` + `qa`. Lead бере issue з міткою `ai-ready` і спершу віддає спеку ba: той перевіряє EARS, сценарії й узгодженість з `openapi.yaml` і повертає PASS або питання (тоді issue отримує `ai-needs-input` з коментарем «Spec validation»). Після PASS architect створює гілку `ai/<issue>-<slug>` з `plan.md` і `tasks.md` (кожен крок з REQ-ID), а для нових архітектурних рішень — чернетку ADR. dev у Docker-пісочниці виконує `tasks.md`, пише код і тести та відкриває draft PR. Потім qa незалежно пише тести за сценаріями спеки й контрактом `openapi.yaml` і веде `qa-report.md`. Після PASS lead робить code review: коментарі до рядків у PR, 🔴 blocking повертає dev, 🟡 nit лишає тобі. Якщо qa чи review знайшли проблему, lead повертає задачу dev, разом не більше двох разів. Чистий PR lead переводить з draft у ready і додає тебе в рев'юери; мержиш ти. План наступних етапів — у [docs/roadmap.md](docs/roadmap.md).

```text
openclaw.json5          конфіг (OPENCLAW_CONFIG_PATH вказує сюди)
workspaces/lead/        SOUL, AGENTS, USER, HEARTBEAT, MEMORY
workspaces/ba/          SOUL, AGENTS, USER, TOOLS, MEMORY
workspaces/architect/   SOUL, AGENTS, USER, TOOLS, MEMORY
workspaces/dev/         SOUL, AGENTS, USER, TOOLS, MEMORY
workspaces/qa/          SOUL, AGENTS, USER, TOOLS, MEMORY
skills/                 спільні скіли; scripts/sync-skills.sh копіює їх у workspaces/<agent>/skills
vendor/dotnet-skills/   скіли .NET від Microsoft (github.com/dotnet/skills), sync-skills.sh теж їх копіює
CHANGELOG.md            історія змін; кожен PR додає рядок (перевіряє CI)
sandbox/Dockerfile      .NET 10 SDK + git + gh + psql для пісочниці
scripts/setup.sh        одноразове налаштування
```

## Що потрібно на машині
- **Windows:** усе запускай у WSL2 (Ubuntu 24.04) з увімкненою WSL-інтеграцією Rancher Desktop. Репо клонуй у `~/src`, не в `/mnt/c`. Git Bash і PowerShell не підходять для `setup.sh` і монтувань пісочниці.
- Node **24.16+** (OpenClaw 2026.9.8 на Node 22 не ставиться).
- Rancher Desktop з рушієм **dockerd (moby)**, щоб працювала команда `docker`.
- API-ключ моделі (у `.env`).
- П'ять токенів GitHub (по одному на агента; від акаунта-бота можна один classic PAT зі scope `repo` в усіх п'яти змінних). Якщо fine-grained PAT, то лише на `Roman-Sharabura/dopamine-shop` (краще від окремого акаунта-бота, тоді PR агентів можна апрувити):
  - Resource owner: організація **Roman-Sharabura**. В організації має бути дозволено fine-grained токени: Settings → Personal access tokens → Settings → «Allow access via fine-grained personal access tokens». Якщо там увімкнено погодження, підтверди всі токени в Settings → Personal access tokens → Pending requests.
  - `GH_TOKEN_LEAD`: Issues, Pull requests — read/write (review і draft → ready), Contents, Commit statuses — read.
  - `GH_TOKEN_BA`: Contents — read.
  - `GH_TOKEN_ARCHITECT`: Contents — read/write.
  - `GH_TOKEN_DEV`: Contents, Pull requests, Issues — read/write.
  - `GH_TOKEN_QA`: Contents, Pull requests — read/write, Issues — read.
- Slack-застосунок у твоєму workspace (див. [Slack](#slack)). Telegram необов'язковий і вимкнений у конфігу.

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
openclaw agents list                                  # lead, ba, architect, dev і qa з потрібними моделями
openclaw agent --agent lead --message "перевір чергу"   # без Slack
openclaw logs --follow                                # що відбувається
```
Або напиши боту в Slack в особисті «перевір чергу». Lead візьме issue [#1](https://github.com/Roman-Sharabura/dopamine-shop/issues/1) (SPEC-001), поставить `ai-in-progress` і передасть його ba. Результат: коментар ba в issue, гілка `ai/001-...` з `plan.md` і `tasks.md` від architect, PR з тестами, `qa-report.md` від qa, review від lead і мітка `ai-review`.

## Slack
Lead слухає особисті повідомлення в Slack через Socket Mode: шлюз сам відкриває з'єднання, тож публічна адреса для WSL не потрібна.
1. [api.slack.com/apps](https://api.slack.com/apps/new) → **Create New App** → **From a manifest** → твій workspace → встав [`slack/app-manifest.json`](slack/app-manifest.json) → **Create**.
2. **Basic Information → App-Level Tokens → Generate Token and Scopes**: scope `connections:write`, збережи. Токен `xapp-...` іде в `SLACK_APP_TOKEN`.
3. **Install App → Install to Workspace**. **Bot User OAuth Token** `xoxb-...` іде в `SLACK_BOT_TOKEN`.
4. У Slack: свій профіль → ⋮ → **Copy member ID** (`U...`) іде в `SLACK_OWNER_ID`. Лише цей користувач може писати боту.
5. `./scripts/setup.sh` (поставить плагін `@openclaw/slack`), потім перезапусти шлюз.
6. Перевір: `openclaw channels list` показує `Slack default: installed, configured, enabled`. Відкрий застосунок у Slack (Apps → Agent Team) і напиши «перевір чергу».

Щоб повернути Telegram, розкоментуй блок `channels.telegram` в `openclaw.json5` і заповни `TELEGRAM_*` у `.env`.

## Адмінка web/admin (етап 5)
1. `git pull && ./scripts/sync-skills.sh`
2. Перебудуй образ пісочниці (у ньому з'явився Node 24): `docker build -t agent-team/dotnet-sandbox:10 sandbox/`
3. Пересоздай пісочниці, щоб вони взяли новий образ: `openclaw sandbox recreate --agent dev`, те саме для `qa` і `architect`.
4. Перевір: `docker run --rm agent-team/dotnet-sandbox:10 node --version` показує `v24.x`. Перезапусти шлюз.
Спека лише для UI може не мати свого `openapi.yaml`: у розділі «Контракт» вона посилається на наявний (зразок — `specs/003-admin-ui-edit-user`).

## Перехід на етап 3 (ba і architect)
1. `git pull && ./scripts/sync-skills.sh`
2. У `.env` додай `BA_MODEL`, `ARCHITECT_MODEL`, `GH_TOKEN_BA` і `GH_TOKEN_ARCHITECT` (див. `.env.example`). Токен бота з `GH_TOKEN_DEV` підходить для обох.
3. Ключ моделі для нових агентів: `./scripts/setup.sh` (кладе ключ в auth-профілі всіх п'яти) або вручну на тимчасовій копії конфігу, як у розділі «Перехід з етапу 1», для `--agent ba` і `--agent architect`.
4. `openclaw config validate`, потім перезапусти шлюз. Пісочниці ba й architect створяться при першому запуску.

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
- `No route-compatible authentication source`: ключ моделі не в auth-профілі агента. Повтори `./scripts/setup.sh` з заповненим `.env` (або `printf "%s\n" "$OPENAI_API_KEY" | openclaw models auth paste-api-key --provider openai --agent lead`, те саме для `ba`, `architect`, `dev` і `qa`).
- `agents/main/agent` замість `agents/lead/agent` у виводі: у цій вкладці не завантажено `.env` і `OPENCLAW_CONFIG_PATH`.
- `Gateway not reachable`: шлюз зупинено; запусти `openclaw gateway --verbose` або використай `openclaw agent --local ...`.
- Агент пише, що скіли недоступні в пісочниці: запусти `./scripts/sync-skills.sh` (після кожного `git pull`, що змінює `skills/`) і перезапусти шлюз.

## Скіли .NET від Microsoft
dev і qa мають частину скілів з [dotnet/skills](https://github.com/dotnet/skills) (той самий marketplace `dotnet-agent-skills`, що й у Claude Code). Це звичайні `SKILL.md`, тому OpenClaw читає їх без змін. Ставимо не плагіни цілком, а окремі скіли: плагінні скіли OpenClaw не видно в пісочниці, а зайві скіли (MAUI, Blazor, WinForms) лише з'їдають промпт.
- Список і коміт: [vendor/dotnet-skills/SOURCE.md](vendor/dotnet-skills/SOURCE.md); хто що отримує: `DOTNET_SKILLS` у `scripts/sync-skills.sh` і `skills` агента в `openclaw.json5`.
- Оновити: `./scripts/update-dotnet-skills.sh` (або з комітом), переглянь diff, закоміть, `./scripts/sync-skills.sh`, перезапусти шлюз.
- Додати скіл: допиши `<плагін>/<скіл>` у `scripts/update-dotnet-skills.sh`, назву в `DOTNET_SKILLS` і в `skills` агента.

## Як дати команді нову задачу
1. Додай `specs/<NNN-slug>/spec.md` і `openapi.yaml` у `main` dopamine-shop зі `status: ready` (для спеки лише на адмінку `openapi.yaml` не потрібен, див. «Адмінка web/admin»).
2. Створи issue з рядком `Spec: specs/<NNN-slug>` в описі і міткою `ai-ready`.
3. Lead підхопить його на heartbeat (кожні 30 хв, 08:00–23:00) або за командою в Slack.

## Мітки (машина станів)
`ai-ready` → `ai-in-progress` (ba → architect → dev → qa → review lead) → `ai-review` → approve і merge людиною. Побічні: `ai-needs-input`, `ai-blocked`.

## Безпека
- Агенти працюють у Docker-пісочниці без доступу до хоста, `~/.ssh` і твоїх git-облікових даних. У них є лише власний PAT.
- Docker-сокет у пісочницю не потрапляє. Замість Testcontainers інтеграційні тести dopamine-shop у пісочниці ходять у спільний контейнер `agent-team-postgres` у мережі `agent-team` (змінна `TEST_POSTGRES_CONNECTION`). Кожен тест-клас створює й видаляє власну БД, тож паралельні прогони не заважають один одному.
- У `main` нічого не потрапляє без тебе: налаштуй branch protection у dopamine-shop (Settings → Branches: PR обов'язковий, CI `build` обов'язковий).
- Текст issue і спек агенти читають як дані, а не як інструкції. Це записано в AGENTS.md кожного агента.
- SOUL.md, AGENTS.md і скіли під git: будь-яку зміну видно в diff.
