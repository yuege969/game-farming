# Time Control & Day/Night System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement HOI4-style time control with day/night cycle, game-time-driven plant growth, and soil moisture drying.

**Architecture:** A `TimeManager` autoload singleton drives game time via signals. `DayNightModulate` (CanvasModulate) listens for color changes. `TimeUI` (CanvasLayer) displays time and speed. `plant.gd` and `game.gd` subscribe to time signals for growth and soil drying.

**Tech Stack:** Godot 4.7, GDScript

## Global Constraints

- Speed levels: 0 (pause) through 5 (16x), with `@export` multipliers
- 1 game day = 10 real minutes at 1x speed (`@export var real_seconds_per_day = 600.0`)
- Day/night via CanvasModulate color: night `(0.30, 0.35, 0.60)`, day `(1.0, 1.0, 1.0)`
- Plant growth: each stage requires a separate watering + wait N days
- Soil dries after 12 game-hours (`@export var soil_dry_hours = 12.0`)
- All tunable values use `@export` for inspector adjustability
- Follow existing code style: `snake_case` vars, `_private` prefix, typed GDScript

---

## File Structure

| File | Responsibility |
|------|---------------|
| `globals/time_manager.gd` (new) | Game-time state, speed control, tick timer, signals |
| `scenes/ui/time_ui.tscn` (new) | CanvasLayer scene with Label nodes for display |
| `scenes/ui/time_ui.gd` (new) | UI script: subscribe to signals, update display, input handling |
| `scenes/level/day_night_modulate.gd` (new) | CanvasModulate script for day/night color transitions |
| `scenes/level/game.tscn` (modify) | Add DayNightModulate + TimeUI nodes |
| `scenes/level/game.gd` (modify) | Soil drying dictionary, subscribe to TimeManager signals |
| `scenes/level/plant.gd` (modify) | Replace Timer with game-time growth, day-change subscription |
| `project.godot` (modify) | Register TimeManager autoload, add time input actions |

---

### Task 1: TimeManager Autoload

**Files:**
- Create: `globals/time_manager.gd`
- Modify: `project.godot`

**Interfaces:**
- Consumes: nothing (foundation)
- Produces:
  - `TimeManager.day: int`, `TimeManager.hour: int`, `TimeManager.minute: int`
  - `TimeManager.speed_index: int` (0–5), `TimeManager.is_paused: bool`
  - `TimeManager.total_hours: float`
  - `TimeManager.real_seconds_per_day: float` (@export, default 600.0)
  - `TimeManager.speed_multipliers: Array[float]` (@export)
  - Signal `time_changed(day: int, hour: int, minute: int)`
  - Signal `day_changed(new_day: int)`
  - Signal `speed_changed(speed_index: int)`

- [ ] **Step 1: Create `globals/` directory and `time_manager.gd`**

```gdscript
extends Node

## Real seconds for one in-game day at 1x speed.
@export var real_seconds_per_day: float = 600.0

## Speed multipliers indexed by speed level.
## Index 0 is pause (0.0), 1-5 are increasing speeds.
@export var speed_multipliers: Array[float] = [0.0, 1.0, 2.0, 4.0, 8.0, 16.0]

signal time_changed(day: int, hour: int, minute: int)
signal day_changed(new_day: int)
signal speed_changed(speed_index: int)

var day: int = 1
var hour: int = 6
var minute: int = 0
var total_hours: float = 6.0

var speed_index: int = 1
var is_paused: bool = false
var _previous_day: int = 1

var _tick_timer: Timer
var _accumulated: float = 0.0
const TICK_INTERVAL: float = 0.5


func _ready() -> void:
	_tick_timer = Timer.new()
	_tick_timer.wait_time = TICK_INTERVAL
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)
	_tick_timer.start()


func _on_tick() -> void:
	var multiplier := speed_multipliers[speed_index]
	if multiplier <= 0.0:
		return

	var seconds_per_game_minute := real_seconds_per_day / (24.0 * 60.0)
	var game_minutes_per_tick := (TICK_INTERVAL * multiplier) / seconds_per_game_minute
	_advance_time(game_minutes_per_tick)


func _advance_time(game_minutes: float) -> void:
	_accumulated += game_minutes
	if _accumulated < 1.0:
		return

	var whole_minutes := int(_accumulated)
	_accumulated -= float(whole_minutes)

	minute += whole_minutes
	while minute >= 60:
		minute -= 60
		hour += 1
	while hour >= 24:
		hour -= 24
		day += 1

	total_hours += float(whole_minutes) / 60.0

	if day != _previous_day:
		_previous_day = day
		day_changed.emit(day)

	time_changed.emit(day, hour, minute)


func set_speed(index: int) -> void:
	var clamped := clampi(index, 0, speed_multipliers.size() - 1)
	if clamped == speed_index:
		return
	speed_index = clamped
	is_paused = (speed_index == 0)
	speed_changed.emit(speed_index)


func toggle_pause() -> void:
	if is_paused:
		set_speed(1)
	else:
		set_speed(0)


func speed_up() -> void:
	set_speed(speed_index + 1)


func speed_down() -> void:
	set_speed(speed_index - 1)
```

