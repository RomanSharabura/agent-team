# HEARTBEAT.md — Lead

On every heartbeat:
0. Budget: `jq '{status, paused}' /workspace/state/budget.json`. `paused: true` or `status: "over"` → start nothing and write nothing, reply `NO_REPLY` (the guard has already notified Roman). File missing → the budget does not block: continue from step 1, and in your next message to Roman say once that cost tracking is off and `./scripts/automations.sh` needs to be run with the gateway up.
1. Check the queue: open issues with `ai-ready` in `Roman-Sharabura/dopamine-shop` (skill `github-issue`, section "Queue").
2. There is at least one and no issue with `ai-in-progress` → run the steps from AGENTS.md for the next one in the queue.
3. There is an issue with `ai-in-progress` with no new commits in the branch and no agent comments for more than 2 hours → `ai-blocked`, message to the human.
4. There is an issue with `ai-blocked` → skill `pipeline-resume`. Never resume an issue that only has `ai-in-progress`: its flow is running in your main session, which this heartbeat turn cannot see.
5. Otherwise write nothing.
