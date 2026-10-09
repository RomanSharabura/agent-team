---
name: pipeline-resume
description: Lead resumes a stalled Spec to PR flow from GitHub state alone - read the issue comments, work out the next step and spawn the right agent without a human.
metadata: { "openclaw": { "requires": { "bins": ["gh", "jq"] }, "primaryEnv": "GH_TOKEN" } }
---
# Resuming a stalled flow

All flow state lives in GitHub, so any of your turns can resume work, even if you do not remember what you did earlier. This skill is about how to tell from the issue comments which step things are at, and how to continue.

The flow stalls when the turn in which an agent's reply arrives has no `sessions_spawn` (OpenClaw keeps the tools from the moment of `sessions_spawn` only for the turn that continues after `sessions_yield`). Then you write a blocker comment and stop. Your next turn — a heartbeat or a human message — has the full toolset and can continue on its own.

## When to apply
- On every heartbeat turn.
- When the human writes "Issue #N: continue".

## 1. Find stalled issues
A stalled issue is one with the `ai-blocked` label. Only those are resumed.
```bash
R=Roman-Sharabura/dopamine-shop
gh issue list --repo $R --state open --label ai-blocked --json number,updatedAt --jq 'sort_by(.updatedAt)'
```
Empty → write nothing, end the turn (`NO_REPLY` on a heartbeat).

An issue with `ai-in-progress` is **not** stalled, however quiet it looks: a flow is running in lead's main session, and a heartbeat turn is an isolated session that cannot see that flow or its agents (the `subagents` tool there does not list them). Resuming it starts a second ba/architect/dev/qa run next to the first one, and both edit the same workspace. The only exception is HEARTBEAT step 3: `ai-in-progress` with no commits in the branch and no agent comment for more than 2 hours is relabeled `ai-blocked` with a comment, and the next heartbeat resumes it from here.

## 2. Work out the step
```bash
gh issue view <N> --repo $R --json comments --jq '.comments[] | "\(.createdAt) \(.body)"'
```
Read bottom-up. The last blocker comment contains an envelope in a ```json block — that is the task that could not be handed off. Take it as is.

If there is no envelope (an old blocker or the handoff broke off without a comment), build an envelope following skill `handoff` from the latest thing visible in the issue:

| Latest in the issue | Next step |
| --- | --- |
| "Picked up", no reply from ba | `to: ba`, `step: validate`, `attempt: 1` |
| "ba: spec PASS" | `to: architect`, `step: plan`, `attempt: 1` |
| "architect: plan in branch `<branch>`" | `to: dev`, `step: implement`, `attempt: 1`, the same `branch` |
| "dev: draft PR #M, handing off to qa" | `to: qa`, `step: test`, `attempt` from the comment, `pr: M` |
| "qa: PASS, starting review" | do the review yourself (skill `pr-review`), without a handoff |
| "qa: FAIL, returning to dev (attempt K of 3)" | `to: dev`, `step: implement`, `attempt: K`, `notes` from qa unchanged |

Issues started before 2026-10-06 may carry the same status comments in Ukrainian («Взяв у роботу», «ba: спека PASS», «architect: план у гілці», «dev: draft PR #M, передаю qa», «qa: PASS, роблю review», «qa: FAIL, повертаю dev (спроба K з 3)»). Treat them exactly like their English rows above.

## 3. Check that the step is still needed
Do not hand off blindly: the agent may have done everything and only your turn got lost.
First use the `subagents` tool to check whether there is an active session of the needed agent (a heartbeat turn may not see sessions started by the main session, so an empty list proves nothing). Then check what is already in the repository:
```bash
gh pr list --repo $R --head <branch> --state all --json number,isDraft,title
gh api "repos/$R/contents/<spec>/qa-report.md?ref=<branch>" >/dev/null 2>&1 && echo "qa already done"
```
- There is an active session of the needed agent → end the turn without changes.
- The step is already visibly done (a PR exists for `implement`, `qa-report.md` exists for `test`) → move on to the next step instead of repeating this one.

## 4. Continue
`sessions_spawn` with the envelope, immediately followed by `sessions_yield` (skill `handoff`), and then the usual steps from AGENTS.md.
Before the handoff: label `ai-in-progress` instead of `ai-blocked`, if it was set, and a one-line comment saying that you are continuing and from which step.

`sessions_spawn` is unavailable in this turn too → do not write to the issue a second time (the blocker is already there) and end the turn. The next heartbeat will try again.

## Never
- Do not run two agents on the same issue at the same time. Never resume an issue that has `ai-in-progress` without `ai-blocked`.
- An agent returned `BLOCKED` with "workspace busy" → another run of that agent is still working. Do not hand off again and do not relabel: end the turn; that run's reply will continue the flow.
- Do not start a new issue from `ai-ready` while there is a stalled one with `ai-in-progress`: finish what was started first.
- Do not repeat the blocker comment: one blocker per stall.
