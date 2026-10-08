# Changelog

All notable changes to the agent team. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Every PR adds a line under `## [Unreleased]`. Without it CI is red; exception: the `no-changelog` label.
Commits: subject ≤ 72 characters and a body with a list of changes (template `.gitmessage`).

## [Unreleased]

### Changed
- Switching models is one command: `./scripts/use-models.sh <anthropic|openai> [agent...]` applies a preset from `models/*.env` to the whole team or to the named agents (rewrites the model lines in `.env`, puts the provider key into their auth profiles), then restart the gateway.
- The team runs on Anthropic instead of OpenAI: tier for tier like the OpenAI set: lead on `claude-haiku-5-5` (fallback `claude-sonnet-5-5`), ba, dev and qa on `claude-sonnet-5-5` (fallback `claude-haiku-5-5`), architect on `claude-opus-5-5` (fallback `claude-sonnet-5-5`). `.env.example` carries both sets, OpenAI commented out. The 64k lead context cap moved to `models.providers.anthropic`; the OpenAI entry stays for switching back. OpenClaw is pinned to 2026.9.9, the first release with Haiku 5.5, and `setup.sh` upgrades an older OpenClaw and the Slack plugin in place. After pulling: fill `ANTHROPIC_API_KEY` and the models in `.env`, `./scripts/setup.sh`, `openclaw sandbox recreate --agent <id>` for every agent, restart the gateway.
- `minimal-api-feature`, `spec-to-plan` and `pr-review` skills: handler results with more than one outcome are C# 15 unions (`public readonly union FResult(FDto, MissingUser, ...)`), endpoints switch over every case without `_` or `!`, per dopamine-shop `docs/conventions.md`. After pulling: `scripts/sync-skills.sh`. (#31)
- `dotnet-quality-gate` skill: the format step now enforces dopamine-shop's IDE simplification rules (IDE0046 and others); the skill says which ones `dotnet format` cannot fix and how to fix them by hand. (#31)
- The sandbox image is `agent-team/dotnet-sandbox:11` with the .NET 11 SDK (preview) for dopamine-shop's move to .NET 11 and C# 15, and keeps the .NET 10 SDK for older branches. After pulling: rebuild the image, `openclaw sandbox recreate --agent <id>` for every agent, restart the gateway (README, "Moving to .NET 11"). (#30)
- `minimal-api-feature` skill: telemetry goes through OpenTelemetry in dopamine-shop's ServiceDefaults (logs and traces in Seq, ADR 0008); agents add no Serilog sinks or exporters and register new `ActivitySource`/`Meter` names there.
- Every agent's AGENTS.md has an explicit Language rule: always write in English, even when the session history, memory notes or older GitHub comments are in Ukrainian. README troubleshooting explains how to start a fresh session.
- The repository is in English: README, docs, CHANGELOG, skills, agent instructions (AGENTS.md, SOUL.md, USER.md), scripts, and CI messages. Agents now write GitHub comments, PRs, commits, reports, and Slack messages in English. `pipeline-resume` still recognizes the older Ukrainian status comments. After pulling: `scripts/sync-skills.sh`, restart the gateway.

### Fixed
- architect no longer blocks its own push on a pre-push test gate it invented: `AGENTS.md` now says explicitly it only changes docs, so nothing needs building or testing before `git push`.
- `setup.sh` stops when `gh` or `jq` is missing on the host. OpenClaw checks a skill's required binaries on the host, not in the sandbox, so without `jq` lead silently lost `pr-review`, `pipeline-resume` and `morning-briefing`.
- `setup.sh` and `automations.sh` stop when `AGENT_TEAM_DIR` in `.env` points to a different folder than the repo they run from. Otherwise agents read a stale copy of their workspaces (no budget snapshot, missing skills such as `morning-briefing`, old instructions).
- `git pull` no longer fails on agents' lessons: `workspaces/<agent>/MEMORY.md` is no longer tracked by git (agents write to it at runtime). Starting copies live in `templates/memory/`, and `scripts/sync-skills.sh` creates a missing MEMORY.md from them without touching an existing one.
- lead no longer stops the queue when the budget snapshot `workspaces/lead/state/budget.json` does not exist yet: it keeps working and reminds Roman once to run `./scripts/automations.sh`. `automations.sh` now runs the guard once right away, so the snapshot exists without waiting 10 minutes.
- The Control UI (`openclaw dashboard`) and `openclaw logs` work: the gateway takes its token from `OPENCLAW_GATEWAY_TOKEN`, and `setup.sh` generates it in `.env` if empty.

