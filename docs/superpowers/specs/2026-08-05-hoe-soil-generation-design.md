# Hoe Tool → Soil Terrain Generation

**Date:** 2026-08-05
**Status:** Approved

## Overview

When the player uses the hoe tool, a single soil tile is generated on `SoliLayer` at the tile directly in front of the player. The tile is only placed if grass exists on `GrassLayer` at that coordinate and no soil is already present.

## Architecture

Two changes across existing files:

### 1. `player.tscn` — Add `hoe_use` method track

Each of the 4 hoe animations needs a `method` track calling `hoe_use` at 0.4s, matching the pattern already used by axe animations (`axe_use`).

Animations to modify:
- `hoe_down`
- `hoe_up`
- `hoe_left`
- `hoe_right`

### 2. `player.gd` — Implement `hoe_use()` method

```
hoe_use():
  1. Get references to GrassLayer and SoliLayer (via scene tree)
  2. Calculate target tile coordinate:
     player_global_pos + last_direction * 16px → TileMapLayer.local_to_map()
  3. Check GrassLayer.get_cell_tile_data(target_coords) — skip if nil
  4. Check SoliLayer.get_cell_source_id(target_coords) — skip if already soil
  5. SoliLayer.set_cell(target_coords, source_id=0, atlas_coords=Vector2i(0,0), terrain=0)
```

### Key Detail: Tile Coordinate

Tile size is 16×16px. Player world position is converted to tilemap-local coordinates before calling `local_to_map()`.

## Data Flow

```
Animation track (0.4s)
  → hoe_use()
    → TileMapLayer.local_to_map(player_pos + last_direction * 16)
    → GrassLayer check: has tile?
    → SoliLayer check: already soil?
    → SoliLayer.set_cell(target, 0, Vector2i(0,0), 0)
```

## What Stays the Same

- Grass tiles remain untouched on `GrassLayer`
- Water, Hills, Trees, Player movement/animation unchanged
- Existing tool switching and one-shot animation system unchanged
