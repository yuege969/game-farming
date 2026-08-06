extends CanvasModulate

@export var night_color: Color = Color(0.30, 0.35, 0.60)
@export var day_color: Color = Color(1.0, 1.0, 1.0)
@export var dawn_start: int = 5
@export var dawn_end: int = 7
@export var dusk_start: int = 17
@export var dusk_end: int = 19


func _ready() -> void:
	TimeManager.time_changed.connect(_on_time_changed)
	_apply_color(TimeManager.hour, TimeManager.minute)


func _on_time_changed(_day: int, hour: int, minute: int) -> void:
	_apply_color(hour, minute)


func _apply_color(hour: int, minute: int) -> void:
	var time_of_day := float(hour) + float(minute) / 60.0

	if time_of_day < dawn_start:
		# Deep night: 0:00 – dawn_start
		color = night_color
	elif time_of_day < dawn_end:
		# Dawn transition: dawn_start – dawn_end
		var t := (time_of_day - dawn_start) / float(dawn_end - dawn_start)
		color = night_color.lerp(day_color, t)
	elif time_of_day < dusk_start:
		# Day: dawn_end – dusk_start
		color = day_color
	elif time_of_day < dusk_end:
		# Dusk transition: dusk_start – dusk_end
		var t := (time_of_day - dusk_start) / float(dusk_end - dusk_start)
		color = day_color.lerp(night_color, t)
	else:
		# Night: dusk_end – 24:00
		color = night_color
