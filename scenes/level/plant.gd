extends StaticBody2D

const TEXTURES := {
	"corn": "res://graphics/plants/corn.png",
	"pumpkin": "res://graphics/plants/pumpkin.png",
	"tomatoes": "res://graphics/plants/tomatoes.png",
}

const GROWTH_INTERVAL := 5.0
const MAX_STAGE := 3

@onready var _sprite: Sprite2D = $Sprite2D

var crop_type: String = ""
var growth_stage: int = 0
var is_watered: bool = false
var _growth_timer: Timer


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

	_sprite.texture = texture
	_sprite.hframes = 4
	_sprite.frame = 0
	growth_stage = 0


func water() -> void:
	if is_watered:
		return

	is_watered = true
	_start_growth_timer()


func _start_growth_timer() -> void:
	_growth_timer = Timer.new()
	_growth_timer.wait_time = GROWTH_INTERVAL
	_growth_timer.timeout.connect(_on_growth_tick)
	_growth_timer.one_shot = false
	add_child(_growth_timer)
	_growth_timer.start()


func _on_growth_tick() -> void:
	growth_stage += 1
	_sprite.frame = growth_stage

	if growth_stage >= MAX_STAGE:
		_growth_timer.stop()
