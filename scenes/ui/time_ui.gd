extends CanvasLayer

@onready var _time_label: Label = $MarginContainer/HBoxContainer/TimeLabel
@onready var _speed_label: Label = $MarginContainer/HBoxContainer/SpeedLabel


func _ready() -> void:
	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.speed_changed.connect(_on_speed_changed)
	# Ensure font size is applied at runtime
	_time_label.add_theme_font_size_override(&"font_size", 12)
	_speed_label.add_theme_font_size_override(&"font_size", 12)
	_refresh_display()


func _process(_delta: float) -> void:
	_handle_input()


func _handle_input() -> void:
	if Input.is_action_just_pressed("time_pause"):
		TimeManager.toggle_pause()
	if Input.is_action_just_pressed("time_speed_up"):
		TimeManager.speed_up()
	if Input.is_action_just_pressed("time_speed_down"):
		TimeManager.speed_down()
	for i in range(1, 6):
		if Input.is_action_just_pressed("time_speed_%d" % i):
			TimeManager.set_speed(i)


func _on_time_changed(day: int, hour: int, minute: int) -> void:
	var hour_str := "%02d" % hour
	var minute_str := "%02d" % minute
	var icon := "☀️" if hour >= 7 and hour < 19 else "🌙"
	_time_label.text = "%s Day %d · %s:%s" % [icon, day, hour_str, minute_str]


func _on_speed_changed(_speed_index: int) -> void:
	_refresh_display()


func _refresh_display() -> void:
	var si := TimeManager.speed_index
	if si == 0:
		_speed_label.text = "[⏸ Paused]"
	else:
		var mult := TimeManager.speed_multipliers[si] as float
		_speed_label.text = "[▶ %.0fx]" % mult
