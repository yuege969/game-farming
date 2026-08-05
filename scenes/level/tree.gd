extends StaticBody2D

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	sprite.frame = [0, 1].pick_random()
	# Duplicate material so each tree has its own independent flash state
	sprite.material = sprite.material.duplicate()


func flash() -> void:
	var mat: ShaderMaterial = sprite.material
	var tween := create_tween()
	tween.tween_method(
		func(v: float): mat.set_shader_parameter("flash_intensity", v),
		0.0, 1.0, 0.08
	)
	tween.tween_method(
		func(v: float): mat.set_shader_parameter("flash_intensity", v),
		1.0, 0.0, 0.12
	)
