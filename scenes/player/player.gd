extends CharacterBody2D

@export var speed: float = 100.0

@onready var animation_tree: AnimationTree = $AnimationTree

var last_direction: Vector2 = Vector2.DOWN
var current_state: String = "idle"

func _physics_process(_delta: float) -> void:
	var direction = Input.get_vector("left", "right", "up", "down")

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
