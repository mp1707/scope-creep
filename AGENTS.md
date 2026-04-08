# Scope Creep - Current Game Documentation

This document describes the current playable vertical slice implemented in this repository.
It is the source of truth for how the game loop works right now.

## Runtime / Platform Baseline

- Engine: LOVE `11.4` (`conf.lua`).
- Save identity: `scope-creep`.
- Window title: `Scope Creep`.
- Startup size: `1920x1080`, resizable, vsync enabled.
- Minimum window size: `854x480`.

## Virtual Resolution & Scaling

- Fixed internal resolution: `1920x1080`.
- Aspect-preserving scale factor: `min(windowW/baseW, windowH/baseH)`.
- Letterbox/pillarbox bars rendered black.
- Pointer conversion uses `screenToGame`; points in bars return `nil`.
- `Scaling.resize` only recalculates scale/offset (no aggressive mode resets).

## Hot Reload

- Implemented in `src/core/hot_reload.lua`.
- Watches `main.lua` and `src/**/*.lua`.
- Poll interval: `0.5s`.
- Saves/restores board and system runtime state.
- Manual reload keys: `R` and `F5`.

## Gameplay Slice Summary

The old POC gameplay loop was removed and replaced with a modular stacklike loop:

- Start with one booster pack: **The Startup**.
- Open pack 4 times to receive deterministic starting cards.
- Build valid worker-target stacks.
- Progress work only while `running`.
- At sprint end, enter `payday`.
- Assign payroll via exact `1 Employee + 1 Money` stacks.
- Continue with `Nächster Sprint` or lose by game-over conditions.

## Controls

- `Space`: toggle `running <-> paused`.
  - Disabled in `payday` and `gameover`.
- `Enter` / `KP Enter`: toggle speed `1x <-> 2x`.
  - Works in `running`, `paused`, and `payday`.
- `Esc`: quit app.
- Mouse:
  - Drag cards to move/stack.
  - Click booster pack (without drag threshold) to open it.
  - In payday, click `Nächster Sprint` button to continue.

## State Machine

Implemented phases:

- `boot`
- `running`
- `paused`
- `payday`
- `gameover`

Transitions:

- `boot -> running` (new game bootstrap)
- `running <-> paused` (Space)
- `running -> payday` (sprint timer reaches 60 sim-seconds)
- `payday -> running` (Next Sprint button)
- `running/paused/payday -> gameover` (loss conditions)

## Time Model

- Sprint duration: `60` simulation seconds.
- `TimeSystem` returns:
  - `realDt` (wall-clock frame delta)
  - `simDt` (state-aware simulation delta)
- `simDt = dt * speedFactor` only if phase is `running`.
- In `paused`, `payday`, `gameover`: `simDt = 0`.

## Board / Stack Model

- Board cards are card instances with runtime fields.
- Stacks are evaluated from parent-child relationships.
- Current physical stacking model keeps a one-direct-child rule per parent (chain/tree-style, not free-form pile).
- Stack evaluation (`StackEvalSystem`) derives:
  - roots
  - stack members
  - work candidates
  - payroll candidate pairs

## Data-Driven Definitions

All gameplay definitions are in `src/game/defs`:

- `card_defs.lua`: static card metadata + visual mapping.
- `pack_defs.lua`: pack content sequence + uses.
- `recipe_defs.lua`: worker-target recipe matrix + completion handlers.

No gameplay rules are hardcoded in render modules.

## Card Catalog (Current)

Employees:

- `junior_dev` (`role=dev`, `workRate=0.5`, salary `1`)
- `junior_tester` (`role=tester`, `workRate=0.5`, salary `1`)

Project:

- `software` (project anchor)

Todo / Feature / Problems:

- `mini_requirement` (`baseDuration=5`, dev)
- `untested_feature` (`baseDuration=5`, tester)
- `mini_feature` (feature, no work)
- `bug` (`baseDuration=5`, dev)
- `security_issue` (`baseDuration=20`, dev)
- `tech_debt` (`baseDuration=5`, dev)

Resource:

- `money` (`value=1`)

Pack:

- `startup` (**The Startup**, 4 uses)

## Pack Flow

`The Startup` sequence:

1. `junior_dev`
2. `junior_tester`
3. `software`
4. `mini_requirement`

Behavior:

- Spawn position is radial around pack center.
- New cards are not auto-attached to the pack.
- Badge shows `usesRemaining`.
- Pack fades out and is removed when uses reach `0`.

## Work System Rules

A work job starts only for stacks containing:

- exactly 1 employee
- exactly 1 todo target
- a valid recipe for `(worker.role, target.defId)`

Effective duration at job start (snapshot):

- `duration = baseDuration / worker.workRate`
- if worker is dev: `+ techDebtCount * 2`
- tech-debt changes do not alter already-started jobs

Progress behavior:

