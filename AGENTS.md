# Roots — Agent Guide

Cozy multiplayer farming sim. Godot 4.7 (Forward+, Jolt Physics), GDScript 2.0,
GD-Sync multiplayer. See `plans/roots_game_plan.md` for the full design and status.

## Project layout

The **Godot project lives in `roots/`** (the folder with `project.godot`).
All opencode paths are relative to the repo root, so game code is at
`roots/src/`, scenes under `roots/src/...`, etc.

- `roots/project.godot` — open this in the Godot editor
- `roots/src/` — all game code: `core/` (singletons), `data/`, `items/`,
  `main/`, `player/`, `ui/`, `world/`, `entities/`, `crafting/`, `skills/`,
  `quests/`, `shaders/`, `multiplayer/`
- `roots/addons/godot_mcp/` — MCP bridge addon (v4.1.0, port 6550)
- `roots/addons/GD-Sync/` — multiplayer addon
- `plans/` — design docs (`roots_game_plan.md`, `terrain_rewrite_plan.md`)
- `docs/coding_standards.md` — GDScript + scene conventions (read this)

Main scene: `roots/src/main/menu/main_menu.tscn`

Autoloads: `GameManager`, `EventBus`, `SaveManager`, `Settings`,
`ItemDatabase`, `CropDatabase`, `SkillManager`, `RecipeDatabase`,
`QuestManager`, `QuestDatabase`.

## Validating changes

There is no separate linter/typecheck step — use the Godot CLI to validate.
Run these from `roots/`:

```bash
# Load the full project headlessly and quit — catches GDScript parse
# errors, bad autoloads, and broken scene references.
godot --headless --quit

# Check a single script's parse without loading the whole project:
godot --headless --check-only --script roots/src/path/to/file.gd
```

Always run `godot --headless --quit` after non-trivial GDScript edits before
considering the task done. Watch the output for `SCRIPT ERROR` / `parse error`.
A benign `invalid UID` warning on `main_menu_bg.jpg` can be ignored.

## GDScript conventions (summary)

See `docs/coding_standards.md` for the full version. Highlights:

- Files `snake_case.gd`, classes `PascalCase`, functions/vars `snake_case`,
  constants `UPPER_SNAKE`, signals `snake_case`, enums `PascalCase` with
  `UPPER_SNAKE` values.
- Always type-hint params and return values.
- Signals go at the top, after `extends`/`class_name`.
- Private functions prefixed with `_`.
- Node names `PascalCase`; prefer signal-driven loose coupling.
- Use `call_deferred()` for scene modifications during physics/signal callbacks.

Do not add comments unless asked. Match the surrounding file's style.

## Godot MCP integration

This project is wired to `@satelliteoflove/godot-mcp` (configured in
`opencode.json` under `mcp.godot-mcp`). The bridge is:

```
opencode  --stdio-->  godot-mcp server (Node)  --ws :6550-->  addon in Godot editor  --debugger-->  running game
```

**Requirements for the MCP tools to work:**
1. The Godot editor must be **open** with this project loaded, and the
   **Godot MCP** plugin enabled (it is, in `project.godot`). The addon serves
   on `127.0.0.1:6550`.
2. opencode must be **restarted** after any `opencode.json` change for the MCP
   server to register.

The server exposes ~21 tools (86 actions): `godot_scene`, `godot_node_read`/
`godot_node_edit`, `godot_editor_read`/`godot_editor_edit` (run/stop/restart,
screenshots, editor error log), `godot_project`, `godot_animation_*`,
`godot_tilemap_*`, `godot_gridmap_*`, `godot_resource`, `godot_scene3d`,
`godot_docs`, `godot_input` (inject input into the running game),
`godot_profiler`, `godot_runtime_state` (live game state as JSON),
`godot_game_time` (freeze/step the game clock for deterministic testing),
`godot_exec` (run GDScript in the running game), `godot_validate_meshes`.

Read tools (`godot_*_read`, `godot_project`, `godot_scene3d`, `godot_docs`,
`godot_runtime_state`, `godot_game_time`, `godot_profiler`,
`godot_validate_meshes`) are safe/observation-only. Write tools
(`godot_*_edit`, `godot_scene`, `godot_input`, `godot_exec`) mutate the
project or drive the game.

Prefer editing files directly for scene/node/script authoring (the bridge
deliberately does not duplicate file-based operations). Use the MCP tools for
what files can't do: running the game, observing live state, capturing editor
errors, deterministic playtesting, and reading binary-encoded tilemap/gridmap
cells.

## Running / testing the game

- From the editor: F5 (plays `main_menu.tscn`).
- From CLI (no MCP): `godot --path roots` (or `godot` from inside `roots/`).
- With MCP: use `godot_editor_edit` `run` to launch, `godot_runtime_state` /
  `godot_game_time` / `godot_input` to drive and observe,
  `godot_editor_read` `screenshot_game` to capture, and
  `godot_editor_read` `editor_log` to pull errors.

## Git

Repo: `github.com/Roanger/Roots`. Default branch `main`. Only commit when
explicitly asked. `*.import` and `.godot/` are gitignored.

## Next session: Phase 3 & 4 remaining

Next time start here. See `plans/roots_game_plan.md` for details.

**Phase 3 to-dos:**
- Plant identification system (3.2)
- Goat/deer/rabbit 3D models (currently placeholder capsules) (3.5)
- Defensive structures (3.6)

**Phase 4 to-dos:**
- Housing placement (4.3)
- Player-specific land permissions (4.3)
- More quest content and chains (4.6)
- Wildlife interactions (4.4)
- Seasonal animal migrations (4.4)
- Environmental hazards (4.5)
- Natural disasters (4.5)
