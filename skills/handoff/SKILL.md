---
name: handoff
description: Envelope format for passing work between team agents (lead to dev and back).
---
# Handoff envelope

Агенти передають між собою лише конверт. Увесь стан живе в GitHub (issue, гілка, PR) і в папці спеки.

```json
{
  "issue": 12,
  "spec": "specs/001-admin-users-list",
  "from": "lead",
  "to": "dev",
  "step": "implement",
  "branch": "ai/12-admin-users-list",
  "attempt": 1,
  "verdict": "TODO",
  "notes": []
}
```

- `branch`: `ai/<issue>-<slug>`, де `slug` — частина назви папки спеки після номера.
- `step`: `implement` (етап 1); пізніше `validate`, `plan`, `test`, `review`.
- `verdict`: `TODO` у запиті; у відповіді `READY` (з полем `pr`), `BLOCKED` або `FAIL` (з `notes`: «REQ-ID — проблема — що потрібно»).
- `attempt` збільшує лише lead. Більше 2 → `ai-blocked`.

Lead передає конверт через `sessions_spawn` з `agentId: "dev"` і конвертом як текстом завдання. Dev відповідає конвертом останнім повідомленням.
