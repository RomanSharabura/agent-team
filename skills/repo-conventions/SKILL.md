---
name: repo-conventions
description: Read dopamine-shop conventions, ADRs, architecture tests and the reference slice before changing any code.
---
# Repo conventions

Перед будь-якою зміною коду в `dopamine-shop`:
1. Прочитай `docs/conventions.md` повністю. Він сильніший за твої звички і за загальні знання про .NET.
2. Проглянь заголовки `docs/adr/*.md`; прочитай ті, що стосуються задачі.
3. Відкрий еталонний слайс: `specs/000-admin-get-user/` і код, на який посилається її `plan.md` (модуль Users, фіча GetUserById).
4. Проглянь `tests/DopamineShop.ArchitectureTests`: там правила шарів, модулів, слайсів і DDD у вигляді коду. Вони запускаються з `dotnet test` і не послаблюються.
5. Знайшов у репо закономірність, якої немає в conventions.md → запиши її в свій `MEMORY.md` і згадай у PR в розділі «Що змінилось», щоб людина вирішила, чи додавати її в conventions.

Не змінюй `docs/conventions.md` і наявні `docs/adr/` сам: це робить людина. architect може додати нову чернетку ADR зі статусом `proposed` (скіл `adr-writer`), приймає її людина при мержі.
