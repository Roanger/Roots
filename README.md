# Roots

A cozy multiplayer farming simulation built with **Godot 4.7**, featuring procedurally generated smooth low-poly worlds, farming, crafting, animal husbandry, combat, and pure co-op via GD-Sync.

**Repository:** [https://github.com/Roanger/Roots.git](https://github.com/Roanger/Roots.git)  
**Contact:** roanger@yahoo.com

---

## Quick Start

1. **Clone the repo**
   ```bash
   git clone https://github.com/Roanger/Roots.git
   cd Roots
   ```

2. **Open in Godot**
   - Open Godot 4.7+
   - Import the project from the `roots/` folder (contains `project.godot`)

3. **Run**
   - Press **F5** to run from the main menu.

The main scene is `roots/src/main/menu/main_menu.tscn`.

---

## Project Layout

| Path | Description |
|------|-------------|
| `roots/` | Godot project (scenes, scripts, assets) |
| `roots/project.godot` | Open this in the Godot editor |
| `roots/src/` | All game code (player, world, UI, items, entities, etc.) |
| `plans/` | Design docs — see [roots_game_plan.md](plans/roots_game_plan.md) |

For controls and detailed structure, see [roots/README.md](roots/README.md).

---

## Current Status (Feb 2026)

Phases 1–4 are largely complete. The game has a full playable loop.

### What's Working
- ✅ **Smooth Heightmap Terrain** — 2D heightmap chunks with real physics collision (`StaticBody3D` + `ConcavePolygonShape3D`), threaded generation, seamless chunk stitching
- ✅ **Player** — `CharacterBody3D` with `move_and_slide`, gravity, jump, crouch, sprint, first/third person camera
- ✅ **Farming** — Hoe tilling (dark soil + FarmPlot spawn), planting, watering, growth stages, harvesting, crop drops
- ✅ **Shovel Digging** — 3×3 bowl depression with DUG vertex coloring *(visual polish in progress)*
- ✅ **Inventory & Hotbar** — Drag-and-drop between inventory, hotbar, and equipment slots
- ✅ **Crafting** — 40+ recipes across Workbench, Forge, Anvil, Alchemy Table, Cooking Fire
- ✅ **Tool System** — 5 tiers (Wood → Mythril), tool affinity per target type, durability
- ✅ **Skill System** — 7 professions, action-based XP, perk tree with synergy bonuses
- ✅ **Animals** — 8 species (Chicken, Cow, Sheep, Goat, Duck, Boar, Deer, Rabbit), feeding, petting, breeding, products
- ✅ **Fences & Placeables** — Fence/gate/post placement with ghost preview, 5 building types
- ✅ **Enemies** — 4 Skeleton types with AI (idle/wander/chase/attack), loot drops, XP
- ✅ **Herb Gathering & Alchemy** — 9 harvestable herbs, 6 potions with timed buff system
- ✅ **Cooking** — 14 recipes, food buffs (well_fed, speed, strength, heal-over-time)
- ✅ **NPCs** — 8 village NPCs with dialogue trees, shops (gold coin currency), quest giving
- ✅ **Quest System** — 25 quests across multiple chains, journal UI, HUD tracker
- ✅ **Village** — Procedural medieval village (MegaKit modular buildings, town well, market stalls)
- ✅ **Day/Night & Seasons** — BinbunSky shader, seasonal sky/fog variation, in-game clock UI
- ✅ **World Items** — `RigidBody3D` drops with proximity auto-pickup, not pushed by player

### In Progress
- ⚠️ Shovel digging visual polish (bowl shape works, refinement needed)
- ⚠️ GD-Sync multiplayer lobby (framework integrated, not yet wired)

---

## Tech

- **Engine:** Godot 4.7 (Forward+, Jolt Physics)
- **Multiplayer:** GD-Sync
- **Scripting:** GDScript 2.0
- **Terrain:** 2D heightmap chunks, `WorkerThreadPool` async generation
- **Physics:** `CharacterBody3D` (player/AI), `RigidBody3D` (items), `StaticBody3D` (terrain/objects)

---

*Peaceful farming, built with care.*
