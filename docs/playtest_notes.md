# Roots — Playtest Notes (Aug 9, 2026)

Written after a headless build check + a live smoke test through the real
main-menu → New Game → world flow (via Godot MCP), immediately following the
Phase 4 completion pass. Share this with playtesters as a "what to expect"
guide.

## What was verified working

- Fresh boot → main menu → "New Game" confirmation dialog → character select
  → world load, end to end, with no errors in the log.
- **Loading screen timing** (this session's bugfix): the loading screen now
  correctly stays up until the world is actually fully populated — village,
  NPCs, wildlife, UI all present within ~1s of it closing. No more
  frozen/hitching feeling after it disappears.
- World population: village (34 building nodes), all 8 NPCs, wildlife
  (rabbits, ducks visible near spawn), HUD (health/stamina/minimap/clock/quest
  tracker) all present immediately.
- Player movement + camera look.
- Inventory (`Tab`) and Character panel (opens together), including the Tool
  1/2/3 equipment slots added this session for profession equipment.
- Crafting menu (`R`): recipe list, category tabs, ingredient/output display,
  full craft flow (timer → ingredients consumed → item granted → skill XP
  awarded) — tested end-to-end with Wooden Planks.
- Tool swing / combat: axe hit correctly reduced a tree's health via
  `HarvestableResource`.
- Farming: hoe correctly tilled soil and spawned a new `FarmPlot`.
- NPC interaction → dialogue UI → shop dialogue options.
- Save: `save_game()` succeeded and wrote a real save file with populated
  `claims`, `farm_plots`, `placed_objects`, `reputation`, `terrain`, `weather`,
  `player_data` sections.
- No errors in the editor/engine log across the entire test session.

## Fixed this session (found during the smoke test, then corrected)

1. **Starting inventory now matches the documented design.** It had drifted
   to a leftover "testing" kit (comments in the code literally said "for
   testing") — Wood-tier tools, 10 wheat seeds, 10 wood logs, 10 stone, 10
   string, 5 coal, 9 iron nuggets, herbs, potions, and fence pieces — which
   completely skipped the Stone-tier bootstrap progression Phase 3.1 was
   built around. `player_controller.gd`'s `_give_starting_items()` now gives
   exactly what the plan says: 4 small_stone + 3 stick, nothing else.
   Verified live: fresh spawn has exactly that, and hand-crafting a Stone Hoe
   from it at the HAND station works end-to-end (consumes 2 small_stone + 1
   stick as the recipe specifies).
2. **Controls docs now say Tab, not I, for Inventory.** The game's actual
   behavior (Tab opens Inventory + Character together) was correct and is
   the intended design — the docs were wrong. `roots/README.md`'s controls
   table updated to match. (The `InputMap`'s dead `"inventory"` action bound
   to physical key I is still unused/inert — left as-is, harmless.)

## Minor / cosmetic (not blocking)

- A `Node3D` `is_inside_tree()` engine warning fires when tilling soil (new
  `FarmPlot` spawn) — pre-existing code, not something touched this session.
  Didn't stop the plot from spawning correctly; likely a `global_position`
  set before `add_child()` ordering issue, same class of bug fixed elsewhere
  this session (house placement, lightning flash) but not chased down here
  since it's cosmetic and harmless.

## Known gaps (already documented, listed here for tester context)

- **Multiplayer isn't wired up** — GD-Sync framework is present but nothing
  uses it for real multi-user play yet. Each tester needs their own
  single-player session.
- **Cold exposure** (Snow weather, new this session) has no warmth/escape
  mechanism — it's a flat drain the whole time it snows. Watch for feedback
  on whether this feels too punishing over a long session.
- **Piece-by-piece building** has wall/floor/door pieces only — no roof yet
  (flat floor tiles work as a stopgap), no window pieces, and a door doesn't
  inset into a wall gap (it just stands where a wall would).
- **Fall damage / lightning / windstorm** balance is untested by real
  players — numbers were tuned by feel (capped fall damage, 3m lightning
  danger radius, 25% windstorm slow) during this session's implementation.
  Good candidates for early feedback.
- Terrain v2's generator-graph flatten-zone blending is still deferred — CPU
  gameplay queries (village placement, building flatten) are correct, but
  the voxel terrain mesh itself can show raw, unflattened heights in that
  blend region on close inspection.

## Suggested playtest focus areas

Given the above, if you want testers' time to be maximally useful, point
them at:
- The starting-item/Stone-tier bootstrap question above (do they even
  notice/care, now that it's skipped?)
- The new housing systems: crafting a `house`, decorating the interior,
  and/or building with `wall_wood`/`floor_wood`/`door_wood` pieces outdoors.
- Environmental hazards and the windstorm disaster, specifically for balance
  feedback (too punishing / not enough stakes / just right).
- General core loop (farm → craft → profession progression → combat) for
  anything that feels unfinished or confusing.