- Runs only in `running`.
- Any stack invalidation resets/cancels the active job.
- Completion is recipe-driven via `RecipeDefs.resolveCompletion`.

## Recipes (Current)

- `dev + mini_requirement`
  - consumes requirement
  - spawns `untested_feature`
  - `junior_dev`: 20% extra `tech_debt`

- `tester + untested_feature`
  - `junior_tester` 20% retest fail: keep `untested_feature`
  - otherwise consume target, spawn `mini_feature`
  - success has 50% chance to spawn `bug`

- `dev + bug` => consume bug
- `dev + tech_debt` => consume tech debt
- `dev + security_issue` => consume security issue

## Global Effects

### Tech Debt Penalty

- Counted globally by `EffectSystem:getTechDebtCount`.
- Applied to newly started dev jobs only.

### Bug Merge

- Triggered whenever effect checks run and free bugs exist.
- While free bug count >= 3:
  - take 3 oldest free bugs by `createdAt`
  - remove them
  - spawn 1 `security_issue`

### Security Issue Periodic Effect

- Each security issue runs its own timer.
- Every `30` simulation seconds:
  - remove one random money card (if available)
  - payroll-assigned money is ignored for deletion

## Sprint Loop

During `running`:

- sprint timer advances with `simDt`
- work jobs progress
- security timers tick
- bug merge checks run

When sprint timer reaches 60 sim-seconds:

- phase enters `payday`
- work is paused/cleared
- payday entry effects are applied

## Payday Logic

On entry:

1. phase -> `payday`
2. duplicate all existing bugs (spawn one extra bug per bug)
3. merge bugs to security issues as needed
4. revenue: each `mini_feature` directly adjacent to `software` (parent/child) spawns `2 money`
5. payroll mapping recomputed from exact 1 employee + 1 money stacks

Payday interaction:

- board is visually dimmed
- only employee and money cards are interactable
- `Nächster Sprint` button is active

Payroll validity:

- only exact 2-card stack with 1 employee + 1 money counts
- valid employee/money pair gets marked/dimmed

## Next Sprint Resolution

On `Nächster Sprint` click:

1. remove unpaid employees (with brief `gekündigt` floating label)
2. consume payroll-assigned money cards
3. clear payroll flags/dimming
4. software sprint-start rule:
  - if no `mini_requirement` and no `untested_feature` in software-connected stack, spawn one `mini_requirement`
5. reset sprint timer and increment sprint number
6. phase -> `running`

## Game Over Conditions

Immediate:

- `>= 3 security_issue` cards on board => `gameover` with reason `data_leak`

After payday resolution:

- `0` employees left => `gameover` with reason `no_team_left`

Overlay messages:

- `data_leak`: "Data leak. You got sued."
- `no_team_left`: "No team left."

## UI / Rendering Responsibilities

Gameplay decisions are separated from rendering.

- Render base and input visuals remain in existing UI modules:
  - `src/ui/card.lua`
  - `src/ui/booster_pack.lua`
  - `src/ui/ui_panel.lua`
  - `src/ui/ui_button.lua`
  - `src/ui/theme.lua`
- Gameplay overlays:
  - `src/game/ui/payday_overlay.lua`
  - `src/game/ui/gameover_overlay.lua`

HUD displays:

- sprint number
- remaining sprint time
- current state
- current speed

## Project Structure

Gameplay modules:

- `src/game/defs/`
  - `card_defs.lua`
  - `pack_defs.lua`
  - `recipe_defs.lua`
- `src/game/systems/`
  - `game_state_system.lua`
  - `time_system.lua`
  - `stack_eval_system.lua`
  - `work_system.lua`
  - `effect_system.lua`
  - `sprint_system.lua`
  - `payday_system.lua`
  - `pack_system.lua`
  - `gameover_system.lua`
- `src/game/ui/`
  - `payday_overlay.lua`
  - `gameover_overlay.lua`

Entrypoint orchestration:

- `main.lua`

## Legacy Cleanup Status

Removed legacy gameplay modules:

- `src/core/card_defs.lua`
- `src/core/recipes.lua`
- `src/core/sprint.lua`
- `src/ui/hud.lua`

## Implementation Notes / Current Deviations

- Stacking is currently constrained by one direct child per card (legacy drag/snap model kept).
- Revenue adjacency for `mini_feature` + `software` uses direct parent/child neighbor check.
- Software icon currently uses `assets/handdrawn/cardIcons/mail.png` placeholder asset.
- Payday labels are German (`Nächster Sprint`, `gekündigt`).

## How To Extend Safely

- Add new cards in `src/game/defs/card_defs.lua`.
- Add pack content in `src/game/defs/pack_defs.lua`.
- Add recipe mapping + handler in `src/game/defs/recipe_defs.lua`.
- Keep deterministic rule hooks inside systems (`work`, `effect`, `payday`), not UI code.
- If adding new periodic effects, store per-instance timers under `card.effectTimers`.