- [ ] **Step 2: Register autoload in `project.godot`**

Add under `[autoload]` section (create the section if absent):

```
[autoload]

TimeManager="*res://globals/time_manager.gd"
```

- [ ] **Step 3: Verify the project opens in Godot without errors**

Open project in Godot editor. Check Output panel for autoload errors (none expected).

- [ ] **Step 4: Commit**

```bash
git add globals/time_manager.gd project.godot
git commit -m "feat: add TimeManager autoload with 5-speed time control"
```

---

### Task 2: Time Control Input Map

**Files:**
- Modify: `project.godot`

**Interfaces:**
- Consumes: `TimeManager` autoload (Task 1)
- Produces: Input actions `time_pause` (P key), `time_speed_up` (] key), `time_speed_down` ([ key), `time_speed_1`–`time_speed_5` (keys 1–5)

- [ ] **Step 1: Add input actions to `project.godot`**

Insert into the `[input]` section (where physical_keycode 80=P, 91=], 87=[, 49-53=1-5):

```ini
time_speed_up={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":91,"key_label":0,"unicode":93,"location":0,"echo":false,"script":null)
]
}
time_speed_down={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":91,"location":0,"echo":false,"script":null)
]
}
time_pause={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":80,"key_label":0,"unicode":112,"location":0,"echo":false,"script":null)
]
}
time_speed_1={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":49,"key_label":0,"unicode":49,"location":0,"echo":false,"script":null)
]
}
time_speed_2={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":50,"key_label":0,"unicode":50,"location":0,"echo":false,"script":null)
]
}
time_speed_3={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":51,"key_label":0,"unicode":51,"location":0,"echo":false,"script":null)
]
}
time_speed_4={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":52,"key_label":0,"unicode":52,"location":0,"echo":false,"script":null)
]
}
time_speed_5={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":53,"key_label":0,"unicode":53,"location":0,"echo":false,"script":null)
]
}
```

Key mapping summary:
- `time_pause`: `P` key (physical_keycode 80)
- `time_speed_up`: `]` key (physical_keycode 91)
- `time_speed_down`: `[` key (physical_keycode 87)
- `time_speed_1`–`time_speed_5`: number keys `1`–`5`

- [ ] **Step 2: Verify in Godot**

Open Project Settings > Input Map, confirm all 8 new actions appear with correct key bindings.

- [ ] **Step 3: Commit**

```bash
git add project.godot
git commit -m "feat: add time control input actions (pause, speed up/down, speed 1-5)"
```

---

### Task 3: DayNightModulate Script

**Files:**
- Create: `scenes/level/day_night_modulate.gd`

**Interfaces:**
- Consumes: `TimeManager.time_changed`, `TimeManager.hour`, `TimeManager.minute`
- Produces: `DayNightModulate` script (attached to CanvasModulate node in Task 7)
  - `@export var night_color: Color = Color(0.30, 0.35, 0.60)`
  - `@export var day_color: Color = Color(1.0, 1.0, 1.0)`
  - `@export var dawn_start: int = 5`, `@export var dawn_end: int = 7`
  - `@export var dusk_start: int = 17`, `@export var dusk_end: int = 19`

- [ ] **Step 1: Create `scenes/level/day_night_modulate.gd`**

```gdscript
extends CanvasModulate

@export var night_color: Color = Color(0.30, 0.35, 0.60)
@export var day_color: Color = Color(1.0, 1.0, 1.0)
@export var dawn_start: int = 5
@export var dawn_end: int = 7
@export var dusk_start: int = 17
@export var dusk_end: int = 19


func _ready() -> void:
	TimeManager.time_changed.connect(_on_time_changed)
	_apply_color(TimeManager.hour, TimeManager.minute)


func _on_time_changed(_day: int, hour: int, minute: int) -> void:
	_apply_color(hour, minute)


func _apply_color(hour: int, minute: int) -> void:
	var time_of_day := float(hour) + float(minute) / 60.0

	if time_of_day < dawn_start:
		# Deep night: 0:00 – dawn_start
		color = night_color
	elif time_of_day < dawn_end:
		# Dawn transition: dawn_start – dawn_end
		var t := (time_of_day - dawn_start) / float(dawn_end - dawn_start)
		color = night_color.lerp(day_color, t)
	elif time_of_day < dusk_start:
		# Day: dawn_end – dusk_start
		color = day_color
	elif time_of_day < dusk_end:
		# Dusk transition: dusk_start – dusk_end
		var t := (time_of_day - dusk_start) / float(dusk_end - dusk_start)
		color = day_color.lerp(night_color, t)
	else:
		# Night: dusk_end – 24:00
		color = night_color
```

- [ ] **Step 2: Verify script compiles**

Open in Godot script editor, check for parse errors.

- [ ] **Step 3: Commit**

```bash
git add scenes/level/day_night_modulate.gd
git commit -m "feat: add DayNightModulate script for time-based color transitions"
```

---

### Task 4: TimeUI Scene & Script

**Files:**
- Create: `scenes/ui/time_ui.tscn`
- Create: `scenes/ui/time_ui.gd`

**Interfaces:**
- Consumes: `TimeManager.time_changed`, `TimeManager.speed_changed`, `TimeManager.day`, `TimeManager.hour`, `TimeManager.minute`, `TimeManager.speed_index`, `TimeManager.speed_multipliers`
- Produces: `TimeUI` CanvasLayer scene (instantiated in Task 7)

- [ ] **Step 1: Create directory `scenes/ui/`**

```bash
mkdir -p scenes/ui
```

- [ ] **Step 2: Create `scenes/ui/time_ui.gd`**

```gdscript
extends CanvasLayer

@onready var _time_label: Label = $MarginContainer/HBoxContainer/TimeLabel
@onready var _speed_label: Label = $MarginContainer/HBoxContainer/SpeedLabel


func _ready() -> void:
	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.speed_changed.connect(_on_speed_changed)
	_refresh_display()


func _process(_delta: float) -> void:
	_handle_input()


func _handle_input() -> void:
	if Input.is_action_just_pressed("time_pause"):
		TimeManager.toggle_pause()
	if Input.is_action_just_pressed("time_speed_up"):
		TimeManager.speed_up()
	if Input.is_action_just_pressed("time_speed_down"):
		TimeManager.speed_down()
	for i in range(1, 6):
		if Input.is_action_just_pressed("time_speed_%d" % i):
			TimeManager.set_speed(i)


func _on_time_changed(day: int, hour: int, minute: int) -> void:
	var hour_str := "%02d" % hour
	var minute_str := "%02d" % minute
	var icon := "☀️" if hour >= 7 and hour < 19 else "🌙"
	_time_label.text = "%s Day %d · %s:%s" % [icon, day, hour_str, minute_str]


func _on_speed_changed(_speed_index: int) -> void:
	_refresh_display()


func _refresh_display() -> void:
	var si := TimeManager.speed_index
	if si == 0:
		_speed_label.text = "[⏸ Paused]"
	else:
		var mult := TimeManager.speed_multipliers[si] as float
		_speed_label.text = "[▶ %.0fx]" % mult
```

- [ ] **Step 3: Create `scenes/ui/time_ui.tscn` in Godot editor**

Build the scene:
1. Root node: `CanvasLayer` (attach `time_ui.gd` script)
2. Add child: `MarginContainer`
   - Theme overrides > Constants: `margin_left = 20`, `margin_top = 10`, `margin_right = 20`
3. Under `MarginContainer`, add `HBoxContainer`
   - Add `Control` (left spacer, Layout > Horizontal Expansion: on)
   - Add `Label` named `TimeLabel` (text: "Day 1 · 06:00", horizontal_alignment: CENTER)
   - Add `Control` (middle spacer, Layout > Horizontal Expansion: on)
   - Add `Label` named `SpeedLabel` (text: "[▶ 1x]", horizontal_alignment: RIGHT)
4. Save to `scenes/ui/time_ui.tscn`

- [ ] **Step 4: Verify scene node paths**

Check that `$MarginContainer/HBoxContainer/TimeLabel` and `$MarginContainer/HBoxContainer/SpeedLabel` match the scene tree.

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/time_ui.tscn scenes/ui/time_ui.gd
git commit -m "feat: add TimeUI CanvasLayer with time display and speed indicator"
```

---

### Task 5: Plant Growth — Game-Time Driven

**Files:**
- Modify: `scenes/level/plant.gd`

**Interfaces:**
- Consumes: `TimeManager.day_changed` signal, `TimeManager.day`
- Produces: unchanged external interface — `setup(crop_name)`, `water()` work identically

- [ ] **Step 1: Replace `plant.gd` content**

Replace the entire file with:

```gdscript
extends StaticBody2D

const TEXTURES := {
	"corn": "res://graphics/plants/corn.png",
	"pumpkin": "res://graphics/plants/pumpkin.png",
	"tomatoes": "res://graphics/plants/tomatoes.png",
}

@export var growth_days_per_stage: int = 1
@export var max_stage: int = 3

var crop_type: String = ""
var growth_stage: int = 0
var is_watered: bool = false
var _watered_day: int = -1


func setup(crop_name: String) -> void:
	crop_type = crop_name

	var texture_path: String = TEXTURES.get(crop_name, "")
	if texture_path.is_empty():
		push_error("Unknown crop type: %s" % crop_name)
		return

	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_error("Failed to load texture: %s" % texture_path)
		return

	var sprite: Sprite2D = $Sprite2D
	sprite.texture = texture
	sprite.hframes = 4
	sprite.frame = 0
	growth_stage = 0


func water() -> void:
	if is_watered:
		return

	is_watered = true
	_watered_day = TimeManager.day

	if not TimeManager.day_changed.is_connected(_on_day_changed):
		TimeManager.day_changed.connect(_on_day_changed)


func _on_day_changed(_new_day: int) -> void:
	if not is_watered:
		return

	var days_passed := TimeManager.day - _watered_day
	if days_passed >= growth_days_per_stage:
		growth_stage += 1
		$Sprite2D.frame = growth_stage
		is_watered = false

		if growth_stage >= max_stage:
			_disconnect_time()


func _disconnect_time() -> void:
	if TimeManager.day_changed.is_connected(_on_day_changed):
		TimeManager.day_changed.disconnect(_on_day_changed)
```

- [ ] **Step 2: Verify script compiles**

Open `plant.gd` in Godot script editor, check for parse errors.

- [ ] **Step 3: Commit**

```bash
git add scenes/level/plant.gd
git commit -m "feat: drive plant growth by game time instead of real-time timer"
```

---

### Task 6: Soil Drying in game.gd

**Files:**
- Modify: `scenes/level/game.gd`

**Interfaces:**
- Consumes: `TimeManager.time_changed` signal, `TimeManager.total_hours`
- Produces: `_watered_tiles: Dictionary` (internal), `@export var soil_dry_hours: float = 12.0`

- [ ] **Step 1: Apply changes to `game.gd`**

Make these specific edits:

**Edit 1:** After `@export var tile_world_offset`, add:
```gdscript
## Game hours until watered soil dries back to regular soil.
@export var soil_dry_hours: float = 12.0
```

**Edit 2:** After `@onready var _player`, add:
```gdscript
var _watered_tiles: Dictionary = {}
```

**Edit 3:** In `_ready()`, add TimeManager signal connection after existing signal connections:
```gdscript
	TimeManager.time_changed.connect(_on_time_changed)
```

**Edit 4:** In `_handle_water`, after `_soil_water_layer.set_cell(...)`, add before the plant watering line:
```gdscript
	# Track watering time for drying
	_watered_tiles[coords] = TimeManager.total_hours
```

**Edit 5:** Add these new methods after `_handle_water`:

```gdscript
func _on_time_changed(_day: int, _hour: int, _minute: int) -> void:
	var current_hours := TimeManager.total_hours
	var to_dry: Array[Vector2i] = []
	for coords in _watered_tiles:
		var watered_at: float = _watered_tiles[coords]
		if (current_hours - watered_at) >= soil_dry_hours:
			to_dry.append(coords)
	for coords in to_dry:
		_revert_to_soil(coords)


func _revert_to_soil(coords: Vector2i) -> void:
	_soil_water_layer.erase_cell(coords)
	_soil_layer.set_cells_terrain_connect([coords], 0, 0)
	_watered_tiles.erase(coords)
```

- [ ] **Step 2: Verify script compiles**

Open `game.gd` in Godot script editor, check for parse errors.

- [ ] **Step 3: Commit**

```bash
git add scenes/level/game.gd
git commit -m "feat: add soil moisture drying driven by game time"
```

---

### Task 7: Integrate — Add Nodes to game.tscn

**Files:**
- Modify: `scenes/level/game.tscn`

**Interfaces:**
- Consumes: `DayNightModulate` script (Task 3), `TimeUI` scene (Task 4)
- Produces: fully working time control system

- [ ] **Step 1: Open `game.tscn` in Godot editor**

- [ ] **Step 2: Add `DayNightModulate` node**

1. Right-click the root `Game` node → Add Child Node
2. Search for `CanvasModulate`, add it
3. Rename to `DayNightModulate`
4. In Inspector, attach script `res://scenes/level/day_night_modulate.gd`
5. Drag it above `Layers` in the scene tree (it must be above what it modulates)

- [ ] **Step 3: Add `TimeUI` node**

1. Right-click the root `Game` node → Instantiate Child Scene
2. Choose `res://scenes/ui/time_ui.tscn`
3. Ensure it's the last child (CanvasLayer draws on top)

- [ ] **Step 4: Verify final scene tree**

```
Game (Node2D) [game.gd]
├── DayNightModulate (CanvasModulate) [day_night_modulate.gd]
├── Layers (Node2D)
│   ├── GrassLayer (TileMapLayer)
│   ├── SoilLayer (TileMapLayer)
│   ├── WaterLayer (TileMapLayer)
│   └── SoilWaterLayer (TileMapLayer)
├── Objects (Node2D)
│   ├── Player (CharacterBody2D)
│   └── ...
└── TimeUI (CanvasLayer) [time_ui.gd]
```

- [ ] **Step 5: Save scene and run the game**

Press F5. Verify:
- Time display shows "Day 1 · 06:00" and "▶ 1x" at top
- Screen tint starts at dawn color
- Press `5` → speed jumps to 16x, day/night cycle visible
- Press `P` → pauses, display shows "⏸ Paused"
- Plant a seed, water it at 5x speed → watches growth stages
- Watered soil reverts to dry after ~12 game hours

- [ ] **Step 6: Commit**

```bash
git add scenes/level/game.tscn
git commit -m "feat: integrate DayNightModulate and TimeUI into game scene"
```
