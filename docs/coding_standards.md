# Roots - Coding Standards & Conventions

## File Organization

```
roots/
├── src/
│   ├── core/          # Singletons, global systems
│   ├── data/          # Databases, resources
│   ├── items/         # Inventory, equipment classes
│   ├── main/          # Main scenes (menu, world)
│   ├── player/        # Player controller, camera
│   ├── ui/            # All UI components
│   └── world/         # Chunks, terrain, crops
└── assets/            # Art, audio, fonts
```

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Files | `snake_case` | `player_controller.gd` |
| Classes | `PascalCase` | `class_name PlayerController` |
| Functions | `snake_case` | `func get_terrain_height()` |
| Variables | `snake_case` | `var current_health` |
| Constants | `UPPER_SNAKE` | `const MAX_SLOTS = 36` |
| Signals | `snake_case` | `signal health_changed` |
| Enums | `PascalCase` (type), `UPPER_SNAKE` (values) | `enum State { IDLE, WALKING }` |

## GDScript Style

### Type Hints
Always use type hints for function parameters and return values:
```gdscript
func add_item(item: ItemData, quantity: int = 1) -> int:
    return overflow_count
```

### Signals
Define signals at the top of the file, after extends:
```gdscript
extends Node
class_name MyClass

signal something_happened(value: int)
signal state_changed(new_state: State)
```

### Export Variables
Group exports at the top, use meaningful ranges:
```gdscript
@export var max_health: float = 100.0
@export_range(0, 10) var damage_multiplier: float = 1.0
```

### Private Functions
Prefix private functions with underscore:
```gdscript
func _internal_calculation() -> void:
    pass

func public_method() -> void:
    _internal_calculation()
```

## Scene Organization

### Node Naming
- Use `PascalCase` for node names
- Be descriptive: `HealthBar` not `PB1`

### Scene Structure
```
Root
├── UI/
│   ├── HUD
│   └── InventoryUI
├── World/
│   ├── TerrainContainer
│   └── ChunkManager
└── Player
```

## Comments

### Function Documentation
```gdscript
## Calculates terrain height at the given world position.
## Returns 0.0 if chunk is not loaded.
func get_terrain_height(world_pos: Vector3) -> float:
```

### Section Headers
```gdscript
# =====================
# MOVEMENT SYSTEM
# =====================
```

## Best Practices

1. **Avoid magic numbers** - Use constants or exports
2. **Single responsibility** - One class, one purpose
3. **Signal over direct calls** - Loose coupling
4. **Null checks** - Always validate node references
5. **Deferred calls** - Use `call_deferred()` for scene modifications
