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

## Next session: Phase 4 complete — Phase 5 or 6 next

Next time start here. See `plans/roots_game_plan.md` for details.
**Phases 1-4 are now fully complete** (see the bottom of this section for
the small, deliberately-deferred piece-by-piece-building/cold-exposure
follow-ups — those are polish, not blockers). Next up is either Phase 5
(Multiplayer Depth) or Phase 6 (Polish & Content) — ask the user which to
prioritize, since both are fully unstarted and roughly comparable in scope.

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
furnishing NPC building interiors and for letting players decorate inside
their own house.

**Land permissions (4.3) is done** — `TerrainService.can_build_at()`/
`get_claim_owner_at()`, claims keyed by `GameManager.local_player_id` (was a
hardcoded `"player"` string). Wired into `player_controller.gd`'s placement
ghost — `_placement_valid` was hardcoded `true` unconditionally before this,
so the existing red/green tint code was dead. Real cross-player enforcement
still needs actual multiplayer wiring to matter beyond single-player
self-consistency (no "other players" exist yet to test against for real).

**Furnish NPC building interiors (4.3) is done** — the 4 shared interior
scripts take a `setup(role_id)` call from `InteriorManager` (was
`_ready()`-driven, no role awareness) and each has a `_furnish(role_id)` match
dressing it per building type (Blacksmith forge/anvil/rack,
Town Hall desk/bookshelf, Farmer House bed/chest, Guard Post weapon
rack/cot, General Store shelves/crates, Bakery oven/bread rack, Herbalist
potion shelves, plus enriched Tavern/Community Center furnishing). If you add
a new NPC building role, add a `match` case in the relevant `_furnish()`
rather than a new interior scene — the shell (floor/walls/ceiling/exit
door/light/collision) is already shared.

**Player house interior decoration (4.3) is done** — `ItemData.
placeable_indoor_ok` gates which placeables work indoors (flower pot, wooden
chair, small table, sitting log). `player_controller.gd._get_own_house_interior_id()`
gates it to your own `house_*` interior only (never NPC buildings). Indoor
placement uses a new `_get_indoor_placement_position()` (floor-height stepping
clamped to the room's known footprint — clamp AFTER grid-snap rounding, not
before, or `roundf()` can push the result back outside the room). Persistence
reuses the existing outdoor `placed_objects` save pipeline (it already walked
indirect `PlaceableObject` children via the `"placeables"` group) rather than
a new system — `main_world._load_placed_objects()` now skips y>100 entries
(interior-space) and `InteriorManager._restore_decorations()` re-spawns them
into the right interior on next entry.

**Piece-by-piece house building (4.3) MVP is done** — `wall_wood`,
`floor_wood`, `door_wood` (`src/data/databases/item_database.gd`, Workbench
recipes in `recipe_database.gd`). Plain `PlaceableObject`s, real world-space
collision, no interior teleport. `door_wood` sets `placeable_is_gate = true`
and reuses the existing fence-gate hinge/open-close code as-is — didn't need
anything new for that part. Models are in `roots/assets/Placeables/
{wall,floor,door}_wood.blend`, built via Blender MCP. **Follow-up scope, not
started:** roof pieces (needs corner/ridge/edge variants for a real sloped
roof — `floor_wood` tiles work as a flat-roof stopgap for now), window
pieces, and a wall-with-doorway variant (today `door_wood` just stands where
a `wall_wood` would, it doesn't inset into one).

**Blender-MCP gotcha found building these:** `bpy.ops.mesh.primitive_cube_add(size=1)`
makes a 1×1×1 cube (±0.5), and `obj.scale` multiplies that directly — so
`scale.x` IS the final edge length, not a half-extent. Assumed the opposite
at first (as if `size=1` meant a 2-unit cube), which quietly built a wall
panel at half the intended size in two axes; only caught because the
diagonal braces' geometry happened to dominate the bounding box and look
*approximately* right in the viewport screenshot. Always check
`object.dimensions` against the real-world target after scaling a primitive
— don't trust the screenshot alone when exact size matters (grid-snapping,
collision).

**Seasonal animal migrations (4.4) is done** — `WILD_SPAWN_RULES` in
`main_world.gd` gained an optional per-species `"seasons"` array
(`GameManager.Season` ints; omitted = year-round). `_migrate_wildlife()`,
called from `_on_season_changed()`, re-rolls every currently-loaded chunk
(despawn+respawn via the existing `_despawn_wildlife_for_chunk`/
`_spawn_wildlife_for_chunk` — same pattern as the night-enemy-wave
despawn/respawn) and diffs before/after species sets to fire a "Wildlife
Migration" notification. Season assignments: Deer/Duck Spring–Autumn (gone
Winter), Boar Summer–Winter (gone Spring), Wolf Autumn–Winter only, Goat
Spring–Summer only, Rabbit year-round.

