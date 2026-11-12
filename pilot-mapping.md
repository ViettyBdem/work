# Pilot mapping: «Список очередей» and «Форма очереди»

26 old cases became 46 cases and 6 setup cases. Results are taken from the updated `sifox-cases_1.eld`.

## Two rules used to build the graph

1. **Gateway cases.** A case that others depend on does the action and checks only the result its children need. Detail checks are steps without a When, or separate leaf cases.
2. **Only a failed action blocks children.** A deviation on a step with a When blocks the descendants. A deviation on a check-only step does not.

Effect on the current results: 3 cases are «Не пройден», and only one of them (QUE-009, no archive icon) blocks anything (QUE-010, QUE-011, QUE-012).

## Old case → new nodes

| Old | Old status | New nodes | Result carried over |
|---|---|---|---|
| QUE-001 | not run | QUE-001 (structure), QUE-004 (rows, no archive button) | |
| QUE-002 | not run | QUE-005 (working), QUE-006 (outside working hours) | |
| QUE-003 | passed | QUE-007 | all steps ok |
| QUE-004 | passed | QUE-008 | all steps ok |
| QUE-005 | failed | QUE-009 (confirmation window), QUE-010 (archive) | QUE-009 step 1: «Нет иконки архивировать очередь в списке очередей.» |
| QUE-006 | not run | QUE-011 (show archive), QUE-012 (restore) | |
| QUE-007 | not run | QUE-002 | |
| QUE-008 | passed | QUE-003 | all steps ok |
| QFRM-001 | not run | QFRM-001, QFRM-002, QFRM-003 | |
| QFRM-002 | not run | QFRM-027 | |
| QFRM-003 | not run | QFRM-005, QFRM-006 | |
| QFRM-004 | passed, comment about red frames | QFRM-011, 012, 013, 014 (validation), QFRM-015 (highlighting) | 011–014 all steps ok. QFRM-015: errors shown ok; both red-frame checks deviate: «Рамки ввода полей не окрашиваются в красный». |
| QFRM-005 | not run | QFRM-025 | |
| QFRM-006 | failed | QFRM-022 (create, gateway), QFRM-023 (banner), QFRM-024 (confirmation window) | QFRM-024 step 1: «Окно не было отображено. Подтверждения … не было. Очередь создана без подтверждения.» QFRM-022 step 1 ok (the queue was created); its toast and row checks not run. |
| QFRM-007 | passed | QFRM-020 | all steps ok |
| QFRM-008 | passed | QFRM-017, QFRM-018 | all steps ok in both |
| QFRM-009 | not run | QFRM-019 | |
| QFRM-010 | not run | QFRM-021 | |
| QFRM-011 | not run | QFRM-007 | |
| QFRM-012 | not run | QFRM-008, QFRM-009 | |
| QFRM-013 | not run | QFRM-010 | |
| QFRM-014 | passed | QFRM-028 | all steps ok |
| QFRM-015 | passed | QFRM-029 | all steps ok |
| QFRM-016 | not run | QFRM-030, QFRM-031, QFRM-032 | |
| QFRM-017 | not run | QFRM-016 | |
| QFRM-018 | not run | QFRM-004 | |

## Decisions to confirm

1. **Red frames split out.** You marked old QFRM-004 «Пройден» although the frames are not red. The validation cases now pass, and the frames are their own low-severity case QFRM-015 (priority 3, S4), which fails without blocking anything.
2. **Queue creation is a gateway.** QFRM-022 says: press «Создать очередь», and if the confirmation window opens, press «Сохранить». It passes whether or not the window bug is present, so cases that need the queue are not blocked. The window itself is checked by QFRM-024.
3. **Passed multi-part case.** Old QFRM-008 was «Пройден», but its text mentioned only part 1. Both QFRM-017 and QFRM-018 are marked passed.
4. **Concrete test data.** «Кредиты» (no operators, QFRM-022), «Вклады» (one operator, priority 0, QFRM-025), «Ипотека» (group, reserve «Вклады», holiday, QFRM-026). QFRM-023/023 use the name «Без операторов», because with the window bug they create a queue as a side effect.
5. **Fixed chain.** Old QFRM-012 was "turn «Сб» on, then turn «Пн»–«Пт» off, expect «Нет рабочих дней»", which can't hold with Saturday on. QFRM-008 and QFRM-009 are now siblings from the fresh form.
6. **Severity** is seeded from the old priority (High → S2, Medium → S3); priority is the old group.

## New cases (not in the old set)

| ID | What | Why |
|---|---|---|
| AUTH-001 | Log in as manager | stub root; replaced when «Авторизация и выбор роли» is rewritten |
| QFRM-015 | Highlighting of fields with errors | red-frame checks taken out of the validation cases |
| QFRM-026 | Create queue «Ипотека» with group, reserve, holiday | gateway: clone, archive, edit-form and row cases need such a queue; only "the queue appears in the list" is asserted |
| QFRM-033 | Move the start of working hours | gateway for «Строка очереди вне рабочего времени»; only "the list opens after saving" is asserted |

## Setup cases (state no case can produce)

| ID | What |
|---|---|
| QUE-S01 | No queues at all in the manager's directions |
| QFRM-S01 | At least three free work numbers |
| QFRM-S02 | A group with operators and two more operators (placeholder until «Группы и операторы» is rewritten) |
| QFRM-S03 | Two directions, each with a group and a queue |
| QFRM-S04 | No free work numbers |
| QFRM-S05 | Weekday, 09:00–20:00 |
