#!/usr/bin/env node
// Сторож бюджету команди. Запускає його автоматизація OpenClaw раз на 10 хвилин (scripts/automations.sh),
// вручну: node scripts/budget-guard.mjs --report
//
// 1. Бере витрати кожного агента з `openclaw gateway usage-cost` (журнали сесій OpenClaw).
// 2. Пише знімок у workspaces/lead/state/budget.json: lead читає його перед кожною передачею і в ранковому брифінгу.
// 3. Перевищено ліміт з budget.json → `openclaw system heartbeat disable` (команда не бере нових задач
//    і не відновлює зупинені) і одне повідомлення в Slack. Нова доба і ліміти в нормі → heartbeat назад,
//    але лише якщо його вимкнув сам сторож.
// Без змін друкує NO_REPLY: автоматизація тоді нічого не надсилає.
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
// Від початку місяця, але не менше двох днів, щоб у брифінгу 1-го числа було «вчора».
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

// Ліміти: daily рахуємо за сьогодні, monthly — від початку місяця.
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
    // Повторюємо щоразу: сторож не знає, чи пережив вимик heartbeat перезапуск шлюзу.
    heartbeat("disable");
    if (!guard.pausedByGuard) {
      guard.pausedByGuard = true;
      guard.pausedOn = today;
      messages.push(
        `⛔ Бюджет вичерпано, heartbeat lead вимкнено: нових задач і відновлення не буде.\n` +
          over.map(describe).join("\n") +
          `\nПоточний крок агента дограє до кінця, далі lead зупиниться з \`ai-blocked\`.` +
          `\nПродовжити сьогодні: підніми ліміт у budget.json, і сторож сам увімкне heartbeat протягом 10 хвилин. Інакше команда продовжить завтра (доба за UTC).`,
      );
    }
  } else if (guard.pausedByGuard) {
    heartbeat("enable");
    guard.pausedByGuard = false;
    guard.pausedOn = null;
    messages.push("✅ Бюджет у нормі, heartbeat lead знову увімкнено: команда продовжить зупинені issues і візьме нові з черги.");
  }
  const fresh = checks.filter((c) => c.level === "warn" && !guard.alerted.keys.includes(key(c)));
  if (fresh.length) messages.push(`⚠️ Витрачено понад ${Math.round(budget.warnAt * 100)}% бюджету:\n` + fresh.map(describe).join("\n"));
  for (const c of checks) if (!guard.alerted.keys.includes(key(c))) guard.alerted.keys.push(key(c));
  if (team.today.missingCost && !guard.alerted.keys.includes("missing-cost")) {
    guard.alerted.keys.push("missing-cost");
    messages.push(
      "ℹ️ OpenClaw не знає ціни моделі для частини викликів: долари в обліку занижені, бюджет тримає ліміт tokens. " +
        "Ціни можна додати в models.providers.<provider>.models.<model>.cost.",
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
    `${name.padEnd(10)} сьогодні $${a.today.usd.toFixed(2).padStart(6)} ${mtok(a.today.tokens).padStart(7)}` +
    ` | вчора $${a.yesterday.usd.toFixed(2).padStart(6)} | місяць $${a.month.usd.toFixed(2).padStart(7)}`;
  console.log(`Витрати на ${today} (UTC), статус: ${status}${guard.pausedByGuard ? ", heartbeat вимкнено сторожем" : ""}`);
  for (const [id, a] of Object.entries(agents)) console.log(row(id, a));
  console.log(row("team", team));
  for (const c of checks) console.log(describe(c));
  if (team.month.missingCost) console.log(`Без ціни: ${team.month.missingCost} викликів моделі, долари занижені; страхує ліміт tokens.`);
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
  const who = c.scope === "team" ? "команда" : c.scope;
  const period = c.period === "daily" ? "за добу" : "за місяць";
  const fmt = c.metric === "usd" ? (v) => `$${v.toFixed(2)}` : mtok;
  return `• ${who} ${period}: ${fmt(c.used)} з ${fmt(c.limit)} (${Math.round(c.ratio * 100)}%)`;
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
