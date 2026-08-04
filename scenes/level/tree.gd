extends StaticBody2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Sprite2D.frame = [0,1].pick_random()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
