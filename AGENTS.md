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

This project is wired to `@satelliteoflove/godot-mcp`, configured in both
`opencode.json` (for the `opencode` CLI) and `.mcp.json` (for Claude Code —
project-scoped MCP servers). The bridge is:

```
client  --stdio-->  godot-mcp server (Node)  --ws :6550-->  addon in Godot editor  --debugger-->  running game
```

**Requirements for the MCP tools to work:**
1. The Godot editor must be **open** with this project loaded, and the
   **Godot MCP** plugin enabled (it is, in `project.godot`). The addon serves
   on `127.0.0.1:6550`.
2. The client (opencode or Claude Code) must be **restarted** after any
   `opencode.json`/`.mcp.json` change for the MCP server to register.

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

## Blender MCP integration

Also wired via `.mcp.json`: `blender-mcp` (the `ahujasid/blender-mcp` addon +
`uvx blender-mcp` bridge), for making/remaking 3D assets (models used in
`roots/assets/`, e.g. the animal `.blend` files, tools, props) directly from a
chat session instead of hand-authoring in the Blender UI. The bridge is:

```
client  --stdio-->  blender-mcp server (uvx)  --socket :9876-->  BlenderMCP addon in Blender  -->  running Blender scene
```

**Requirements for the MCP tools to work:**
1. The `BlenderMCP` addon must be installed and enabled in Blender's
   Preferences → Add-ons (already installed at
   `~/.config/blender/<version>/scripts/addons/addon.py` for this machine).
2. Blender must be **open**, with the addon's **"Start MCP Server"** button
   clicked (View3D → sidebar (N-panel) → BlenderMCP tab). The addon listens on
   `127.0.0.1:9876`.
3. Claude Code must be **restarted** after the `.mcp.json` change for the
   server to register.

Exposes scene/object read+edit, material/shader editing, and (with API keys
configured in the addon's preferences) Poly Haven asset downloads and
Rodin/Hyper3D generative model creation. Exported models still need to land in
`roots/assets/` and get imported/wired into `item_database.gd` /
`animal_data.gd` etc. by hand (or via a follow-up Godot MCP / file edit) —
Blender MCP only drives Blender itself, not the Godot project.

**Gotchas learned building the tool remakes (Jul 2026):**
- Never call `bpy.ops.wm.read_factory_settings()` (or anything that reloads
  Blender's whole Python/addon state) over the bridge — it kills the running
  MCP server's connection and even removes the BlenderMCP sidebar tab until
  Blender is fully restarted. To clear a scene, remove objects individually
  (`bpy.data.objects.remove(obj, do_unlink=True)` in a loop) instead.
- `bpy.ops.object.mode_set()` (and other operators needing a 3D viewport
  context) can fail with "Context missing active object" when called through
  the exec bridge. Prefer pure `bmesh` data manipulation over edit-mode
  operators where possible — it sidesteps the context requirement entirely.
- **Any mesh built via raw `bmesh.verts.new()`/`bmesh.faces.new()` (not a
  `bpy.ops.mesh.primitive_*` call) has no UVs**, which Godot's tangent
  generation turns into a real bug: the surface can render fully invisible in
  Godot with zero errors anywhere. `godot_validate_meshes` catches it
  (`degenerate_uvs`, "N% of triangles have zero UV area"). Fix by walking the
  mesh with `bmesh` and assigning each loop a UV projected onto its face's
  dominant axis plane before `bm.to_mesh()` — see the shovel/hammer/tongs/
  mortar build scripts in this session's history for the pattern. For a
  flat-color low-poly asset with no textures, UV layout quality doesn't matter,
  only that it's non-degenerate.
- After saving a changed `.blend` over an existing asset, Godot reimports it
  automatically (filesystem watcher) — no explicit reimport call needed. Use
  `godot_editor_edit run frozen=true` → `godot_exec` (e.g.
  `player.update_held_tool(InventoryItem.new(item_data))`) → `godot_game_time
  step` → `godot_editor_read screenshot_game` to verify a model in-game without
  touching the Godot UI.

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

## Next session: Phase 4 remaining

Next time start here. See `plans/roots_game_plan.md` for details.
**Phase 3 (3.1–3.6) is now fully complete.**

A Jul 2026 doc audit found several items below were already done but left
unchecked in the plan (now corrected): plant identification (herbarium),
goat/deer/rabbit models (real `.blend` files, not capsules), defensive
structures (walls/spiked barricade), wildlife hunting interactions, and quest
content (25 quests/7 chains, up from 10+/3).

Phase 3.1's last two items are done: "Master Craft" in `crafting_ui.gd`
(Forge/Anvil "Temper", Alchemy Table "Distill") activated the previously-dead
`ItemData.ItemQuality` field across tool power, durability, and potion/food
potency. Blacksmith's Tongs + Alchemist's Mortar & Pestle (new Blender-MCP
models) activated the previously-dead passive `Equipment.TOOL_1/2/3` slots —
equip one for a per-profession crafting-speed/quality bonus via the new
`ItemData.equip_bonuses` field, summed into `SkillManager.get_perk_bonus()`.

**Housing placement (4.3) is done** — `house` placeable + `HouseObject`
(`src/world/house_object.gd`, mirrors `CommunityCenterObject`). Building it
surfaced 3 bugs in the *existing* interior system (`BuildingDoor` +
`InteriorManager`, shared by community center/shops/tavern/small houses) that
made every one of those already-shipped buildings non-functional once
entered — all fixed now, see the 4.3 entry in `plans/roots_game_plan.md`:
no exit door existed anywhere, walls were invisible from inside (backface
culling on plain `MeshInstance3D` boxes), and there was zero collision on any
interior surface (player fell through the floor into real terrain far below
the interior's `y=500` pocket-dimension offset). If you add a 5th interior
type, copy the `_add_box()` pattern (StaticBody3D + CollisionShape3D +
CULL_DISABLED material) and the `_add_exit_door()`/`_add_light()` calls from
`small_house_interior.gd` — don't reintroduce the bug.

**Planned (Jul 2026 design note, see `plans/roots_game_plan.md` 4.3):** two
parallel housing systems, not one replacing the other — (1) the premade
`house` item above (fast, teleports into a pocket-dimension interior), and
(2) a not-yet-started piece-by-piece open-world building system (modular
wall/floor/roof/door pieces, no teleport — the "no loading screen" option;
today only fences/gates/posts work this way, no building pieces exist yet).
The BuildingDoor/InteriorManager system is also the intended foundation for
furnishing NPC building interiors (currently bare reused templates) and for
letting players decorate inside their own house.

**Phase 4 to-dos:**
- Player-specific land permissions — claim posts are placed/persisted but not
  enforced (`TerrainService.is_in_any_claim_zone()` exists, zero callers);
  also no multiplayer networking exists yet to have "other players" (4.3)
- Furnish NPC building interiors — give each of the 4 shared interior
  templates per-building-role props instead of the current bare rooms (4.3)
- Player house interior decoration — place decoration items inside your own
  house's interior instance (4.3)
- Piece-by-piece house building — modular wall/floor/roof/door placeables
  built directly in the world, no interior teleport (4.3)
- Seasonal animal migrations (4.4)
- Environmental hazards (4.5)
- Natural disasters (4.5)
