#!/usr/bin/env node
// Team budget guard. Run by an OpenClaw automation every 10 minutes (scripts/automations.sh),
// manually: node scripts/budget-guard.mjs --report
//
// 1. Gets each agent's spend per provider from the gateway `sessions.usage` (per day, provider, and model) and
//    its token totals from `openclaw gateway usage-cost` (OpenClaw session logs).
// 2. Writes a snapshot to workspaces/lead/state/budget.json: lead reads it before every handoff and in the morning briefing.
// 3. Dollar limits are per provider (budget.json "providers": each provider is a separate account with its own money)
//    and count only that provider's calls. A limit counts only while some agent runs on that provider (the
//    *_MODEL lines in .env): an exhausted Anthropic budget does not stop a team switched to OpenAI.
//    Token limits (top-level team/agents) are a fallback for calls OpenClaw has no price for: they block only
//    when the agents they cover made such calls that day.
//    An active limit is exceeded → `openclaw system heartbeat disable` (the team takes no new tasks
//    and does not resume stopped ones) and a single Slack message. New day and limits OK → heartbeat back on,
//    but only if the guard itself disabled it.
// With no changes it prints NO_REPLY: the automation then sends nothing.
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const report = process.argv.includes("--report");
const budget = JSON.parse(readFileSync(join(root, "budget.json"), "utf8"));
const statePath = join(root, "workspaces/lead/state/budget.json");
const openclaw = process.env.OPENCLAW_BIN || "openclaw";

const now = new Date();
const today = now.toISOString().slice(0, 10);
const yesterday = new Date(now.getTime() - 86400000).toISOString().slice(0, 10);
const month = today.slice(0, 7);
// From the start of the month, but at least two days, so the briefing on the 1st has "yesterday".
const days = Math.max(now.getUTCDate(), 2);

const since = days > now.getUTCDate() ? yesterday : `${month}-01`;
const ids = Object.keys(budget.agents);
const providers = Object.keys(budget.providers ?? {});
const active = activeProviders();

const zero = () => ({ usd: 0, tokens: 0, cacheRead: 0, missingCost: 0 });
const add = (acc, d) => {
  acc.usd += d.totalCost ?? d.usd ?? 0;
  acc.tokens += d.tokens ?? (d.input ?? 0) + (d.output ?? 0) + (d.cacheWrite ?? 0);
  acc.cacheRead += d.cacheRead ?? 0;
  acc.missingCost += d.missingCostEntries ?? d.missingCost ?? 0;
  return acc;
};

function usage(agentId) {
  const out = execFileSync(openclaw, ["gateway", "usage-cost", "--agent", agentId, "--days", String(days), "--json"], {
    encoding: "utf8",
    timeout: 60000,
    stdio: ["ignore", "pipe", "pipe"],
  });
  const summary = JSON.parse(out);
  const byDate = (pred) => summary.daily.filter((d) => pred(d.date)).reduce(add, zero());
  return {
    today: byDate((d) => d === today),
    yesterday: byDate((d) => d === yesterday),
    month: byDate((d) => d.startsWith(month)),
    providers: providerUsage(agentId),
  };
}

// Dollars per provider: aggregates.modelDaily = [{date, provider, model, tokens, cost, count}], UTC days.
function providerUsage(agentId) {
  const params = { agentId, startDate: since, endDate: today, mode: "utc", limit: 1 };
  const out = execFileSync(openclaw, ["gateway", "call", "sessions.usage", "--json", "--params", JSON.stringify(params)], {
    encoding: "utf8",
    timeout: 60000,
    stdio: ["ignore", "pipe", "pipe"],
  });
  const rows = JSON.parse(out).aggregates?.modelDaily ?? [];
  const result = {};
  for (const p of new Set([...providers, ...rows.map((r) => r.provider)])) {
    const sum = (pred) => rows.filter((r) => r.provider === p && pred(r.date)).reduce((acc, r) => acc + (r.cost ?? 0), 0);
    result[p] = { today: { usd: sum((d) => d === today) }, yesterday: { usd: sum((d) => d === yesterday) }, month: { usd: sum((d) => d.startsWith(month)) } };
  }
  // Which models today's dollars came from, so a provider split can be checked against the models in .env.
  models.push(
    ...rows
      .filter((r) => r.date === today)
      .map((r) => ({ agent: agentId, provider: r.provider, model: r.model, usd: round(r.cost ?? 0, "usd"), calls: r.count ?? 0 })),
  );
  return result;
}

