# Harvest & Soil Auto-Revert Design

**Date:** 2026-08-06
**Status:** approved

## Overview

Two related features for the soil→crop→harvest lifecycle:

1. **Auto-harvest**: Player walks into a mature crop's Area2D → crop is harvested, position reverts to soil
2. **Soil auto-revert**: Unplanted soil tiles automatically revert to grass after a configurable idle period

## Constants

| Parameter | Value | Description |
|-----------|-------|-------------|
| `soil_dry_hours` | 6.0 | Wet soil → dry soil (changed from 12.0) |
| `soil_revert_hours` | 12.0 | Dry idle soil → grass (new) |

## Architecture

```
plant.gd                      game.gd
  ┌─────────────┐              ┌──────────────────────┐
  │ Area2D       │  harvested   │ _on_crop_harvested()  │
  │ body_entered ├─────────────►│   - 重置土壤空闲计时   │
  │ → 检测玩家   │  signal      │                        │
  │ → 检测成熟   │              │ _on_time_changed()     │
  │ → queue_free │              │   - 湿土→干土 (6h)     │
  └─────────────┘              │   - 干土→草地 (12h)    │
                               └──────────────────────┘
```

## Changes

### plant.gd

- `_ready()`: connect `$Area2D.body_entered` → `_on_body_entered`
- `_on_body_entered(body)`: if `body.name == "Player"` and `growth_stage >= max_stage`, emit `harvested(global_position)` → `queue_free()`
- New `signal harvested(world_pos: Vector2)`

### plant.tscn

- Area2D: `collision_layer = 0`, `collision_mask = 2` (player layer)

### game.gd

- `soil_dry_hours` default → `6.0` (was `12.0`)
- New `@export var soil_revert_hours: float = 12.0`
- New `_soil_idle: Dictionary` — `{coords: idle_start_hours}`
- `_handle_hoe()`: `_soil_idle[coords] = TimeManager.total_hours`
- `_handle_plant()`: `_soil_idle.erase(coords)`
- New `_on_crop_harvested(world_pos)`: compute coords; if soil is dry, start idle timer
- `_revert_to_soil()`: after revert, if no plant → `_soil_idle[coords] = TimeManager.total_hours`
- `_on_time_changed()`: add idle soil check → `_soil_layer.erase_cell(coords)` on timeout

## Soil Lifecycle State Machine

```
Grass ──[hoe]──► Dry Soil ──[plant]──► Occupied Soil
                     │                      │
                     │ [12h idle]           │ [water]
                     ▼                      ▼
                   Grass              Wet Soil (Occupied)
                                           │
                                           │ [harvest or no plant + 6h dry]
                                           ▼
                                       Dry Soil
                                           │
                                           │ [12h idle, no plant]
                                           ▼
                                         Grass
```