**Environmental hazards (4.5) is done** — three hazards, none of which
existed before (fall/weather/trap damage was previously confirmed to be
zero anywhere in the codebase):
- **Fall damage** (`player_controller.gd`): `_fall_peak_y` tracks the
  highest point reached while airborne (updated in `_apply_gravity`);
  `_handle_fall_landing()` fires on the not-grounded→grounded transition.
  5m safe height, 5 dmg/m, capped at 50 — deliberately can't be lethal on
  its own, this is a cozy game.
- **Lightning strikes** during Storm weather (`weather_effects.gd`,
  `_tick_hazards`/`_strike_lightning`): random 8–18s interval, bright
  fading `OmniLight3D` flash at a random point near the player, damages
  (18 dmg) only within a 3m "danger radius" of the strike.
- **Cold exposure** during Snow weather: flat 2 HP/5s drain the whole time
  it's snowing. **No warmth/escape mechanism yet** (no campfire-proximity
  or clothing check) — revisit if it feels too punishing in real play.

Found and fixed two real bugs while testing this: the lightning
danger-radius damage path was mathematically unreachable (the random
strike-distance range's *minimum* already exceeded the danger radius, so
close strikes could never actually roll), and the flash light hit the same
"set global_position before add_child" ordering bug documented earlier in
this file for the HouseObject work — check for that pattern specifically
whenever spawning a Node3D and immediately positioning it.

**Bugfix (Aug 2026): loading screen was closing 5-15s early.**
`_on_terrain_ready()` in `main_world.gd` calls ~24 world-setup functions
(village building, NPC/animal/enemy spawning, several UI panels, save-data
loading) then hides the loading screen. ~13 of those functions internally
`await get_tree().process_frame` (or a timer) but were being called
*without* `await` from `_on_terrain_ready()`. Calling an async function
without awaiting it in GDScript fires it and moves on immediately — it does
not block. So `_hide_loading_screen()` ran almost instantly while village
building (the heaviest single piece) and everything else were still queued,
and the player watched all that setup happen in bursts for 5-15s with the
loading screen already gone — looked like a frozen/hitching game. Fixed:
added `await` to every call in that sequence that's an actual coroutine.
**If you add an `await` inside any of those setup functions later, you must
add `await` to its call in `_on_terrain_ready()` too, or this comes right
back** — there's a comment at the call site as a tripwire. General lesson:
in this codebase, a function starting with `await get_tree().process_frame`
is a strong signal to check whether its caller awaits it.

**Natural disasters (4.5) is done — Phase 4 is now fully complete.**
Windstorm: a rarer escalation of Storm weather (`weather_effects.gd`,
`_maybe_start_windstorm`/`_end_windstorm`/`_grant_storm_debris`), 20% chance
per fresh storm, 45-75s duration. Player slowed to 75% speed (reuses the
existing "speed" buff — same mechanism a Speed Potion uses, just <1.0) with
periodic free wood as a cozy silver lining. Found and fixed a real bug:
`_end_windstorm()` only cleared its own flag and didn't explicitly remove
the speed buff, so ending early (e.g. the underlying storm weather itself
ending before the windstorm's own timer) left the player slowed after the
"windstorm has passed" notification already said otherwise — fixed by
calling `player._remove_buff("speed")` explicitly instead of trusting the
buff's own timer to line up.

Every Phase 4 section (4.1 Biome, 4.2 NPC, 4.3 Settlement, 4.4 Wildlife, 4.5
Environmental, 4.6 Quest) is checked off now except the deliberately-deferred
piece-by-piece-building follow-ups noted below. Next project-wide work is
Phase 5 (Multiplayer Depth — GD-Sync framework exists but nothing in it is
wired for real multi-user play) or Phase 6 (Polish & Content — art, audio,
QoL, endgame), both fully unstarted; see `plans/roots_game_plan.md` for the
full section breakdowns.

**Remaining follow-ups (not gaps, deliberately deferred):**
- Roof/window pieces + wall-doorway variant for piece-by-piece building (4.3)
- Cold exposure warmth/escape mechanism (4.5 — see note above)

**Pre-playtest smoke test (Aug 2026) — see `docs/playtest_notes.md` for the
full pass.** Two real findings, both fixed:
1. `player_controller.gd`'s `_give_starting_items()` had regressed to a
   leftover full "testing" kit (own code comments said "for testing"),
   completely bypassing the documented Stone-tier bootstrap (3.1). Restored
   to exactly 4 small_stone + 3 stick; verified spawn → craft Stone Hoe at
   HAND station works end-to-end. **If you ever need a full item set for
   testing again, do it via `godot_exec`/a debug-only path — don't add it
   back into `_give_starting_items()`, that's what caused this.**
2. Controls docs said "I" for Inventory; the actual (and intended) key is
   Tab, which also opens Character together. `roots/README.md` fixed to
   match. The `InputMap`'s `"inventory"` action (bound to I) is unused dead
   code — harmless, left as-is.
