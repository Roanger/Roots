# Roots - Cozy Farming Game

A peaceful multiplayer farming simulation built with Godot 4.7, featuring procedurally generated smooth low-poly worlds, multiple professions, and pure co-op gameplay.

## Features

### Core Gameplay
- **Exploration** — Discover 9+ biomes (Plains, Forest, Desert, Taiga, Mountains, Snow, Swamp, Beach, Highland) and settle wherever you choose
- **Farming** — Till soil with a hoe, plant seeds, water crops, harvest at full growth, recover seeds
- **Digging** — Shovel carves persistent SDF terrain deformation via `VoxelTool.do_sphere()`, saved across restarts
- **Professions** — 7 professions with action-based XP and perk trees:
  - Cultivation (Farming)
  - Resource Gathering (Mining, Lumberjack, Foraging)
  - Blacksmithing (Forge, Anvil)
  - Cooking & Baking
  - Husbandry (Animal Care)
  - Alchemy
  - Herb Gathering
- **Skill System** — Gain XP through actions, spend skill points on profession perks, synergy bonuses for dual/triple disciplines
- **Combat** — Melee weapons (sword, axe, dagger), 4 enemy types, loot drops

### World
- Smooth voxel terrain (`VoxelLodTerrain` via godot_voxel/Voxel Tools 1.6) with Transvoxel SDF meshing, real rivers/lakes, and a 10-biome shader
- Native LOD/streaming/collision, persistent digging via `VoxelStreamSQLite`
- Loading screen with seed display; spawns gated behind terrain-collision readiness
- Procedural medieval village (8 NPCs, market stalls), dynamically placed on dry land
- Day/night cycle with seasonal sky/fog variation
- In-game clock (time, day of week, season)
- Menu/world music system with dedicated audio bus and volume slider

### Animals & Husbandry
- 8 species: Chicken, Cow, Sheep, Goat, Duck, Boar, Deer, Rabbit
- Feed, pet, and breed animals — babies spawn from two fed adults
- Products on timers: eggs, milk, wool
- Fence/gate/post placement system with ghost preview

### NPCs & Quests
- 8 village NPCs: Shopkeeper, Innkeeper, Blacksmith, Baker, Mayor, Herbalist, Farmer, Guard
- Dialogue trees, shops (gold coin currency), quest giving and turn-in
- 25 quests across multiple chains with journal UI and HUD tracker

### Multiplayer
- Pure co-op via GD-Sync *(lobby wiring in progress)*

---

## Getting Started

### Prerequisites
- Godot Engine 4.7 or later
- GD-Sync addon (included in `addons/`)

### Installation
1. Clone the repository
2. Open `roots/project.godot` in Godot 4.7+
3. Press **F5** to run

### Controls

| Action | Key |
|--------|-----|
| Move | W / A / S / D |
| Jump | Space |
| Sprint | Shift |
| Crouch | C |
| Interact / Use Tool | Left Click |
| Interact with NPC/Object | E |
| Toggle First/Third Person | T |
| Inventory / Character | Tab |
| Crafting | R |
| Skill Tree | K |
| Quest Journal | J |
| Hotbar slots | 1–8 |
| Pause | Esc |

---

## Project Structure

```
roots/
├── src/
│   ├── core/
│   │   └── singletons/       # Autoloads: GameManager, EventBus, SaveManager, SkillManager, QuestManager
│   ├── main/
│   │   ├── menu/             # Main menu scene
│   │   └── world/            # main_world.gd — world setup, NPC/animal/enemy spawning
│   ├── player/               # player_controller.gd, camera, farming, tool swing
│   ├── ui/                   # HUD, inventory, hotbar, crafting, skill tree, quest journal, dialogue, shop
│   ├── world/
│   │   ├── terrain_v2/        # terrain_service.gd (VoxelLodTerrain facade), world_noise.gd, world_object_spawner.gd
│   │   ├── crops/             # farm_plot.gd, crop growth
│   │   ├── biomes/, props/, structures/, town_buildings/, interiors/
│   │   └── harvestable_resource.gd
│   ├── entities/
│   │   ├── npcs/             # base_npc.gd, npc_data.gd
│   │   ├── animals/          # base_animal.gd, animal_data.gd
│   │   └── base_enemy.gd
│   ├── items/                # item_data.gd, world_item.gd, tool_affinity.gd
│   ├── data/
│   │   └── databases/        # ItemDatabase, CropDatabase, RecipeDatabase, QuestDatabase
│   └── skills/               # skill_manager.gd, perk_data.gd
├── addons/
│   ├── GD-Sync/              # Multiplayer framework
│   └── zylann.voxel/         # Voxel Tools (godot_voxel) 1.6 GDExtension
└── plans/                    # Design docs (roots_game_plan.md, terrain_rewrite_plan.md)
```

---

## Technical Details

- **Engine:** Godot 4.7 (Forward Plus renderer)
- **Physics:** Jolt Physics — `CharacterBody3D` (player/AI), `RigidBody3D` (world items), native voxel collision (terrain)
- **Terrain:** `VoxelLodTerrain` (godot_voxel/Voxel Tools 1.6 GDExtension), Transvoxel smooth SDF meshing
- **Multiplayer:** GD-Sync
- **Scripting:** GDScript 2.0
- **Save System:** `VoxelStreamSQLite` for terrain/digging modifications; player data via SaveManager

---

## License

This project is proprietary software. All rights reserved.

## Acknowledgments

- [GD-Sync](https://www.gd-sync.com) — Multiplayer framework
- [Godot Engine](https://godotengine.org) — Game engine
- [Jolt Physics](https://github.com/jrouwe/JoltPhysics) — Physics engine

---

*Built with ❤️ for peaceful gaming*
