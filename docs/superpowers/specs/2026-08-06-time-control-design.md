# Time Control & Day/Night System Design

**Date:** 2026-08-06
**Status:** Approved
**Reference:** Hearts of Iron IV time control mechanics

## Overview

Implement a game-time system inspired by HOI4's time control, with day/night cycle, integrated plant growth, and soil moisture drying.

---

## Part 1: TimeManager Core (Autoload)

### File: `globals/time_manager.gd`

Central autoload singleton managing all game-time state.

### Time Advancement

- Internal `Timer` ticks every 0.5s (frame-independent)
- Each tick accumulates `real_delta * speed_multiplier` into game time
- At 1x speed: 1 in-game day = 10 real-time minutes (`@export` adjustable via `real_seconds_per_day`)

### Speed Levels (HOI4 style, 5 speeds + pause)

| Index | Label | Key | Multiplier | Use Case |
|-------|-------|-----|------------|----------|
| 0 | Pause | `Space` | 0x | Plan layout, think |
| 1 | 1x | `1` | 1x | Normal operations |
| 2 | 2x | `2` | 2x | Light waiting |
| 3 | 3x | `3` | 4x | Wait for crops |
| 4 | 4x | `4` | 8x | Fast skip |
| 5 | 5x | `5` | 16x | Ultra fast-forward |

All multipliers are `@export` for editor adjustability.

### State Variables

```
day: int          # Day counter (starts at 1)
hour: int         # 0-23
minute: int       # 0-59
speed_index: int  # 0-5 (0 = paused)
is_paused: bool   # true when speed_index == 0
total_hours: float # Total elapsed game hours (accumulated, for drying calculations)
```

### Signals

- `time_changed(day: int, hour: int, minute: int)` — emitted every in-game minute
- `day_changed(new_day: int)` — emitted when day increments
- `speed_changed(speed_index: int)` — emitted on speed switch

---

## Part 2: Day/Night Visual Effect

### Implementation: `CanvasModulate` node

A `CanvasModulate` named `DayNightModulate` placed above all tilemaps and objects in `game.tscn`. Its `color` property is adjusted to create the day/night cycle.

### Color Schedule

| Period | Game Time | Color | Visual |
|--------|-----------|-------|--------|
| Deep Night | 0:00 – 5:00 | `(0.30, 0.35, 0.60)` | Darkest, blue-tinted |
| Dawn | 5:00 – 7:00 | Lerp transition | Sky brightens |
| Day | 7:00 – 17:00 | `(1.0, 1.0, 1.0)` | Full brightness |
| Dusk | 17:00 – 19:00 | Lerp transition | Sky darkens |
| Night | 19:00 – 24:00 | `(0.30, 0.35, 0.60)` | Dark, blue-tinted |

### Transition Logic

- Uses `lerp()` with normalized progress within dawn/dusk windows
- Colors and transition times are `@export` for editor tweaking
- Updates every frame in `_process` for smooth visual

---

## Part 3: Time UI

### File: `scenes/ui/time_ui.tscn` + `time_ui.gd`

`CanvasLayer` node added to the game scene, always on top.

### Layout

```
┌─────────────────────────────────────────────────┐
│         🌙 Day 3 · 14:30         [▶ 1x]        │
└─────────────────────────────────────────────────┘
```

- **Top-center:** Day and time display with day/night icon
- **Top-right:** Current speed indicator (shows `⏸ Paused` or `▶ Nx`)

### Interactions

| Action | Effect |
|--------|--------|
| `+` / `]` keys | Speed up one level |
| `-` / `[` keys | Speed down one level |
| `Space` | Toggle pause/resume |
| `1`–`5` keys | Jump to specific speed |

### Implementation

- Subscribes to `TimeManager.time_changed` and `speed_changed` signals
- Updates labels reactively
- Pause state shows visual distinction (dimmed display)

---

## Part 4: Plant Growth (Game-Time Driven)

### File: `scenes/level/plant.gd` (modify)

### Growth Rule

**Each growth stage requires watering. Without watering, the plant stays frozen at its current stage.**

