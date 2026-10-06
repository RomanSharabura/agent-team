---
name: morning-briefing
description: Lead's weekday morning briefing for Roman - what the team finished, what is in progress, what waits on Roman, sprint goal progress and spend from the budget snapshot.
metadata: { "openclaw": { "requires": { "bins": ["gh", "jq"] }, "primaryEnv": "GH_TOKEN" } }
---
# Morning briefing

The turn comes from the "Morning briefing" automation (Mon–Fri morning). Your reply goes to Roman in Slack as is, so write only the briefing: no intro, in English, up to 15 lines. Change nothing in GitHub and hand no tasks to anyone: this is only a report. The flow is driven by the heartbeat and `pipeline-resume`.

## Data
```bash
R=Roman-Sharabura/dopamine-shop
SINCE=$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ)   # on Monday: '72 hours ago'
# Done: PRs merged in the period, and issues that reached ai-review
gh pr list --repo $R --state merged --search "merged:>=$SINCE" --json number,title,url
gh issue list --repo $R --state open --label ai-review --json number,title,updatedAt
# In progress and stalled
gh issue list --repo $R --state open --label ai-in-progress --json number,title,updatedAt
gh issue list --repo $R --state open --label ai-blocked --json number,title,updatedAt
gh issue list --repo $R --state open --label ai-needs-input --json number,title,updatedAt
# Queue
gh issue list --repo $R --state open --label ai-ready --json number,title,milestone,createdAt
# Sprint goal: the open milestone with the nearest due_on (without a date — the oldest)
gh api "repos/$R/milestones?state=open&sort=due_on&direction=asc" \
  --jq '.[0] | {title, description, due_on, open_issues, closed_issues}'
# PRs waiting for Roman's review
gh pr list --repo $R --state open --search "review-requested:RomanSharabura" --json number,title,url
```
Take the step for each in-progress issue from the last signed comment (`gh issue view <N> --comments`), as in skill `pipeline-resume`.

Spend — from the budget guard snapshot; do not calculate anything yourself:
```bash
jq '{updatedAt, status, paused, checks, team, agents: (.agents | map_values({today, yesterday}))}' /workspace/state/budget.json
```
No file or `updatedAt` older than an hour → line "Spend tracking has not updated since …, check the Budget guard automation".

## Format
```text
☀️ Briefing <date>
Sprint goal: <milestone> — <closed>/<closed+open> issues, due <due_on>   (line only if there is a milestone)
✅ Done: #12 SPEC-004 merged; #14 awaiting your review (PR #15)
🔧 In progress: #16 — dev, attempt 2 of 3
⏸ Waiting on you: #17 ai-needs-input (2 questions about the spec); PR #15 review
📥 Queue: 3 issues, next #18 SPEC-007
💸 Yesterday $4.20 (dev $2.90, qa $0.80, …), month to date $31.50 of $150; ≈ $2.10 per PR
```
- Skip empty lines; if nothing happened in the period and nothing is waiting, say in one line that the queue is empty and the team is idle.
- "≈ $ per PR": yesterday's team spend divided by the number of issues that reached `ai-review` yesterday; none → the line without this part. It is an approximation, so write "≈".
- `paused: true` or `checks` contains `over` → the first line after the heading: "⛔ Team paused due to budget: <what was exceeded>".
- Links to issues and PRs — full URLs; Slack makes them clickable.
