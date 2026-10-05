---
name: repo-conventions
description: Read dopamine-shop conventions, ADRs and the reference feature before changing any code.
---
# Repo conventions

Перед будь-якою зміною коду в `dopamine-shop`:
1. Прочитай `docs/conventions.md` повністю. Він сильніший за твої звички і за загальні знання про .NET.
2. Проглянь заголовки `docs/adr/*.md`; прочитай ті, що стосуються задачі.
3. Відкрий еталонну фічу: `specs/000-admin-get-user/` і код, на який посилається її `plan.md`.
4. Знайшов у репо закономірність, якої немає в conventions.md → запиши її в свій `MEMORY.md` і згадай у PR в розділі «Що змінилось», щоб людина вирішила, чи додавати її в conventions.

Не змінюй `docs/conventions.md` і `docs/adr/` сам: це робить людина (пізніше architect через PR).
