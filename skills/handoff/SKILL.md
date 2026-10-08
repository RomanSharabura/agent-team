---
name: handoff
description: Envelope format for passing work between team agents (lead to ba, architect, dev, qa and back) and the lead review step.
---
# Handoff envelope

Agents pass only the envelope between each other. All state lives in GitHub (issue, branch, PR) and in the spec folder.

```json
{
  "issue": 12,
  "spec": "specs/001-admin-users-list",
  "from": "lead",
  "to": "ba",
  "step": "validate",
  "branch": "ai/12-admin-users-list",
  "pr": null,
  "attempt": 1,
  "verdict": "TODO",
  "notes": []
}
```

- `branch`: `ai/<issue>-<slug>`, where `slug` is the part of the spec folder name after the number.
- `step`: `validate` (ba), `plan` (architect), `implement` (dev) or `test` (qa). The review is done by lead itself (skill `pr-review`), without a handoff; lead records its verdict in the envelope the same way.
- Order: ba → architect → dev → qa → lead review. architect creates the branch and pushes `plan.md` and `tasks.md` to it; dev works in the same branch.
- `pr`: draft PR number. dev fills it in the response, then lead passes it to qa.
- `verdict`: `TODO` in the request. In the response:
  - ba: `PASS`, `QUESTIONS` or `BLOCKED`;
  - architect: `READY`, `QUESTIONS` or `BLOCKED`;
  - dev: `READY` (with the `pr` field) or `BLOCKED`;
  - qa: `PASS`, `FAIL` or `BLOCKED`;
  - review (lead): `APPROVE` or `CHANGES`.
- `notes`: for `QUESTIONS` — "REQ-ID — problem — question" (lead posts them in the issue for Roman); for `PASS` from ba — optional `nit: …`; for `READY` from architect — one line per draft ADR; for `FAIL` and `BLOCKED` — lines "REQ-ID — expected — actual — test" or "REQ-ID — problem — what is needed"; for `CHANGES` — "path:line — problem — what to do" (only 🔴 from the review). Lead passes them to dev unchanged.
- `attempt` applies only to the dev ↔ qa/review loop: ba and architect work with `attempt: 1`. Only lead increments it, when returning the task to dev after `FAIL` from qa or `CHANGES` from the review. The counter is shared, no more than three attempts (dev can get the task back twice): `FAIL` or `CHANGES` on `attempt: 3` → `ai-blocked`.

Lead passes the envelope via `sessions_spawn` with `agentId` (`ba`, `architect`, `dev` or `qa`) and the envelope as the task text. The agent replies with an envelope as its last message.

## Budget
Before every `sessions_spawn` lead reads the budget guard snapshot:
```bash
jq '{updatedAt, paused, blocked, over: [.checks[] | select(.level == "over" and .active) | "\(.provider // "") \(.scope)"]}' /workspace/state/budget.json
```
- `paused: true`, or `blocked` contains the agent you are handing off to → do not hand off (the guard already counts limits per provider: an exhausted limit of a provider the agent does not run on is not in `blocked`). Label `ai-blocked` and a blocker comment with the envelope, as when `sessions_spawn` is unavailable, with the reason "budget: <what was exceeded>". Do not write to the human: the guard has already notified Roman.
- No file → hand off (the guard has not run yet), but mention in the next message to the human that spend tracking is not working.

Immediately after `sessions_spawn` lead calls `sessions_yield` and waits for the envelope that way. Do not end the turn without a yield: the result would then arrive as a separate turn in which OpenClaw may not provide `sessions_spawn`, and the next handoff would be impossible. After the yield the turn continues with the same tools that were available at spawn time. Do not poll `subagents` or `sessions_list` in a loop.
