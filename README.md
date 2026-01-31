# Roots

A cozy multiplayer farming simulation built with **Godot 4.7**, featuring procedurally generated low-poly worlds, farming, crafting, and pure co-op via GD-Sync.

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
   - Import or open the project: use the `roots` folder (contains `project.godot`)

3. **Run**
   - Open `roots/project.godot` in Godot, then press **F5** to run.

The main game scene is `roots/src/main/menu/main_menu.tscn` (loaded as main in project settings).

---

## Project Layout

| Path | Description |
|------|-------------|
| `roots/` | Godot project (engine, scenes, scripts, assets) |
| `roots/project.godot` | Godot project file — open this in the editor |
| `roots/src/` | Game code (player, world, UI, items, etc.) |
| `plans/` | Design docs and [roots_game_plan.md](plans/roots_game_plan.md) |

For more detail (controls, structure, phases), see [roots/README.md](roots/README.md).

---

## Status

- **Phase 1 (Foundation):** Mostly complete — player, camera, terrain, chunks, water, fog, main menu, pause, inventory slots.
- **Phase 2 (Core Mechanics):** In progress — inventory UI, hotbar, character/equipment UI, farming (plant, grow, water, harvest). **Drag-and-drop between inventory/hotbar/equipment is now working!**

### Recent Updates (Jan 2026)
- ✅ Fixed item pickup bug (world items now properly destroyed after pickup)
- ✅ Implemented drag-and-drop system with Godot 4.7 workaround
- ✅ Items can be moved between inventory, hotbar, and equipment slots
- ⚠️ Equipment slot visuals need polish (items persist but icons not displaying)

Development plan and checklist: [plans/roots_game_plan.md](plans/roots_game_plan.md).

---

## Tech

- **Engine:** Godot 4.7 (Forward+)
- **Multiplayer:** GD-Sync
- **Scripting:** GDScript 2.0

---

*Peaceful farming, built with care.*
