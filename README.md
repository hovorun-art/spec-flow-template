# Spec-driven flow для Claude Code + OpenSpec

Шаблон флоу з проекту `leetcode` (гра про корабель), без деталей гри. Цей README не копіюється в проект.

## Встановлення

```bash
~/Dev/spec-flow-template/install.sh ~/Dev/my-project        # існуючі файли не чіпає
~/Dev/spec-flow-template/install.sh ~/Dev/my-project --force # перезаписати
```

Потім заповнити:

| Файл | Що вписати |
|---|---|
| `.claude/flow.conf` | гілка, команди перевірок, лінтер, встановлення залежностей (зараз npm/eslint; порожнє значення вимикає перевірку) |
| `CLAUDE.md` | блоки `TODO`: опис проекту, команди, архітектура |
| `openspec/config.yaml` | `context`: що за продукт і стек |
| `docs/concept.md` | загальна ідея |

Потрібно: `git`, `python3`, `claude`, OpenSpec CLI (`npm i -g @fission-ai/openspec`).

## Що всередині

- **Ворота перед специфікаціями**: `gate-specs.sh` блокує `specs/`, `design.md`, `tasks.md`, поки немає `/specs-go`.
  Спершу `decisions.md` (Decided / Open questions) і питання через AskUserQuestion.
- **Хуки**: лінт на кожне редагування, перевірка "лише англійська" поза `locales/`, повні перевірки на Stop,
  потім обов'язковий PASS від `change-verifier` (сабагент на Opus, звіряє код зі спеками і `decisions.md`).
- **Команди**: `/opsx:*` (OpenSpec з доробками під decisions), `/specs-go`, `/work-on`.
- **Скіл** `reference-research`: шукає референси перед питаннями про те, як щось має виглядати.
- **Паралельні агенти**: `scripts/agents/` — worktree на кожну зміну, статус, злиття по `.merge-after`.

## Що свідомо не взято

- `game-design` і `ref2game`: ігрові скіли. Для ігрового проекту скопіюй їх з
  `~/Dev/leetcode/.claude/skills/` (у них приклади з кораблем, їх варто переписати).
- Пам'ять Claude (`~/.claude/projects/...`) прив'язана до проекту. Загальні правила з неї
  (питання українською, без чисел у спеках) вже вписані в `CLAUDE.md` і `openspec/config.yaml`.
