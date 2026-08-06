extends StaticBody2D

signal harvested(world_pos: Vector2)

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


func _ready() -> void:
	$Area2D.body_entered.connect(_on_body_entered)


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
	if is_watered or growth_stage >= max_stage:
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


func _on_body_entered(body: Node2D) -> void:
	if not body.name == "Player":
		return
	if growth_stage < max_stage:
		return
	harvested.emit(global_position)
	queue_free()
