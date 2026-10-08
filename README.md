# agent-team

An [OpenClaw](https://docs.openclaw.ai) agent team that takes a spec from [dopamine-shop](https://github.com/Roman-Sharabura/dopamine-shop) and delivers a Pull Request. The human does two things: writes the spec and merges the PR.

**Stage 3 (current):** `lead` + `ba` + `architect` + `dev` + `qa`. Lead takes an issue labeled `ai-ready` and first hands the spec to ba: ba checks EARS, scenarios, and consistency with `openapi.yaml` and returns PASS or questions (then the issue gets `ai-needs-input` with a "Spec validation" comment). After PASS, architect creates branch `ai/<issue>-<slug>` with `plan.md` and `tasks.md` (each step with a REQ-ID), plus a draft ADR for new architectural decisions. dev, in the Docker sandbox, executes `tasks.md`, writes code and tests, and opens a draft PR. Then qa independently writes tests from the spec scenarios and the `openapi.yaml` contract and maintains `qa-report.md`. After PASS, lead does a code review: line comments on the PR, 🔴 blocking goes back to dev, 🟡 nit is left for you. If qa or review finds a problem, lead returns the task to dev, at most twice in total. Lead moves a clean PR from draft to ready and adds you as a reviewer; you merge. From stage 4 the team takes tasks from the queue on its own, stays within budget, and reports in Slack every morning (see [Stage 4](#stage-4-queue-without-manual-start-budgets-briefing)). The plan for the next stages is in [docs/roadmap.md](docs/roadmap.md).

```text
openclaw.json5          config (OPENCLAW_CONFIG_PATH points here)
workspaces/lead/        SOUL, AGENTS, USER, HEARTBEAT, MEMORY
workspaces/ba/          SOUL, AGENTS, USER, TOOLS, MEMORY
workspaces/architect/   SOUL, AGENTS, USER, TOOLS, MEMORY
workspaces/dev/         SOUL, AGENTS, USER, TOOLS, MEMORY
workspaces/qa/          SOUL, AGENTS, USER, TOOLS, MEMORY
skills/                 shared skills; scripts/sync-skills.sh copies them into workspaces/<agent>/skills
templates/memory/       starting MEMORY.md per agent; sync-skills.sh copies it if missing (MEMORY.md itself is not in git)
vendor/dotnet-skills/   .NET skills from Microsoft (github.com/dotnet/skills), sync-skills.sh copies them too
CHANGELOG.md            change history; every PR adds a line (checked by CI)
sandbox/Dockerfile      .NET 10 SDK + git + gh + psql for the sandbox
budget.json             team and agent spending limits (stage 4)
scripts/setup.sh        one-time setup
scripts/automations.sh  schedule: budget guard and morning briefing (stage 4)
scripts/budget-guard.mjs spend tracking and team pause per budget.json
```

## What you need on the machine
- **Windows:** run everything in WSL2 (Ubuntu 24.04) with Rancher Desktop WSL integration enabled. Clone the repo into `~/src`, not `/mnt/c`. Git Bash and PowerShell do not work for `setup.sh` and the sandbox mounts.
- Node **24.16+** (OpenClaw 2026.9.9 does not install on Node 22).
- Rancher Desktop with the **dockerd (moby)** engine, so the `docker` command works.
- `gh` and `jq` on the host (`sudo apt install gh jq`): OpenClaw checks the binaries a skill requires on the host, not in the sandbox, so without them lead does not see `pr-review`, `pipeline-resume` and `morning-briefing`.
- A model API key (in `.env`).
- Five GitHub tokens (one per agent; from a bot account you can use one classic PAT with scope `repo` in all five variables). If fine-grained PATs, then only for `Roman-Sharabura/dopamine-shop` (preferably from a separate bot account, so agent PRs can be approved):
  - Resource owner: the **Roman-Sharabura** organization. The organization must allow fine-grained tokens: Settings → Personal access tokens → Settings → "Allow access via fine-grained personal access tokens". If approval is enabled there, approve all tokens in Settings → Personal access tokens → Pending requests.
  - `GH_TOKEN_LEAD`: Issues, Pull requests: read/write (review and draft → ready), Contents, Commit statuses: read.
  - `GH_TOKEN_BA`: Contents: read.
  - `GH_TOKEN_ARCHITECT`: Contents: read/write.
  - `GH_TOKEN_DEV`: Contents, Pull requests, Issues: read/write.
  - `GH_TOKEN_QA`: Contents, Pull requests: read/write, Issues: read.
- A Slack app in your workspace (see [Slack](#slack)). Telegram is optional and disabled in the config.

## Running
```bash
git clone https://github.com/RomanSharabura/agent-team && cd agent-team
cp .env.example .env        # fill in
./scripts/setup.sh          # sandbox image, network and Postgres for tests, labels, config check
set -a; source .env; set +a
export OPENCLAW_CONFIG_PATH="$PWD/openclaw.json5"
openclaw gateway --verbose  # gateway in this terminal; Ctrl+C stops it
```

## First test
In another terminal (with the same environment variables):
```bash
openclaw agents list                                  # lead, ba, architect, dev and qa with the right models
openclaw agent --agent lead --message "check the queue"   # without Slack
openclaw logs --follow                                # what is happening
```
Or DM the bot in Slack "check the queue". Lead will take issue [#1](https://github.com/Roman-Sharabura/dopamine-shop/issues/1) (SPEC-001), set `ai-in-progress`, and hand it to ba. Result: a ba comment on the issue, branch `ai/001-...` with `plan.md` and `tasks.md` from architect, a PR with tests, `qa-report.md` from qa, a review from lead, and the `ai-review` label.

## Slack
Lead listens to Slack direct messages via Socket Mode: the gateway opens the connection itself, so no public address is needed for WSL.
1. [api.slack.com/apps](https://api.slack.com/apps/new) → **Create New App** → **From a manifest** → your workspace → paste [`slack/app-manifest.json`](slack/app-manifest.json) → **Create**.
2. **Basic Information → App-Level Tokens → Generate Token and Scopes**: scope `connections:write`, save. The `xapp-...` token goes into `SLACK_APP_TOKEN`.
3. **Install App → Install to Workspace**. The **Bot User OAuth Token** `xoxb-...` goes into `SLACK_BOT_TOKEN`.
4. In Slack: your profile → ⋮ → **Copy member ID** (`U...`) goes into `SLACK_OWNER_ID`. Only this user can message the bot.
5. `./scripts/setup.sh` (installs the `@openclaw/slack` plugin), then restart the gateway.
6. Check: `openclaw channels list` shows `Slack default: installed, configured, enabled`. Open the app in Slack (Apps → Agent Team) and write "check the queue".

To bring Telegram back, uncomment the `channels.telegram` block in `openclaw.json5` and fill in `TELEGRAM_*` in `.env`.

## Which agent did what
All agents use GitHub as a single bot, `dopamine-dev-bot`: the `GH_TOKEN_<AGENT>` tokens differ, but they are PATs of the same account, so GitHub shows one name. The agent is identified by its signature:
- a comment, PR body, or review starts with `**[lead]**`, `**[dev]**`, `**[qa]**`… (the `AGENT_ID` variable in the sandbox, `github-issue` skill);
- a commit has the trailer `Agent: dev` (`git commit --trailer`, `git-commit` skill), and the author is `dopamine-dev-bot (dev)`; the bot email is the same, so commits stay linked to it;
- GitHub shows label changes only as from the bot, so lead changes a label only together with a signed comment.

To enable: `git pull && ./scripts/sync-skills.sh`, restart the gateway, then `openclaw sandbox recreate --agent <id>` for all five (the sandbox picks up the new `AGENT_ID` and `GIT_AUTHOR_NAME` variables only on creation).

A truly separate identity for each agent (its own avatar in the issue timeline, in labels, and in "Approve") requires a separate GitHub login:
- **five bot accounts** (`dopamine-lead-bot`, `dopamine-dev-bot`…): each with its own email, an organization invite, and a classic `repo` PAT in its own `GH_TOKEN_<AGENT>` variable; `GIT_AUTHOR_EMAIL` set to the matching bot's email. Nothing in the code needs changing except the author emails. Downside: five accounts and tokens, and under GitHub rules machine accounts must be managed by a human;
- **a GitHub App per agent** (`dopamine-lead[bot]`…): short-lived tokens instead of PATs and precise permissions on a single repository. Needs a script that generates an installation token from the App private key before the agent runs (the token lives an hour), so this is a separate stage.

## Models
The team runs on one provider at a time, Anthropic by default; both sets are in [`.env.example`](.env.example) and in the presets in [`models/`](models). The Anthropic set mirrors the OpenAI one tier by tier:

| Agent | Anthropic | OpenAI | Anthropic $/1M in/out |
|---|---|---|---|
| lead | `claude-haiku-5-5` (fb `claude-sonnet-5-5`) | `gpt-6-luna` (fb `gpt-5.6-luna`) | 0.10 / 0.50 |
| ba, dev, qa | `claude-sonnet-5-5` (fb `claude-haiku-5-5`) | `gpt-6.1-sol` (fb `gpt-6-sol`; ba `gpt-6.1-sol`) | 2 / 10 |
| architect | `claude-opus-5-5` (fb `claude-sonnet-5-5`) | `gpt-6-astra` (fb `gpt-6.1-sol`) | 4 / 20 |

Lead mostly orchestrates and reviews against a checklist; if its reviews get shallow, move `LEAD_MODEL` to Sonnet first. The fallback only fires on a rate limit or an outage, so a cheap one is fine.

Notes:
- **OpenClaw 2026.9.9 or newer is required.** 2026.9.8 doesn't know Claude Haiku 5.5 (no price, no thinking settings).
- **Fallback model.** Each agent has `model: { primary, fallbacks }` (the `*_FALLBACK_MODEL` variables). Anthropic counts rate limits separately per model class, so on a 429 OpenClaw, after a short retry, switches to the fallback instead of aborting the turn.
- **Lead context.** The lead main session (Slack and all handoffs) used to grow without bound: every tool call sent it in full, hence ~59k tokens per request (on OpenAI it hit 200k TPM). Now sessions restart daily at 04:00 (`session.reset`), and the lead model has a 64k active context limit (`models.providers.anthropic.models`), after which OpenClaw compacts the history. That also keeps Haiku 5.5 under 100k-token prompts, where its price is 5x lower. If you change `LEAD_MODEL`, change the `id` in that entry too.
- **Prompt caching.** OpenClaw turns on Anthropic's 5-minute prompt cache by itself for the direct API; cache reads cost a tenth of input.
- **Switching models.** Presets live in [`models/`](models): `anthropic.env` (the default) and `openai.env` (the OpenAI column above). Switch with one command, for the whole team or for some agents:
  ```bash
  ./scripts/use-models.sh openai            # whole team to OpenAI
  ./scripts/use-models.sh anthropic dev qa  # only dev and qa back to Claude
  ```
  It rewrites the `*_MODEL` / `*_FALLBACK_MODEL` lines in `.env` and puts the matching key from `.env` (`ANTHROPIC_API_KEY` / `OPENAI_API_KEY`) into those agents' auth profiles, so that key must be filled in first. Then restart the gateway after `set -a; source .env; set +a`: the config reads the model variables only at gateway start. No sandbox recreate is needed. Your own mix: copy a preset to `models/<name>.env` and edit it, or change one line in `.env` by hand (the key for that provider must already be in the agent's profile: `./scripts/setup.sh` puts every filled key in). For a single chat, `/model <provider/model>` in the chat with the agent switches only that session.
- **Lead context cap per model.** The 64k cap is set per model id in `models.providers.<provider>.models` (Haiku 5.5 and gpt-6-luna are there). Moving lead to a model not listed there drops the cap: add an entry with its `id`.
- Cost per agent: `node scripts/budget-guard.mjs --report`. Your rate limits per model are in the Anthropic Console (Settings → Limits); they grow with the usage tier.

## Stage 4: queue without manual start, budgets, briefing
The team takes tasks from the queue on its own: the lead heartbeat every 10 minutes (08:00–23:00) finishes what was started (`pipeline-resume`) and takes the next `ai-ready`. On top of that, two jobs in the OpenClaw scheduler:
- **Budget guard** (every 10 min, no model call): `scripts/budget-guard.mjs` gets each agent's spend per provider from the gateway (`sessions.usage`, by day and model) and its tokens from `openclaw gateway usage-cost`, writes a snapshot to `workspaces/lead/state/budget.json`, and compares it with the limits in [`budget.json`](budget.json). Dollar limits are **per provider** (`providers.anthropic`, `providers.openai`: team daily/monthly and per agent daily), because each provider is a separate account with its own money: a provider's limit counts only that provider's calls, and only while some agent runs on it (the `*_MODEL` lines in `.env`). So when the Anthropic month is used up, `./scripts/use-models.sh openai` and a gateway restart get the team going again, and the other way round. The top-level `team`/`agents` token limits are provider-independent, a fallback for models OpenClaw has no price for. Over 80%: a warning in Slack. Over 100%: `openclaw system heartbeat disable` and a message: the agent finishes its current step, and lead stops before the next handoff with `ai-blocked` and an envelope in a comment. The next day (UTC), when spend is within limits, the guard re-enables the heartbeat itself, and the pipeline continues from the same step.
- **Morning briefing** (Mon–Fri at 09:00 Kyiv time): lead, using the `morning-briefing` skill, posts in Slack what is done, what is in progress, what is waiting on you, sprint goal progress, and spend (yesterday, month to date, ≈ $ per PR).

**Sprint goal**: the open milestone in dopamine-shop with the nearest `due_on` (the milestone description is the goal itself). Lead takes `ai-ready` from that milestone first, and the briefing shows its progress. The milestone is optional: without one the queue goes oldest first.

To enable:
1. `git pull && ./scripts/sync-skills.sh`, restart the gateway.
2. Check the limits in `budget.json`: set each provider's `monthly.usd` to what that account may spend (dollars are OpenClaw's estimate from model prices; `tokens` is a fallback if OpenClaw doesn't know the model's prices). Per-agent daily caps follow each preset's models: architect gets more on Opus (Anthropic) and on gpt-6-astra (OpenAI). Changes to `budget.json` take effect from the next guard run, no restart needed.
3. With the gateway running: `./scripts/automations.sh`. Re-running updates the same jobs. For a different briefing time, set `BRIEFING_CRON` and `BRIEFING_TZ` in `.env`.
4. Check: `node scripts/budget-guard.mjs --report` (spend table, changes nothing), `openclaw automations list --agent lead`, briefing right now: `openclaw automations run <id Morning briefing>`.
5. A safeguard beyond the guard: a monthly spend limit in each provider's console (Anthropic: Settings → Limits; OpenAI: project limits). The guard sees spend with up to a 10-minute delay and does not interrupt a step already running.

Spend is also visible in the Control UI (Usage) and via `openclaw gateway usage-cost --all-agents`, `openclaw status --usage`.

Why not Paperclip: Paperclip connects to OpenClaw 2026.9.8 (the `openclaw_gateway` adapter, protocol v4) and tracks spend only for runs it starts itself. Here the entire ba → architect → dev → qa chain is launched by lead inside OpenClaw (`sessions_spawn` and heartbeat), so Paperclip budgets would not stop dev or qa, and tracking would require moving orchestration from OpenClaw to Paperclip and running yet another server with a database. OpenClaw's native tracking sees every agent, including subagents.

## Admin UI web/admin (stage 5)
1. `git pull && ./scripts/sync-skills.sh`
2. Rebuild the sandbox image (it now includes Node 24): `docker build -t agent-team/dotnet-sandbox:11 sandbox/`
3. Recreate the sandboxes so they pick up the new image: `openclaw sandbox recreate --agent dev`, and the same for `qa` and `architect`.
4. Check: `docker run --rm agent-team/dotnet-sandbox:11 node --version` shows `v24.x`. Restart the gateway.
A UI-only spec may have no `openapi.yaml` of its own: in its "Contract" section it references an existing one (example: `specs/003-admin-ui-edit-user`).

## Moving to .NET 11 (preview)
dopamine-shop targets .NET 11 RC1 and C# 15 (its ADR 0012), so the sandbox image needs the .NET 11 SDK. The image keeps the .NET 10 SDK too, for branches cut before the move.
1. `git pull`
2. Rebuild the image: `docker build --pull -t agent-team/dotnet-sandbox:11 sandbox/` (`--pull` picks up the newest `sdk:11.0`, which follows each RC and then GA).
3. Check: `docker run --rm agent-team/dotnet-sandbox:11 dotnet --list-sdks` shows `11.0.100-rc.1...` (or later) and `10.0.x`.
4. Recreate the sandboxes so they use the new tag: `openclaw sandbox recreate --agent <id>` for `lead`, `ba`, `architect`, `dev` and `qa`, then restart the gateway.

## Moving to stage 3 (ba and architect)
1. `git pull && ./scripts/sync-skills.sh`
2. In `.env`, add `BA_MODEL`, `ARCHITECT_MODEL`, `GH_TOKEN_BA`, and `GH_TOKEN_ARCHITECT` (see `.env.example`). The bot token from `GH_TOKEN_DEV` works for both.
3. Model key for the new agents: `./scripts/setup.sh` (puts the key into the auth profiles of all five) or manually on a temporary copy of the config, as in "Moving from stage 1", for `--agent ba` and `--agent architect`.
4. `openclaw config validate`, then restart the gateway. The ba and architect sandboxes are created on first run.

## Enabling review by lead
1. `git pull && ./scripts/sync-skills.sh`
2. Give `GH_TOKEN_LEAD` the permissions Pull requests: read/write and Commit statuses: read (on GitHub: Settings → Developer settings → Fine-grained tokens → lead token → Edit). The token does not change, no need to touch `.env`.
3. Restart the gateway.

## Moving from stage 1
1. `git pull && ./scripts/sync-skills.sh`
2. In `.env`, add `QA_MODEL` and `GH_TOKEN_QA` (see `.env.example`).
3. Model key for qa: `./scripts/setup.sh` or `printf "%s\n" "$ANTHROPIC_API_KEY" | openclaw models auth paste-api-key --provider anthropic --agent qa` on a temporary copy of the config.
4. Restart the gateway.

## Troubleshooting
- The Control UI asks for a "Gateway secret", or `openclaw logs` prints `requires credentials`: `.env` has no `OPENCLAW_GATEWAY_TOKEN`. Run `./scripts/setup.sh` (generates the token), `set -a; source .env; set +a`, and restart the gateway. Then `openclaw dashboard --no-open` gives a link with a one-time login. Do not run `openclaw doctor` on `openclaw.json5`: it rewrites the file.
- `No route-compatible authentication source`: the model key is not in the agent's auth profile. Rerun `./scripts/setup.sh` with a filled-in `.env` (or `printf "%s\n" "$ANTHROPIC_API_KEY" | openclaw models auth paste-api-key --provider anthropic --agent lead`, and the same for `ba`, `architect`, `dev`, and `qa`).
- `agents/main/agent` instead of `agents/lead/agent` in the output: `.env` and `OPENCLAW_CONFIG_PATH` are not loaded in this tab.
- `Gateway not reachable`: the gateway is stopped; run `openclaw gateway --verbose` or use `openclaw agent --local ...`.
- An agent still answers in Ukrainian: `git pull`, restart the gateway, then start a fresh session (`/new` in the chat with the agent, or wait for the daily 04:00 reset). An old session keeps its Ukrainian history, and the model tends to continue in that language. Notes agents wrote earlier in `workspaces/<agent>/memory/` may also be Ukrainian; the Language rule in AGENTS.md overrides them, or delete them.
- An agent says skills are unavailable in the sandbox: run `./scripts/sync-skills.sh` (after every `git pull` that changes `skills/`) and restart the gateway.

## .NET skills from Microsoft
dev and qa get some of the skills from [dotnet/skills](https://github.com/dotnet/skills) (the same `dotnet-agent-skills` marketplace as in Claude Code). They are plain `SKILL.md` files, so OpenClaw reads them unchanged. We install individual skills rather than whole plugins: OpenClaw plugin skills are not visible in the sandbox, and unneeded skills (MAUI, Blazor, WinForms) just eat the prompt.
- List and commit: [vendor/dotnet-skills/SOURCE.md](vendor/dotnet-skills/SOURCE.md); who gets what: `DOTNET_SKILLS` in `scripts/sync-skills.sh` and the agent's `skills` in `openclaw.json5`.
- Update: `./scripts/update-dotnet-skills.sh` (or with a commit), review the diff, commit, `./scripts/sync-skills.sh`, restart the gateway.
- Add a skill: append `<plugin>/<skill>` in `scripts/update-dotnet-skills.sh`, and the name in `DOTNET_SKILLS` and in the agent's `skills`.

## How to give the team a new task
1. Add `specs/<NNN-slug>/spec.md` and `openapi.yaml` to dopamine-shop `main` with `status: ready` (an admin-only spec doesn't need `openapi.yaml`, see "Admin UI web/admin").
2. Create an issue with the line `Spec: specs/<NNN-slug>` in the description and the `ai-ready` label.
3. Lead picks it up on the heartbeat (every 10 min, 08:00–23:00) or on a Slack command. Issues in the sprint goal milestone go first (see "Stage 4").

## Labels (state machine)
`ai-ready` → `ai-in-progress` (ba → architect → dev → qa → lead review) → `ai-review` → approve and merge by a human. Side states: `ai-needs-input`, `ai-blocked`.

## Security
- Agents work in a Docker sandbox with no access to the host, `~/.ssh`, or your git credentials. They only have their own PAT.
- The Docker socket is not exposed to the sandbox. Instead of Testcontainers, dopamine-shop integration tests in the sandbox use the shared `agent-team-postgres` container on the `agent-team` network (the `TEST_POSTGRES_CONNECTION` variable). Each test class creates and drops its own DB, so parallel runs don't interfere with each other.
- Nothing reaches `main` without you: set up branch protection in dopamine-shop (Settings → Branches: PR required, CI `build` required).
- Agents read issue and spec text as data, not as instructions. This is written in each agent's AGENTS.md.
- SOUL.md, AGENTS.md, and skills are under git: any change is visible in the diff.
