# Terrain Rewrite Implementation Plan (Voxel → Smooth Heightmap)

## Overview
This document outlines the step-by-step process for transitioning the *Roots* overworld from a 3D Voxel Engine to a 2D Smooth Heightmap Grid. This pivot will improve AI pathfinding, simplify building/farming placement, and better align with the game's cozy, low-poly aesthetic.

---

## Status Summary (Feb 2026)

| Phase | Status |
|-------|--------|
| Phase 1: Strip Voxel Systems | ✅ Complete |
| Phase 2: Heightmap Generation & Physics | ✅ Complete |
| Phase 3: Player & AI Physics Update | ✅ Complete |
| Phase 4: Interactions & Visuals | ✅ Mostly Complete |
| Phase 4 – Digging visuals | ⚠️ In Progress — not yet correct |
| Phase 4 – Chunk seam stitching | ✅ Complete |

---

## Phase 1: Strip Voxel Systems ✅
**Goal:** Remove all 3D array overhead and voxel-specific logic without breaking the game's core loop.

1. **`chunk_data.gd`** ✅
   - Removed the `voxels` 3D `PackedByteArray` and all `VOXEL_*` constants.
   - Replaced with a `heights` 2D `PackedFloat32Array` (size: `chunk_size * chunk_size`).
   - Removed `get_voxel()`, `set_voxel()`, `get_surface_local_y()`, and 3D digging logic.
2. **`chunk_manager.gd`** ✅
   - Removed `_generate_chunk_data`'s 3D voxel fill loop, cave carving, and 3D ore noise sampling.
   - Removed `_build_voxel_mesh_data` (the complex 6-face vertex builder).
   - Removed voxel-specific visual updates.
3. **`noise_utilities.gd`** ✅
   - Kept 2D surface noise (elevation, detail, moisture, temperature).
   - Removed 3D cave and ore noise generators.

---

## Phase 2: Heightmap Generation & Physics ✅
**Goal:** Generate a rolling green landscape with real Godot physics collision.

1. **Grid Mesh Generation (`chunk_manager.gd`)** ✅
   - `_build_heightmap_mesh_data(chunk, nu, excl_zones)` generates a grid of `sz × sz` quads.
   - Flat normals for low-poly faceted look.
   - Vertex colors based on biome via `_get_terrain_vertex_color()`.
   - `CULL_DISABLED` on terrain material to prevent see-through on steep slopes.
2. **Physics Collision** ✅
   - `StaticBody3D` + `ConcavePolygonShape3D` (trimesh from mesh) per chunk.
   - Collision layer 1 (Terrain).
3. **Performance/Threading** ✅
   - `WorkerThreadPool` architecture retained.
   - Background threads generate heightmap + `ArrayMesh`; main thread calls `add_child`.
4. **Chunk Seam Stitching** ✅
   - Edge vertices sample noise directly (`_sample_height_at_world`) so adjacent chunk boundaries always match.

---

## Phase 3: Player & AI Physics Update ✅
**Goal:** Rip out manual raycast/height-query grounding and use standard Godot physics.

1. **Player (`player_controller.gd`)** ✅
   - Uses `move_and_slide()` with gravity. `is_on_floor()` works for jumping.
   - All `chunk.get_world_height()` references removed.
2. **Animals & Enemies (`base_animal.gd`, `base_enemy.gd`)** ✅
   - `_snap_to_terrain()` removed. Standard gravity + `move_and_slide()`.
3. **NPCs (`base_npc.gd`)** ✅
   - Standard gravity + `move_and_slide()`. `collision_mask = 1` for terrain.
4. **World Items (`world_item.gd`, `world_item.tscn`)** ✅
   - `RigidBody3D` with `collision_mask = 1` (terrain only — not pushed by player).
   - `PickupArea` (Area3D) detects player for looting.

---

## Phase 4: Interactions & Visuals ✅ (Mostly)
**Goal:** Re-integrate farming, gathering, and terrain modifications.

1. **Object Spawning (`chunk_manager.gd`)** ✅
   - Trees, rocks, grass, bushes, and biome decorations use `heights` array for Y-positioning.
   - No `VOXEL_Y_OFFSET` needed.
2. **Terrain Modification — Tilling (Hoe)** ✅
   - `modify_terrain_at()` sets `TileMod.TILLED` and rebuilds mesh with dark soil vertex color.
   - `FarmPlot` spawned at tilled position.
3. **Terrain Modification — Digging (Shovel)** ⚠️ *In Progress*
   - `dig_terrain_at()` digs a 3×3 bowl (center −0.8, ring −0.3) and sets `TileMod.DUG`.
   - Mesh rebuilds with dark earth color on dug cells and adjacent walls.
   - **Known issues:** Visual depression is functional but not fully polished. Steep single-vertex digs previously caused see-through holes (fixed with `CULL_DISABLED` + bowl shape). Further visual refinement needed.
4. **Farm Plots** ✅
   - `FarmPlot` spawns at correct world height. Tilled plots restored on chunk reload.
5. **Ores & Caves**
   - Ore nodes spawn as surface rocks in Mountain biomes. ✅
   - Instanced Mine/Cave scenes: planned for later.

---

## Known Issues / Next Steps

- **Digging visuals** — The 3×3 bowl approach prevents see-through holes but the depression shape and coloring still needs refinement. Consider: smoother falloff, particle effects on dig, or a dedicated "dirt pile" mesh.
- **Chunk seams on rebuild** — After `_rebuild_chunk_mesh()` (dig/till), edge stitching uses `noise_util` (main thread). Verify seams remain correct after modifications near chunk boundaries.
- **Caves** — Planned as instanced scenes, not yet implemented.
- **NavMesh** — AI navigation mesh generation not yet wired to new heightmap terrain.
