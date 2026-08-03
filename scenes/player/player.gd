extends CharacterBody2D

const SPEED: float = 100.0

@onready var animation_tree: AnimationTree = $AnimationTree

var last_direction: Vector2 = Vector2.DOWN

func _physics_process(_delta: float) -> void:
	var direction = Input.get_vector("left", "right", "up", "down")

	# Update blend positions for 8-directional animation
	if direction != Vector2.ZERO:
		last_direction = direction
		animation_tree.set("parameters/MoveStateMachine/idle/blend_position", direction)
		animation_tree.set("parameters/MoveStateMachine/move/blend_position", direction)
	else:
		animation_tree.set("parameters/MoveStateMachine/idle/blend_position", last_direction)

	# Switch between idle and move animation states
	var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/MoveStateMachine/playback")
	if direction != Vector2.ZERO:
		playback.travel("move")
	else:
		playback.travel("idle")

	# Movement
	velocity = direction * SPEED
	move_and_slide()
