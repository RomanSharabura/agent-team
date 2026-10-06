#!/usr/bin/env node
// Team budget guard. Run by an OpenClaw automation every 10 minutes (scripts/automations.sh),
// manually: node scripts/budget-guard.mjs --report
//
// 1. Gets each agent's spend from `openclaw gateway usage-cost` (OpenClaw session logs).
// 2. Writes a snapshot to workspaces/lead/state/budget.json: lead reads it before every handoff and in the morning briefing.
// 3. A budget.json limit is exceeded → `openclaw system heartbeat disable` (the team takes no new tasks
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
  };
}

const agents = {};
for (const id of Object.keys(budget.agents)) agents[id] = usage(id);
const team = {};
for (const period of ["today", "yesterday", "month"]) {
  team[period] = Object.values(agents).map((a) => a[period]).reduce(add, zero());
}

// Limits: daily is counted for today, monthly from the start of the month.
const checks = [];
const collect = (scope, limits, used) => {
  for (const [period, key] of [["daily", "today"], ["monthly", "month"]]) {
    for (const [metric, limit] of Object.entries(limits?.[period] ?? {})) {
      const value = used[key][metric];
      const ratio = limit > 0 ? value / limit : 0;
      const level = ratio >= 1 ? "over" : ratio >= budget.warnAt ? "warn" : "ok";
      if (level !== "ok") checks.push({ scope, period, metric, used: round(value, metric), limit, ratio: round(ratio, "ratio"), level });
    }
  }
};
collect("team", budget.team, team);
for (const [id, limits] of Object.entries(budget.agents)) collect(id, limits, agents[id]);

const over = checks.filter((c) => c.level === "over");
const status = over.length ? "over" : checks.length ? "warn" : "ok";

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
  const fresh = checks.filter((c) => c.level === "warn" && !guard.alerted.keys.includes(key(c)));
  if (fresh.length) messages.push(`⚠️ Over ${Math.round(budget.warnAt * 100)}% of budget spent:\n` + fresh.map(describe).join("\n"));
  for (const c of checks) if (!guard.alerted.keys.includes(key(c))) guard.alerted.keys.push(key(c));
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
  warnAt: budget.warnAt,
  checks,
  team: roundAll(team),
  agents: Object.fromEntries(Object.entries(agents).map(([id, a]) => [id, roundAll(a)])),
  limits: { team: budget.team, agents: budget.agents },
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
  for (const [id, a] of Object.entries(agents)) console.log(row(id, a));
  console.log(row("team", team));
  for (const c of checks) console.log(describe(c));
  if (team.month.missingCost) console.log(`No price: ${team.month.missingCost} model calls, dollars understated; the tokens limit is the fallback.`);
} else {
  console.log(messages.length ? messages.join("\n\n") : "NO_REPLY");
}

function heartbeat(action) {
  execFileSync(openclaw, ["system", "heartbeat", action, "--json"], { stdio: "ignore", timeout: 60000 });
}
function key(c) {
  return `${c.level}:${c.scope}:${c.period}:${c.metric}`;
}
function describe(c) {
  const who = c.scope === "team" ? "team" : c.scope;
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
function roundAll(periods) {
  return Object.fromEntries(
    Object.entries(periods).map(([p, v]) => [p, { usd: round(v.usd, "usd"), tokens: v.tokens, cacheRead: v.cacheRead, missingCost: v.missingCost }]),
  );
}
