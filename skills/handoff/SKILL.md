---
name: handoff
description: Envelope format for passing work between team agents (lead to dev, lead to qa, and back).
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
  "pr": null,
  "attempt": 1,
  "verdict": "TODO",
  "notes": []
}
```

- `branch`: `ai/<issue>-<slug>`, де `slug` — частина назви папки спеки після номера.
- `step`: `implement` (dev) або `test` (qa); пізніше `validate`, `plan`, `review`.
- `pr`: номер draft PR. Заповнює dev у відповіді, далі lead передає його qa.
- `verdict`: `TODO` у запиті. У відповіді:
  - dev: `READY` (з полем `pr`) або `BLOCKED`;
  - qa: `PASS`, `FAIL` або `BLOCKED`.
- `notes`: для `FAIL` і `BLOCKED` — рядки «REQ-ID — очікувано — фактично — тест» або «REQ-ID — проблема — що потрібно». Lead передає їх dev без змін.
- `attempt` збільшує лише lead, коли повертає задачу dev після `FAIL`. Спроб не більше трьох (dev може отримати задачу назад двічі): `FAIL` на `attempt: 3` → `ai-blocked`.

Lead передає конверт через `sessions_spawn` з `agentId` (`dev` або `qa`) і конвертом як текстом завдання. Агент відповідає конвертом останнім повідомленням.
