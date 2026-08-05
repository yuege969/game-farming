extends CharacterBody2D

@export var speed: float = 100.0
@export var tile_offset: int = 16
@export var tile_offset_y: int = 0

@onready var animation_tree: AnimationTree = $AnimationTree

var last_direction: Vector2 = Vector2.DOWN
var current_state: String = "idle"

var tools: Array[String] = ["axe", "hoe", "water"]
var current_tool_idx: int = 1  # default to hoe
var is_using_tool: bool = false
var _one_shot_was_active: bool = false

func _ready() -> void:
	# Initialize ToolStateMachine to default tool (hoe)
	_switch_tool()

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
		# Continuously update tool blend position during animation
		var tool_name = tools[current_tool_idx]
		var tool_blend_path = "parameters/ToolStateMachine/%s/blend_position" % tool_name
		animation_tree.set(tool_blend_path, last_direction)
		# Detect OneShot completion (edge: was active → not active)
		var is_active = animation_tree.get("parameters/OneShot/active")
		if _one_shot_was_active and not is_active:
			is_using_tool = false
		_one_shot_was_active = is_active
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

func _switch_tool() -> void:
	var tool_name = tools[current_tool_idx]
	var tool_blend_path = "parameters/ToolStateMachine/%s/blend_position" % tool_name
	animation_tree.set(tool_blend_path, last_direction)
	var tool_playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/ToolStateMachine/playback")
	tool_playback.travel(tool_name)

func _start_tool_action() -> void:
	var tool_name = tools[current_tool_idx]
	# Ensure ToolStateMachine is in the correct tool state (not Start/End)
	var tool_playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/ToolStateMachine/playback")
	tool_playback.travel(tool_name)
	# Set the tool's blend position to current facing direction
	var tool_blend_path = "parameters/ToolStateMachine/%s/blend_position" % tool_name
	animation_tree.set(tool_blend_path, last_direction)
	# Fire the OneShot
	animation_tree.set("parameters/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_one_shot_was_active = false
	is_using_tool = true

func axe_use() -> void:
	# Placeholder — called by axe animation track at 0.4s
	pass

func _get_target_coords() -> Vector2i:
	var layers = get_tree().current_scene.get_node("Layers")
	var soil_layer: TileMapLayer = layers.get_node("SoliLayer")
	# Offset world position (facing direction + Y pivot), then snap to tile
	var adjusted_pos: Vector2 = global_position + last_direction * tile_offset + Vector2(0, tile_offset_y)
	var player_local: Vector2 = soil_layer.to_local(adjusted_pos)
	var player_coords: Vector2i = soil_layer.local_to_map(player_local)
	return player_coords

func hoe_use() -> void:
	var layers = get_tree().current_scene.get_node("Layers")
	var grass_layer: TileMapLayer = layers.get_node("GrassLayer")
	var soil_layer: TileMapLayer = layers.get_node("SoliLayer")
	var water_layer: TileMapLayer = layers.get_node("WaterLayer")

	var target_coords := _get_target_coords()

	# Only till if grass exists at the target tile
	if grass_layer.get_cell_tile_data(target_coords) == null:
		return

	# Don't double-till — soil already present
	if soil_layer.get_cell_source_id(target_coords) != -1:
		return

	# Don't till tiles that intersect with water
	if water_layer.get_cell_source_id(target_coords) != -1:
		return

	# Place soil tile with terrain auto-connect (terrain_set=0, terrain=0)
	soil_layer.set_cells_terrain_connect([target_coords], 0, 0)
