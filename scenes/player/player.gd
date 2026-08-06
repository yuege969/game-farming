extends CharacterBody2D

## Emitted when a tool animation fires its action frame.
## game.gd listens and performs the actual world manipulation.
signal tool_action(tool_name: String, target_world_pos: Vector2)

## Emitted when player presses the plant key.
## game.gd listens and spawns a Plant at the target tile.
signal plant_action(seed_name: String, target_world_pos: Vector2)

@export var speed: float = 100.0
@export var tile_offset: int = 16
@export var tile_offset_y: int = 0

@onready var animation_tree: AnimationTree = $AnimationTree

@onready var _axe_sound: AudioStreamPlayer2D = $Sounds/AxeSound
@onready var _hoe_sound: AudioStreamPlayer2D = $Sounds/HoeSound
@onready var _water_sound: AudioStreamPlayer2D = $Sounds/WaterSound
@onready var _step_sound: AudioStreamPlayer2D = $Sounds/StepSound
@onready var _bgm: AudioStreamPlayer2D = $Sounds/BackgroundSound

const STEP_INTERVAL: float = 0.35
var _step_timer: float = 0.0

var last_direction: Vector2 = Vector2.DOWN
var current_state: String = "idle"

var tools: Array[String] = ["axe", "hoe", "water"]
var current_tool_idx: int = 1  # default to hoe

var seeds: Array[String] = ["corn", "pumpkin", "tomatoes"]
var current_seed_idx: int = 0

var is_using_tool: bool = false
var _one_shot_was_active: bool = false

func _ready() -> void:
	# Initialize ToolStateMachine to default tool (hoe)
	_switch_tool()
	# Start background music looping
	_bgm.play()
	# music.mp3 import has loop disabled, so loop manually via finished signal
	_bgm.finished.connect(_bgm.play)

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

	# --- Seed switching (always available) ---
	if Input.is_action_just_pressed("seed_toggle"):
		current_seed_idx = (current_seed_idx + 1) % seeds.size()

	# --- Plant action (always available) ---
	if Input.is_action_just_pressed("plant"):
		plant_action.emit(seeds[current_seed_idx], _tool_target_pos())

	# --- Movement (locked during tool use) ---
	if is_using_tool:
		velocity = Vector2.ZERO
		_step_timer = 0.0
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
			# Step sound timer — play on interval while moving
			_step_timer += _delta
			if _step_timer >= STEP_INTERVAL:
				_step_sound.play()
				_step_timer = 0.0
		else:
			direction = Vector2.ZERO
			_step_timer = 0.0   # reset so next walk starts fresh

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
	# Play tool sound
	match tool_name:
		"axe":
			_axe_sound.play()
		"hoe":
			_hoe_sound.play()
		"water":
			_water_sound.play()
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

func _tool_target_pos() -> Vector2:
	return global_position + last_direction * tile_offset + Vector2(0, tile_offset_y)

## Called by animation method track — emits signal for game.gd to handle
func axe_use() -> void:
	tool_action.emit("axe", _tool_target_pos())

## Called by animation method track — emits signal for game.gd to handle
func water_use() -> void:
	tool_action.emit("water", _tool_target_pos())

## Called by animation method track — emits signal for game.gd to handle
func hoe_use() -> void:
	tool_action.emit("hoe", _tool_target_pos())
