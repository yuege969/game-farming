# Audio Playback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire up 5 existing AudioStreamPlayer2D nodes in player.tscn to play at appropriate gameplay moments.

**Architecture:** All changes in `player.gd` — add `@onready` node refs, play BGM on ready, play tool sounds on action start, play step sounds on a timer during movement.

**Tech Stack:** Godot 4 (GDScript)

## Global Constraints

- Only `scenes/player/player.gd` is modified.
- No new audio files needed.
- No changes to `game.gd` or any other file.

---

### Task 1: Add audio playback logic to player.gd

**Files:**
- Modify: `scenes/player/player.gd`

**Interfaces:**
- Consumes: Existing `$Sounds/AxeSound`, `$Sounds/HoeSound`, `$Sounds/WaterSound`, `$Sounds/StepSound`, `$Sounds/BackgroundSound` from player.tscn
- Produces: Audio plays at correct times with no new signals or exports

- [ ] **Step 1: Add `@onready` audio node references and step timer variables**

After existing `@onready var animation_tree` line, add:

```gdscript
@onready var _axe_sound: AudioStreamPlayer2D = $Sounds/AxeSound
@onready var _hoe_sound: AudioStreamPlayer2D = $Sounds/HoeSound
@onready var _water_sound: AudioStreamPlayer2D = $Sounds/WaterSound
@onready var _step_sound: AudioStreamPlayer2D = $Sounds/StepSound
@onready var _bgm: AudioStreamPlayer2D = $Sounds/BackgroundSound

const STEP_INTERVAL: float = 0.35
var _step_timer: float = 0.0
```

- [ ] **Step 2: Update `_ready()` to start background music**

Replace the current `_ready()`:
```gdscript
func _ready() -> void:
    # Initialize ToolStateMachine to default tool (hoe)
    _switch_tool()
```

With:
```gdscript
func _ready() -> void:
    # Initialize ToolStateMachine to default tool (hoe)
    _switch_tool()
    # Start background music looping
    _bgm.play()
```

Note: Ensure `music.mp3` import settings have loop enabled. If not, add:
```gdscript
    _bgm.finished.connect(_bgm.play)
```

- [ ] **Step 3: Add tool sound playback in `_start_tool_action()`**

At the beginning of `_start_tool_action()`, before firing the OneShot, add:

```gdscript
func _start_tool_action() -> void:
    var tool_name = tools[current_tool_idx]
    # Play tool sound
    match tool_name:
        "axe":
            _axe_sound.play()
        "hoe":
            _hoe_sound.play()
        "water":
            _water_sound.play()
    # Ensure ToolStateMachine is in the correct tool state (not Start/End)
    ...
```

- [ ] **Step 4: Add step sound timer logic in `_physics_process()`**

In the movement section (`else` branch of `if is_using_tool`), add step timer:

```gdscript
    else:
        var raw_direction = Input.get_vector("left", "right", "up", "down")

        # Normalize and round direction for 8-directional blend space
        var direction: Vector2
        if raw_direction != Vector2.ZERO:
            raw_direction = raw_direction.normalized()
            direction.x = round(raw_direction.x)
            direction.y = round(raw_direction.y)
            # Step sound timer — play on interval while moving
            _step_timer += _delta
            if _step_timer >= STEP_INTERVAL:
                _step_sound.play()
                _step_timer = 0.0
        else:
            direction = Vector2.ZERO
            _step_timer = 0.0   # reset so next walk starts fresh

        # Update blend positions for 8-directional animation
        ...
```

Also reset `_step_timer` when using a tool (in the `if is_using_tool:` branch, after setting velocity):

```gdscript
    if is_using_tool:
        velocity = Vector2.ZERO
        _step_timer = 0.0
        ...
```

- [ ] **Step 5: Verify in Godot editor**

Open the project in Godot, run the scene, and verify:
- Background music plays on start and loops
- Axe sound plays when using axe tool
- Hoe sound plays when using hoe tool
- Water sound plays when using water tool
- Step sound plays rhythmically while walking
- Step sound stops immediately when player stops moving
- Step sound doesn't play during tool use

- [ ] **Step 6: Commit**

```bash
git add scenes/player/player.gd
git commit -m "feat: add audio playback for tools, steps, and BGM"
```
