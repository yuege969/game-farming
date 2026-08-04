# Tool Animation System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add tool switching and usage animation logic to player.gd using three global input actions.

**Architecture:** Single-file change to `scenes/player/player.gd`. All AnimationTree connections already exist in the scene. Input actions `action`, `tool_forward`, `tool_backward` are already defined in the Input Map.

**Tech Stack:** Godot 4.x, GDScript

## Global Constraints

- 3 tools only: axe, hoe, water
- Movement locked during tool animation (0.8s)
- Default tool: hoe (matches ToolStateMachine Start→hoe)

---

### Task 1: Implement tool animation switching logic

**Files:**
- Modify: `scenes/player/player.gd`

**Interfaces:**
- Produces: `tools: Array[String]`, `current_tool_idx: int`, `is_using_tool: bool`, `_switch_tool()`, `_start_tool_action()`, `axe_use()`

- [ ] **Step 1: Add tool state variables**

After `var current_state: String = "idle"` (line 8), add:

```gdscript
var tools: Array[String] = ["axe", "hoe", "water"]
var current_tool_idx: int = 1  # default to hoe
var is_using_tool: bool = false
```

- [ ] **Step 2: Add input handling for tool switching and action in _physics_process**

```gdscript
func _physics_process(_delta: float) -> void:
	# --- Tool switching input (only when not using a tool) ---
	if not is_using_tool:
		if Input.is_action_just_pressed("tool_forward"):
			current_tool_idx = (current_tool_idx + 1) % tools.size()
			_switch_tool()
		if Input.is_action_just_pressed("tool_backward"):
			current_tool_idx = (current_tool_idx - 1 + tools.size()) % tools.size()
			_switch_tool()

	# --- Tool action input ---
	if Input.is_action_just_pressed("action") and not is_using_tool:
		_start_tool_action()

	# --- Movement (locked during tool use) ---
	if is_using_tool:
		velocity = Vector2.ZERO
		# Track OneShot completion
		if not animation_tree.get("parameters/OneShot/active"):
			is_using_tool = false
	else:
		var raw_direction = Input.get_vector("left", "right", "up", "down")

		# Normalize and round direction for 8-directional blend space
		var direction: Vector2
		if raw_direction != Vector2.ZERO:
			raw_direction = raw_direction.normalized()
			direction.x = round(raw_direction.x)
			direction.y = round(raw_direction.y)
		else:
			direction = Vector2.ZERO

		# Update blend positions for 8-directional animation
		if direction != Vector2.ZERO:
			last_direction = direction
			animation_tree.set("parameters/MoveStateMachine/idle/blend_position", direction)
			animation_tree.set("parameters/MoveStateMachine/move/blend_position", direction)
		else:
			animation_tree.set("parameters/MoveStateMachine/idle/blend_position", last_direction)

		# Only switch state when it actually changes
		var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/MoveStateMachine/playback")
		var target_state = "move" if direction != Vector2.ZERO else "idle"
		if target_state != current_state:
			current_state = target_state
			playback.travel(target_state)

		# Movement
		velocity = direction * speed

	move_and_slide()
```

- [ ] **Step 3: Add helper functions after _physics_process**

```gdscript
func _switch_tool() -> void:
	var tool_name = tools[current_tool_idx]
	var tool_blend_path = "parameters/ToolStateMachine/%s/blend_position" % tool_name
	animation_tree.set(tool_blend_path, last_direction)
	var tool_playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/ToolStateMachine/playback")
	tool_playback.travel(tool_name)


func _start_tool_action() -> void:
	var tool_name = tools[current_tool_idx]
	# Set the tool's blend position to current facing direction
	var tool_blend_path = "parameters/ToolStateMachine/%s/blend_position" % tool_name
	animation_tree.set(tool_blend_path, last_direction)
	# Fire the OneShot
	animation_tree.set("parameters/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	is_using_tool = true


func axe_use() -> void:
	# Placeholder — called by axe animation track at 0.4s
	pass
```

- [ ] **Step 4: Verify syntax**

Run Godot headless to verify the script parses without errors.

- [ ] **Step 5: Commit**

```bash
git add scenes/player/player.gd
git commit -m "feat: add tool switching and usage animation logic"
```
