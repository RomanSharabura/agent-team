---
name: workspace-lock
description: Architect, dev and qa take a lock on their workspace before touching /workspace/repos and release it when they return, so two runs of the same agent never edit one checkout at the same time.
metadata: { "openclaw": { "requires": { "bins": ["date"] } } }
---
# Workspace lock

Each agent has one workspace and one checkout (`/workspace/repos/dopamine-shop`) for all of its runs. Two runs at the same time (for example a duplicated handoff) would reset and edit the same files under each other, and neither run's tests would mean anything. The lock makes the second run stop before it touches the checkout.

## Take the lock (first step, before any git command)
```bash
L=/workspace/state/run.lock
mkdir -p /workspace/state
if mkdir "$L" 2>/dev/null; then
  printf 'issue=%s step=%s since=%s\n' "<issue>" "<step>" "$(date -u +%FT%TZ)" > "$L/owner"
  echo "lock taken"
else
  cat "$L/owner" 2>/dev/null
  find "$L" -maxdepth 0 -mmin +180 | grep -q . && echo "stale"
fi
```
- `lock taken` → continue with your steps.
- The lock is held and not `stale` (younger than 3 hours) → another run of you is working in this checkout. Do not run any git command, do not touch the checkout. Return `BLOCKED` to lead with `notes`: `workspace busy — <contents of owner> — wait for that run to finish`.
- The lock is `stale` (3 hours or older) → the earlier run died without releasing it. Take it over: `rm -rf "$L"`, take it again as above, and say in your envelope's `notes` that you took over a stale lock (`owner` contents). Then start from a clean checkout as your step 1 says (`git reset --hard origin/<branch>`).

## Release the lock (last step, whatever the verdict)
Right before returning any envelope (`READY`, `PASS`, `FAIL`, `QUESTIONS` or `BLOCKED`, except the "workspace busy" one above, where the lock is not yours):
```bash
rm -rf /workspace/state/run.lock
```

## Never
- Release a lock you did not take.
- Work in the checkout without holding the lock.
