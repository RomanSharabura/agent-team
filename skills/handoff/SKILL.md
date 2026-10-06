---
name: handoff
description: Envelope format for passing work between team agents (lead to ba, architect, dev, qa and back) and the lead review step.
---
# Handoff envelope

Агенти передають між собою лише конверт. Увесь стан живе в GitHub (issue, гілка, PR) і в папці спеки.

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

- `branch`: `ai/<issue>-<slug>`, де `slug` — частина назви папки спеки після номера.
- `step`: `validate` (ba), `plan` (architect), `implement` (dev) або `test` (qa). Review робить сам lead (скіл `pr-review`), без передачі; його вердикт lead записує в конверт так само.
- Порядок: ba → architect → dev → qa → review lead. Гілку створює architect і пушить у неї `plan.md` і `tasks.md`; dev працює в тій самій гілці.
- `pr`: номер draft PR. Заповнює dev у відповіді, далі lead передає його qa.
- `verdict`: `TODO` у запиті. У відповіді:
  - ba: `PASS`, `QUESTIONS` або `BLOCKED`;
  - architect: `READY`, `QUESTIONS` або `BLOCKED`;
  - dev: `READY` (з полем `pr`) або `BLOCKED`;
  - qa: `PASS`, `FAIL` або `BLOCKED`;
  - review (lead): `APPROVE` або `CHANGES`.
- `notes`: для `QUESTIONS` — «REQ-ID — проблема — питання» (lead публікує їх в issue для Roman); для `PASS` від ba — необов'язкові `nit: …`; для `READY` від architect — по рядку на чернетку ADR; для `FAIL` і `BLOCKED` — рядки «REQ-ID — очікувано — фактично — тест» або «REQ-ID — проблема — що потрібно»; для `CHANGES` — «path:line — проблема — що зробити» (лише 🔴 з review). Lead передає їх dev без змін.
- `attempt` стосується лише петлі dev ↔ qa/review: ba і architect працюють з `attempt: 1`. Збільшує його лише lead, коли повертає задачу dev після `FAIL` від qa або `CHANGES` з review. Лічильник спільний, спроб не більше трьох (dev може отримати задачу назад двічі): `FAIL` чи `CHANGES` на `attempt: 3` → `ai-blocked`.

Lead передає конверт через `sessions_spawn` з `agentId` (`ba`, `architect`, `dev` або `qa`) і конвертом як текстом завдання. Агент відповідає конвертом останнім повідомленням.
