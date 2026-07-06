# Terrain Rewrite Implementation Plan

> **Superseded (Jul 2026):** The heightmap terrain described below is being replaced by
> a smooth-SDF voxel terrain built on **Voxel Tools (godot_voxel) 1.6 GDExtension**.
> See the **Terrain v2 (godot_voxel) Rewrite** section at the bottom of this document.
> The historical heightmap plan is kept for reference.

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

---

# Terrain v2 (godot_voxel) Rewrite — Jul 2026

## Motivation
The heightmap terrain works for walking/farming but cannot support the full game vision:
the land shape is bland (blobby noise hills, no rivers/cliffs), water is flat chunk-local
quads, and shovel digging never worked as persistent deformation. Decision: rebuild on
**Voxel Tools (Zylann's godot_voxel) 1.6 GDExtension** with smooth Transvoxel meshing —
real SDF terrain with overhangs, robust digging, built-in LOD/streaming/collision, and a
path to caves, rivers, and swimming. Old saves are abandoned (fresh world format).

## Status

| Phase | Status |
|-------|--------|
| Phase 0: Install & validate godot_voxel | ✅ Complete |
| Phase 1: World generator (biomes, rivers, lakes) | ✅ Complete — tested in game |
| Phase 2: TerrainService facade + old chunk system removal | ✅ Complete |
| Phase 3: Water (global sea level, rivers) | ✅ Complete |
| Phase 4: Digging + persistence | ✅ Complete |
| Phase 5: Re-wire spawning, tilling, farm plots | ✅ Complete |

## Phase 0: Install & Validate ✅
- Installed **Voxel Tools 1.6 GDExtension** (built for Godot 4.4.1+) at
  `roots/addons/zylann.voxel/`. Confirmed all classes register on the custom
  Godot 4.7 beta build (`VoxelLodTerrain`, `VoxelGeneratorGraph`,
  `VoxelMesherTransvoxel`, `VoxelStreamSQLite`, `VoxelTool`, `VoxelInstancer`).
- Data-level test passed: `VoxelGeneratorNoise2D` → `VoxelBuffer` →
  `VoxelTool.do_sphere()` dig lowers the surface → `VoxelMesherTransvoxel`
  builds a mesh.
- Interactive test scene: `roots/src/world/terrain_v2/test/voxel_test.tscn`
  (F6: WASD+mouse fly-cam, left-click dig, right-click add, Esc frees mouse).

## Phase 1: World Generator
- New generator (GDScript `VoxelGeneratorScript` or `VoxelGeneratorGraph`) under
  `roots/src/world/terrain_v2/`, reusing elevation/moisture/temperature noise concepts
  but redesigned: river valleys carved below sea level, lakes, cliffs, mountain shaping.
- Biome classification stays CPU-side (thresholds on noise) for gameplay queries;
  terrain coloring moves from vertex colors to a shader (biome data via texture
  indices or world-position noise sampling).
- Flat-shaded low-poly look via material/shader on the Transvoxel mesh.

## Phase 2: TerrainService Facade ✅
- `terrain_v2/terrain_service.gd` — complete rewrite wrapping `VoxelLodTerrain` +
  `WorldNoise`. Preserves the old ChunkManager API for backward compat.
- `terrain_v2/terrain_service.tscn` — scene node holding the script. Replaces
  `chunks/chunk_manager.tscn` in `main_world.tscn`.
- **API surface supported:**
  - `get_terrain_height()` / `get_biome_at()` — via `WorldNoise` CPU queries
  - `get_tile_mod_at()` / `modify_terrain_at()` — tilling via `FarmPlot` overlay
  - `dig_terrain_at()` — shovel via `VoxelTool.do_sphere(MODE_REMOVE)`
  - `add_exclusion_zone()` — CPU-side flatten (graph-based flatten deferred)
  - `chunk_loaded`/`chunk_unloaded` signals — polled virtual-chunk approach
  - `force_update()` / `clear_all_chunks()` — no-ops (VLT is continuous)
- **Compatibility shims:** `terrain_container`, `chunk_save_dir`, `chunk_size`
  set on TerrainService are silently ignored (VLT manages meshes internally).
- **Known limitation:** The flatten-zone nodes in the `VoxelGeneratorGraph`
  (`NODE_MIX`, `NODE_SMOOTHSTEP`) produce incorrect terrain — the blend
  region between flattened and natural height is not matching the CPU math.
  Deferred to Phase 5 when generator spawning is re-wired.
- `main_world.gd` updated: removed `terrain_container`, `chunk_save_dir`, and
  `force_update()` wiring to the old chunk manager.
- **Callers unchanged:** `player_controller.gd`, `base_animal.gd`,
  `town_builder.gd`, `base_enemy.gd`, `settings.gd` work with the new facade
  via duck-typing on the same method names. No caller changes needed.
- The old `chunks/chunk_manager.gd` + `chunk_data.gd` remain in the tree for
  reference but are no longer wired into the scene.

## Phase 3: Water ✅
- `_create_water_plane()` in `main_world.gd`: large `PlaneMesh` (2000×2000) at y=0
  (sea level), following the player in `_process` so it stays centered on camera.
- Uses the existing `water_shader.gdshader` (depth-based color, shoreline foam,
  Fresnel sky reflection, specular sun sparkle, wave vertex displacement).
- `SHADOW_CASTING_SETTING_OFF` since it's transparent.
- Global shader uniforms `sun_direction` + `sun_color` already set up by
  `_setup_water_shader_globals()` — no changes needed.
- Swimming/buoyancy hooks deferred to a future pass.

## Phase 4: Digging + Persistence ✅
- Shovel → `VoxelTool.do_sphere()` (MODE_REMOVE, radius 2.5) — real persistent SDF
  deformation wired through `terrain_service.dig_terrain_at()`.
- `terrain_service.voxel_stream`: `VoxelStreamSQLite` at
  `user://saves/world_<seed>/voxels.sqlite`, `save_generator_output=false` (only
  modified blocks are stored).
- `save_modified_blocks()` called after each dig to flush to disk immediately.
- `save_modified_blocks()` also called in `_exit_tree()` for clean shutdown.
- Confirmed persistence across game restart: dug surface (y=2.0) survived
  a stop/start cycle; fresh worlds with no database fall back to the generator.
- Old per-chunk JSON save format (`chunks/`) no longer wired; `chunk_save_dir`
  is a no-op setter in the new facade.

## Phase 5: Re-wire Gameplay Systems ✅
- `WorldObjectSpawner` (`terrain_v2/world_object_spawner.gd`) — standalone node
  that listens to TerrainService `chunk_loaded`/`chunk_unloaded` signals and
  spawns/despawns world objects per virtual 32×32 chunk.
- Loads the same FBX scene pools as the old system (trees, rocks, pine, dead
  trees, pebbles, 3D grass, bushes, flowers, ferns, mushrooms, clovers).
- Each object has a `HarvestableResource` collision child for tool interaction
  (axes chop trees, pickaxes mine rocks, sickles harvest herbs).
- Biome-aware species selection, scale/rotation variation, and loot tables
  preserved from the old `chunk_manager.gd` logic.
- Exclusion zones suppress spawning in the village area.
- Fishing spots spawn in water biomes with `FishingSpot` nodes.
- **Tilling** unchanged — already works as overlay via `modify_terrain_at()`.
- **Wildlife/enemy/NPC** queries unchanged — already use `TerrainService`.
- **Known limitation:** The generator-graph flatten zone blend (`NODE_MIX` +
  `NODE_SMOOTHSTEP` + `NODE_DISTANCE_2D`) produces incorrect terrain in the
  blend region. Deferred: CPU queries (used for gameplay) still flatten
  correctly, but the voxel terrain shows raw heights.

## Out of Scope (post-rewrite follow-ups)
Caves, boats, waterfalls, swimming physics, NavMesh — enabled by this architecture
but tracked separately in `roots_game_plan.md`.