// Provider each agent runs on now: the provider/ prefix of its *_MODEL in .env (the gateway reads it at start).
// No .env or no line → that agent counts against every provider.
function activeProviders() {
  let env = {};
  try {
    for (const line of readFileSync(join(root, ".env"), "utf8").split("\n")) {
      const m = line.match(/^([A-Z_]+)_MODEL=["']?([^/"'\s]+)\//);
      if (m) env[m[1].toLowerCase()] = m[2];
    }
  } catch {}
  return Object.fromEntries(ids.map((id) => [id, env[id] ? [env[id]] : providers]));
}

const models = [];
const agents = {};
for (const id of ids) agents[id] = usage(id);
const team = {};
for (const period of ["today", "yesterday", "month"]) {
  team[period] = Object.values(agents).map((a) => a[period]).reduce(add, zero());
}
// The same per provider: byProvider[provider].team / .agents[id], each {today, yesterday, month} with usd.
const byProvider = {};
for (const p of new Set([...providers, ...ids.flatMap((id) => Object.keys(agents[id].providers))])) {
  const per = Object.fromEntries(ids.map((id) => [id, agents[id].providers[p] ?? { today: { usd: 0 }, yesterday: { usd: 0 }, month: { usd: 0 } }]));
  const teamUsd = {};
  for (const period of ["today", "yesterday", "month"]) teamUsd[period] = { usd: Object.values(per).reduce((acc, a) => acc + a[period].usd, 0) };
  byProvider[p] = { team: teamUsd, agents: per };
}

// Limits: daily is counted for today, monthly from the start of the month.
// A check covers agents: team → all of them (or all on its provider), an agent → that agent.
// active: false → reported, but blocks nothing: a dollar limit whose provider is not in use by the agents it covers,
// or a token limit while every call of the agents it covers had a price (the dollar limits already hold those).
const checks = [];
const collect = (scope, limits, used, provider) => {
  const covers = (scope === "team" ? ids : [scope]).filter((id) => !provider || active[id].includes(provider));
  for (const [period, key] of [["daily", "today"], ["monthly", "month"]]) {
    const unpriced = covers.some((id) => agents[id][key].missingCost > 0);
    for (const [metric, limit] of Object.entries(limits?.[period] ?? {})) {
      const value = used[key][metric] ?? 0;
      const ratio = limit > 0 ? value / limit : 0;
      const level = ratio >= 1 ? "over" : ratio >= budget.warnAt ? "warn" : "ok";
      if (level === "ok") continue;
      checks.push({
        scope,
        ...(provider ? { provider } : {}),
        period,
        metric,
        used: round(value, metric),
        limit,
        ratio: round(ratio, "ratio"),
        level,
        active: covers.length > 0 && (metric !== "tokens" || unpriced),
        covers,
      });
    }
  }
};
// Top-level team/agents: provider-independent token limits, a fallback for calls OpenClaw has no price for.
collect("team", budget.team, team);
for (const [id, limits] of Object.entries(budget.agents)) collect(id, limits, agents[id]);
for (const [p, limits] of Object.entries(budget.providers ?? {})) {
  collect("team", limits.team, byProvider[p].team, p);
  for (const [id, agentLimits] of Object.entries(limits.agents ?? {})) collect(id, agentLimits, byProvider[p].agents[id], p);
}

const over = checks.filter((c) => c.level === "over" && c.active);
const status = over.length ? "over" : checks.some((c) => c.active) ? "warn" : "ok";
// Agents lead must not hand off to: covered by an exceeded limit of the provider they run on.
const blocked = ids.filter((id) => over.some((c) => c.covers.includes(id)));

let prev = {};
try {
  prev = JSON.parse(readFileSync(statePath, "utf8"));
} catch {}
const guard = { pausedByGuard: false, pausedOn: null, alerted: { date: today, keys: [] }, ...prev.guard };
if (guard.alerted.date !== today) guard.alerted = { date: today, keys: [] };

const messages = [];
if (!report) {
  if (over.length) {
    // Repeat every time: the guard does not know whether the heartbeat disable survived a gateway restart.
    heartbeat("disable");
    if (!guard.pausedByGuard) {
      guard.pausedByGuard = true;
      guard.pausedOn = today;
      messages.push(
        `⛔ Budget exhausted, lead heartbeat disabled: no new tasks and no resumes.\n` +
          over.map(describe).join("\n") +
          `\nThe agent's current step will run to completion, then lead will stop with \`ai-blocked\`.` +
          `\nTo continue today: raise the limit in budget.json and the guard will re-enable the heartbeat within 10 minutes. Otherwise the team continues tomorrow (day in UTC).`,
      );
    }
  } else if (guard.pausedByGuard) {
    heartbeat("enable");
    guard.pausedByGuard = false;
    guard.pausedOn = null;
    messages.push("✅ Budget OK, lead heartbeat re-enabled: the team will resume stopped issues and take new ones from the queue.");
  }
  const fresh = checks.filter((c) => c.level === "warn" && c.active && !guard.alerted.keys.includes(key(c)));
  if (fresh.length) messages.push(`⚠️ Over ${Math.round(budget.warnAt * 100)}% of budget spent:\n` + fresh.map(describe).join("\n"));
  for (const c of checks) if (c.active && !guard.alerted.keys.includes(key(c))) guard.alerted.keys.push(key(c));
  if (team.today.missingCost && !guard.alerted.keys.includes("missing-cost")) {
    guard.alerted.keys.push("missing-cost");
    messages.push(
      "ℹ️ OpenClaw does not know model prices for some calls: tracked dollars are understated, the tokens limit holds the budget. " +
        "Prices can be added in models.providers.<provider>.models.<model>.cost.",
    );
  }
}

const snapshot = {
  updatedAt: now.toISOString(),
  date: today,
  status,
  paused: guard.pausedByGuard,
  blocked,
  activeProviders: active,
  warnAt: budget.warnAt,
  checks,
  team: roundAll(team),
  agents: Object.fromEntries(Object.entries(agents).map(([id, { providers: _, ...a }]) => [id, roundAll(a)])),
  providers: Object.fromEntries(
    Object.entries(byProvider).map(([p, v]) => [
      p,
      { team: roundUsd(v.team), agents: Object.fromEntries(Object.entries(v.agents).map(([id, a]) => [id, roundUsd(a)])) },
    ]),
  ),
  modelsToday: models.toSorted((a, b) => b.usd - a.usd),
  limits: { team: budget.team, agents: budget.agents, providers: budget.providers },
  guard,
};
if (!report) {
  mkdirSync(dirname(statePath), { recursive: true });
  writeFileSync(`${statePath}.tmp`, JSON.stringify(snapshot, null, 2) + "\n");
  renameSync(`${statePath}.tmp`, statePath);
}

if (report) {
  const row = (name, a) =>
    `${name.padEnd(10)} today $${a.today.usd.toFixed(2).padStart(6)} ${mtok(a.today.tokens).padStart(7)}` +
    ` | yesterday $${a.yesterday.usd.toFixed(2).padStart(6)} | month $${a.month.usd.toFixed(2).padStart(7)}`;
  console.log(`Spend for ${today} (UTC), status: ${status}${guard.pausedByGuard ? ", heartbeat disabled by guard" : ""}`);
  for (const [id, a] of Object.entries(agents)) console.log(row(id, a) + `  [${active[id].join(", ")}]`);
  console.log(row("team", team));
  for (const [p, v] of Object.entries(byProvider)) {
    const usd = (period) => `$${v.team[period].usd.toFixed(2)}`;
    console.log(`${p.padEnd(10)} today ${usd("today").padStart(7)} | yesterday ${usd("yesterday").padStart(7)} | month ${usd("month").padStart(8)}`);
  }
  for (const m of snapshot.modelsToday) console.log(`  today ${m.agent.padEnd(9)} ${`${m.provider}/${m.model}`.padEnd(32)} $${m.usd.toFixed(2).padStart(6)}  ${m.calls} calls`);
  for (const c of checks) {
    const why = c.metric === "tokens" ? "all calls priced" : "provider not in use";
    console.log(describe(c) + (c.active ? "" : ` (${why}, not blocking)`));
  }
  if (blocked.length) console.log(`Blocked: ${blocked.join(", ")}`);
  if (team.month.missingCost) console.log(`No price: ${team.month.missingCost} model calls, dollars understated; the tokens limit is the fallback.`);
} else {
  console.log(messages.length ? messages.join("\n\n") : "NO_REPLY");
}

function heartbeat(action) {
  execFileSync(openclaw, ["system", "heartbeat", action, "--json"], { stdio: "ignore", timeout: 60000 });
}
function key(c) {
  return `${c.level}:${c.provider ?? "all"}:${c.scope}:${c.period}:${c.metric}`;
}
function describe(c) {
  const who = (c.provider ? `${c.provider} ` : "") + (c.scope === "team" ? "team" : c.scope);
  const period = c.period === "daily" ? "daily" : "monthly";
  const fmt = c.metric === "usd" ? (v) => `$${v.toFixed(2)}` : mtok;
  return `• ${who} ${period}: ${fmt(c.used)} of ${fmt(c.limit)} (${Math.round(c.ratio * 100)}%)`;
}
function mtok(v) {
  return `${(v / 1e6).toFixed(1)}M tok`;
}
function round(v, kind) {
  return kind === "tokens" ? Math.round(v) : Math.round(v * 100) / 100;
}
function roundUsd(periods) {
  return Object.fromEntries(Object.entries(periods).map(([p, v]) => [p, { usd: round(v.usd, "usd") }]));
}
function roundAll(periods) {
  return Object.fromEntries(
    Object.entries(periods).map(([p, v]) => [p, { usd: round(v.usd, "usd"), tokens: v.tokens, cacheRead: v.cacheRead, missingCost: v.missingCost }]),
  );
}