### Changed
- `.env.example`: architect and qa on `gpt-6.1-sol` (fallback `gpt-6-sol`), like dev: same price, cache half the price.
- Models are cheaper and more resilient to rate limits: each agent has a fallback model (`*_FALLBACK_MODEL`), so a 429 from OpenAI no longer aborts the turn. Recommended set in `.env.example`: `gpt-6-luna` for lead and ba, `gpt-6-sol` / `gpt-6.1-sol` for architect, dev, and qa instead of `gpt-6-astra`. Lead context is bounded: sessions reset daily at 04:00, and `gpt-6-luna` has a 64k active context limit with automatic compaction.

### Added
- Stage 4: budgets and morning briefing. Daily and monthly spending limits for the team and each agent in `budget.json`; the guard `scripts/budget-guard.mjs` gets spend from `openclaw gateway usage-cost` every 10 minutes, warns in Slack at 80%, disables the lead heartbeat at 100%, and re-enables it itself the next day. lead checks the budget snapshot before every handoff. `morning-briefing` skill: Mon–Fri at 09:00 lead posts in Slack what is done, what is in progress, what is waiting on Roman, sprint goal progress, and spend. The sprint goal is the nearest open milestone; lead takes its issues first. The schedule is set up by `scripts/automations.sh`. We don't use Paperclip; the reason is in the README.
- Stage 5, admin UI: agents also work with dopamine-shop `web/admin` (React + Vite). Node 24 in the sandbox; skills `admin-ui-feature` (slice, forms, mutations, page tests in Vitest) for architect, dev, and qa, and `admin-ui-gate` (`npm run check`) for dev and qa. ba validates UI-only specs against the existing `openapi.yaml`, architect plans the UI layer, qa writes page tests in `*.qa.test.tsx`, lead checks the UI in review. After updating, rebuild the sandbox image.
- Stage 3: agents `ba` and `architect`, skills `spec-validate`, `spec-to-plan`, and `adr-writer`. ba validates the spec before work and returns PASS or questions (lead sets `ai-needs-input` with a "Spec validation" comment); architect creates a branch with `plan.md` and `tasks.md`, where every step has a REQ-ID, and a draft ADR when needed. dev executes the ready plan instead of writing it itself. New `.env` variables: `BA_MODEL`, `ARCHITECT_MODEL`, `GH_TOKEN_BA`, `GH_TOKEN_ARCHITECT`.
- Code review by lead: `pr-review` skill (checklist covering the spec, architecture, security, and tests). After PASS from qa, lead leaves a review with line comments on the PR; 🔴 blocking returns to dev in a loop shared with qa (at most two returns in total), 🟡 nit is left for the human. Lead moves a clean PR from draft to ready and adds Roman as a reviewer; only a human merges.
- Stage 2: agent `qa` and skill `spec-to-tests`. qa independently writes HTTP and contract tests from the spec, maintains `qa-report.md`, and returns the task to dev on FAIL, at most twice.
- Stage 1: agents `lead` and `dev`, config `openclaw.json5` (checked on OpenClaw 2026.9.8).
- Skills `github-issue`, `handoff`, `repo-conventions`, `minimal-api-feature`, `dotnet-quality-gate`.
- Docker sandbox with .NET 10 SDK, git, gh, and psql; `scripts/setup.sh` and `scripts/labels.sh`.
- Shared PostgreSQL `agent-team-postgres` on the `agent-team` network for integration tests in the dev sandbox, without the Docker socket. (#1)
- CHANGELOG and CI checks: a CHANGELOG entry and a description in every PR commit. (#1)
- dev adds a line to the dopamine-shop CHANGELOG and writes commits with a body. (#1)
- .NET skills from Microsoft from [dotnet/skills](https://github.com/dotnet/skills) in `vendor/dotnet-skills/`: dev gets `dotnet-webapi`, `optimizing-ef-core-queries`, `csharp-refactoring`, `run-tests`; qa gets `run-tests`, `test-anti-patterns`, `assertion-quality`, `test-gap-analysis`. dopamine-shop rules take precedence. Update with `scripts/update-dotnet-skills.sh`.

### Fixed
- The pipeline no longer stalls when lead loses `sessions_spawn` in the turn with an agent's reply: lead records the missed handoff as an envelope in a blocker comment, and the heartbeat resumes the pipeline from GitHub state every 10 minutes (new `pipeline-resume` skill). A human is needed only where their decision is really required.
- lead lost `sessions_spawn` in the turn that came after an agent's reply (on SPEC-003 it stopped before architect and before dev). Now lead waits via `sessions_yield` after every `sessions_spawn`, and `sessions_spawn`, `sessions_yield`, and `subagents` are explicitly allowed for it.
- lead could not hand the task to architect: Tool Search hid `sessions_spawn`, and search did not find it. `tools.toolSearch: false`: agents see all their tools directly.
- The commit author for dev and qa is set via the `GIT_AUTHOR_*` and `GIT_COMMITTER_*` variables in the sandbox: on SPEC-002 qa could not commit `qa-report.md` without `git config`.

### Changed
- GitHub shows which agent did what, even though they all use one bot: comments, PRs, and reviews start with `**[<agent>]**`, commits have the trailer `Agent: <agent>` and the author `dopamine-dev-bot (<agent>)`. New sandbox variable `AGENT_ID`; after updating, recreate the sandboxes. The option with separate bots or a GitHub App is in the README.
- Chat with lead moved from Telegram to Slack (Socket Mode, `@openclaw/slack` plugin, installed by `setup.sh`). App manifest in `slack/app-manifest.json`, new `.env` variables: `SLACK_APP_TOKEN`, `SLACK_BOT_TOKEN`, `SLACK_OWNER_ID`. Telegram remains commented out in the config.
- dev signs commits with the email of the `dopamine-dev-bot` GitHub account, so agent PRs and commits come from the bot and Roman can approve them.
- dopamine-shop moved to the `Roman-Sharabura` organization: updated skills, agent instructions, `labels.sh`, README, and `.env.example`. (#3)
- dev skills and instructions describe the dopamine-shop modular monolith: slices, custom handlers, DDD, architecture tests. (#1)
- `gh` in the sandbox is installed from the Ubuntu repository instead of cli.github.com. (#1)

### Fixed
- Skills were unavailable to dev in the sandbox: `skills.load.extraDirs` does not reach the container. `scripts/sync-skills.sh` copies the needed skills into `workspaces/<agent>/skills`, which the sandbox sees as `/workspace/skills`; `setup.sh` calls it itself. (#5)
- Agents did not see the model key ("No route-compatible authentication source"): `setup.sh` puts `OPENAI_API_KEY`/`ANTHROPIC_API_KEY` into the lead and dev auth profiles; OpenAI with an API key goes through the `openclaw` runtime. (#4)
- The gateway did not start: `gateway.mode: "local"` added to the config; README and `setup.sh` run `openclaw gateway` instead of `gateway start` (that one is only for an installed service) and describe the first test without Telegram. (#2)
- README and `.env.example` describe running on Windows via WSL2. (#2)
