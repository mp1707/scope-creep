# Scope Creep - Baseline Setup

This file documents the core runtime/setup behavior currently implemented in this project.

## Engine + Window

- Engine: LOVE `11.4` (configured in `conf.lua`).
- Save identity: `scope-creep`.
- Window title: `Scope Creep`.
- Startup window size: `1920x1080`.
- Window is resizable: `true`.
- VSync: `on` (`t.window.vsync = 1`).
- Minimum window size: `854x480`.

## Virtual Resolution + Aspect Ratio

- Internal virtual resolution is fixed to `1920x1080` (16:9) in `main.lua` + `src/core/scaling.lua`.
- Game renders to an offscreen canvas at the virtual size, then scales to fit the real window.
- Scale factor uses `min(windowW / baseW, windowH / baseH)`, preserving aspect ratio.
- Content is centered via `offsetX` / `offsetY`.
- Extra area is letterboxed/pillarboxed with black bars (`barColor = {0,0,0,1}`).
- Resizing does not force window dimensions anymore (no `love.window.updateMode` in resize flow), which avoids macOS maximize flicker loops.

## Rendering Style (Not Pixelated)

- The render canvas uses `linear` filtering (`canvas:setFilter("linear", "linear")`).
- Fonts are also filtered with `linear` in `Theme.load()`.
- Result: smooth scaling rather than pixel-art nearest-neighbor upscaling.

## Icon Assets

- Use icon assets from `assets/icons` for in-game card visuals.
- Use the `256px` icon variants as the standard source for game rendering.

## Resize + Input Mapping

- `love.resize(w, h)` only recalculates scale/offset via `Scaling.resize(w, h)`.
- `screenToGame(x, y)` converts window/screen coordinates into virtual-game coordinates.
- `screenToGame` returns `nil, nil` when the pointer is in the black-bar area (outside the virtual viewport).
- `screenToGame` is exposed globally as `_G.screenToGame` for UI modules.

## Hot Reload

- Implemented in `src/core/hot_reload.lua`.
- Watches `main.lua` and all `.lua` files under `src/`.
- Poll interval: every `0.5s`.
- On change:
  - Saves runtime state via `HotReload.getState` (currently `state.time`).
  - Unloads `src.*` modules from `package.loaded` (except hot_reload itself).
  - Reloads `main.lua` and re-runs `love.load(true)`.
  - Restores runtime state via `HotReload.setState`.
  - Shows `Reloaded` message for ~2 seconds.
- Manual reload keys: `r` and `f5`.

## Main Loop Wiring

- `love.update(dt)`:
  - Advances `state.time`.
  - Updates `InfoPanel`.
  - Updates hot-reload watcher.
- `love.draw()`:
  - Draws via `Scaling.draw(...)` into the virtual canvas.
  - Then presents scaled output + black bars.
- `escape` key quits the app.

## LOVE Modules

Disabled:

- `joystick`, `physics`, `video`.

Enabled:

- `audio`, `graphics`, `window`, `timer`, `keyboard`, `mouse`, `sound`, `font`, `image`.