```
Plant(seed) → 💧Water → Wait N days → Stage 1
                                   → 💧Water again → Wait N days → Stage 2
                                                                      → 💧Water again → Wait N days → Stage 3 (mature)
```

### Changes

**Remove:**
- `const GROWTH_INTERVAL` and `_growth_timer: Timer`

**Add:**
```gdscript
@export var growth_days_per_stage: int = 1  # Days to wait after watering
var _watered_day: int = -1                  # Day when last watered
```

### Logic

1. `water()` → record `_watered_day = TimeManager.day`, set `is_watered = true`, subscribe to `TimeManager.day_changed`
2. On `day_changed` → check if `(current_day - _watered_day) >= growth_days_per_stage`
3. If ready → advance `frame += 1`, reset `is_watered = false`, update `_watered_day`
4. If `frame >= MAX_STAGE` → mature, disconnect signal, stop growing
5. If not watered again → plant stays at current stage indefinitely

### Visual Feedback

- `is_watered = true`: wet soil tile underneath (existing `soil_water` mechanic)
- `is_watered = false`: dry soil, plant frozen at current frame
- Watering again triggers the next growth wait cycle

---

## Part 5: Soil Moisture Drying

### File: `scenes/level/game.gd` (modify)

### Drying Cycle

```
Dry Soil → 💧Water → Wet Soil (soil_water) → Wait N game-hours → Auto-revert to Dry Soil
```

### Implementation

Add a dictionary in `game.gd`:

```gdscript
# key: Vector2i tile coords, value: float (game hour when watered)
var _watered_tiles: Dictionary = {}
@export var soil_dry_hours: float = 12.0  # Hours until soil dries
```

### Logic

1. **On water** (`_handle_water`): store `_watered_tiles[coords] = TimeManager.total_hours`
2. **On `TimeManager.time_changed`**: iterate `_watered_tiles`, check if `(TimeManager.total_hours - stored_hours) >= soil_dry_hours`
3. **On dry**: erase `soil_water_layer` cell, restore `_soil_layer` cell with terrain connect, remove from dict
4. `soil_dry_hours` is `@export` (default 12 game-hours = half a day)

### Complete Moisture Cycle

```
Dry Soil ──💧──▶ Wet Soil ──12h──▶ Dry Soil
                    │
                    └── Plant absorbs water, grows one stage
```

---

## Part 6: Input Map & File Manifest

### New Input Actions (project.godot)

| Action | Key | Purpose |
|--------|-----|---------|
| `time_pause` | `Space` | Toggle pause |
| `time_speed_up` | `+` / `]` | Increase speed |
| `time_speed_down` | `-` / `[` | Decrease speed |
| `time_speed_1` | `1` | Jump to 1x |
| `time_speed_2` | `2` | Jump to 2x |
| `time_speed_3` | `3` | Jump to 3x |
| `time_speed_4` | `4` | Jump to 4x |
| `time_speed_5` | `5` | Jump to 5x |

### File Manifest

| File | Action | Description |
|------|--------|-------------|
| `globals/time_manager.gd` | **New** | Autoload time manager singleton |
| `scenes/ui/time_ui.tscn` | **New** | Time UI scene (CanvasLayer) |
| `scenes/ui/time_ui.gd` | **New** | Time UI script |
| `scenes/level/game.tscn` | Modify | Add DayNightModulate + TimeUI nodes |
| `scenes/level/game.gd` | Modify | Soil drying logic |
| `scenes/level/plant.gd` | Modify | Game-time-driven growth |
| `project.godot` | Modify | Register autoload, add input map |

---

## Data Flow

```
Keyboard Input ──▶ TimeManager ──▶ signals ──▶ TimeUI (display)
                        │                        DayNightModulate (color)
                        │                        plant.gd (growth check)
                        │                        game.gd (soil drying)
```

---

## Future Extensions (Out of Scope)

- Season system (spring/summer/autumn/winter) affecting crop types
- NPC schedules based on time of day
- Nighttime particles (fireflies)
- Energy/fatigue system for player
- Save/load game time state
