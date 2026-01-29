# Roots - Cozy Farming Game

A peaceful multiplayer farming simulation built with Godot 4.7, featuring procedurally generated low-poly worlds, multiple professions, and pure co-op gameplay.

## Features

### Core Gameplay
- **Exploration** - Discover multiple biomes and settle wherever you choose
- **Farming** - Grow crops, raise animals, and build your perfect farm
- **Professions** - Choose from 7 unique professions:
  - Cultivation (Farming)
  - Resource Gathering
  - Blacksmithing
  - Cooking & Baking
  - Husbandry (Animal Care)
  - Alchemy
  - Herb Gathering
- **Skill System** - Gain experience through actions and unlock perks

### Multiplayer
- Pure co-op gameplay with friends
- GD-Sync integration for seamless multiplayer
- Shared world state and synchronized progression

### World
- Procedurally generated biomes
- Dynamic weather and day/night cycle
- Living NPCs and wildlife
- Seasonal changes

## Getting Started

### Prerequisites
- Godot Engine 4.7 or later
- GD-Sync addon (included)

### Installation
1. Clone the repository
2. Open the project in Godot 4.7+
3. Run the project (F5)

### Controls
| Action | Keyboard | Gamepad |
|--------|----------|---------|
| Move | W/A/S/D | Left Stick |
| Jump | Space | A |
| Interact | E | X |
| Crouch | C | B |
| Toggle First Person | T | Y |
| Inventory | I | Select |
| Pause | Esc | Start |

## Project Structure

```
roots/
├── src/
│   ├── core/
│   │   ├── singletons/       # Autoloaded global scripts
│   │   │   ├── game_manager.gd
│   │   │   ├── event_bus.gd
│   │   │   ├── save_manager.gd
│   │   │   └── settings.gd
│   │   └── utils/
│   ├── main/
│   │   ├── menu/             # Main menu scenes
│   │   └── world/            # Main game world
│   ├── player/               # Player controller and scenes
│   ├── ui/                   # UI components and HUD
│   ├── world/
│   │   ├── terrain/          # Terrain generation
│   │   ├── chunks/           # Chunk management
│   │   ├── biomes/           # Biome definitions
│   │   ├── structures/       # Building structures
│   │   └── props/            # World props and decorations
│   ├── entities/
│   │   ├── npcs/             # NPC logic
│   │   ├── animals/          # Farm animals
│   │   └── wildlife/         # Wild animals
│   ├── items/                # Item definitions
│   ├── skills/               # Skill system
│   ├── crafting/             # Crafting system
│   ├── data/                 # Databases and configs
│   └── multiplayer/          # Multiplayer systems
├── plans/                    # Design documents
├── addons/GD-Sync/           # Multiplayer framework
└── GD-SyncTemplates/         # GD-Sync example templates
```

## Development Phases

1. **Phase 1: Foundation** (Weeks 1-8)
   - Project setup and configuration
   - Player controller with movement
   - Basic terrain generation
   - UI framework

2. **Phase 2: Core Mechanics** (Weeks 9-16)
   - Inventory system
   - Farming mechanics
   - Tool system
   - Skill system

3. **Phase 3: Professions** (Weeks 17-28)
   - All 7 professions implemented
   - Crafting stations
   - Recipe system

4. **Phase 4: World & Exploration** (Weeks 29-40)
   - Multiple biomes
   - NPC system
   - Settlement mechanics
   - Wildlife

5. **Phase 5: Multiplayer** (Weeks 41-52)
   - Full GD-Sync integration
   - Social features
   - World events

6. **Phase 6: Polish** (Ongoing)
   - Art assets
   - Audio design
   - Quality of life features

## Technical Details

- **Engine:** Godot 4.7 (Forward Plus renderer)
- **Physics:** Jolt Physics
- **Multiplayer:** GD-Sync
- **Scripting:** GDScript 2.0
- **Save System:** JSON + GD-Sync cloud

### Performance Considerations
- Chunk-based world generation
- Object pooling for frequently spawned items
- LOD system for distant terrain
- Level of detail for models

## Contributing

As a solo developer project, contributions are welcome but should align with the development plan. Please open an issue to discuss major changes.

## License

This project is proprietary software. All rights reserved.

## Acknowledgments

- [GD-Sync](https://www.gd-sync.com) - Multiplayer framework
- [Godot Engine](https://godotengine.org) - Game engine
- [Jolt Physics](https://github.com/jrouwe/JoltPhysics) - Physics engine

---

*Built with ❤️ for peaceful gaming*
