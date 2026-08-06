extends Node

## Real seconds for one in-game day at 1x speed.
@export var real_seconds_per_day: float = 600.0

## Speed multipliers indexed by speed level.
## Index 0 is pause (0.0), 1-5 are increasing speeds.
@export var speed_multipliers: Array[float] = [0.0, 1.0, 2.0, 4.0, 8.0, 16.0]

signal time_changed(day: int, hour: int, minute: int)
signal day_changed(new_day: int)
signal speed_changed(speed_index: int)

var day: int = 1
var hour: int = 6
var minute: int = 0
var total_hours: float = 6.0

var speed_index: int = 1
var is_paused: bool = false
var _previous_day: int = 1

var _tick_timer: Timer
var _accumulated: float = 0.0
const TICK_INTERVAL: float = 0.5


func _ready() -> void:
	_tick_timer = Timer.new()
	_tick_timer.wait_time = TICK_INTERVAL
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)
	_tick_timer.start()


func _on_tick() -> void:
	var multiplier := speed_multipliers[speed_index]
	if multiplier <= 0.0:
		return

	var seconds_per_game_minute := real_seconds_per_day / (24.0 * 60.0)
	var game_minutes_per_tick := (TICK_INTERVAL * multiplier) / seconds_per_game_minute
	_advance_time(game_minutes_per_tick)


func _advance_time(game_minutes: float) -> void:
	_accumulated += game_minutes
	if _accumulated < 1.0:
		return

	var whole_minutes := int(_accumulated)
	_accumulated -= float(whole_minutes)

	minute += whole_minutes
	while minute >= 60:
		minute -= 60
		hour += 1
	while hour >= 24:
		hour -= 24
		day += 1

	total_hours += float(whole_minutes) / 60.0

	if day != _previous_day:
		_previous_day = day
		day_changed.emit(day)

	time_changed.emit(day, hour, minute)


func set_speed(index: int) -> void:
	var clamped := clampi(index, 0, speed_multipliers.size() - 1)
	if clamped == speed_index:
		return
	speed_index = clamped
	is_paused = (speed_index == 0)
	speed_changed.emit(speed_index)


func toggle_pause() -> void:
	if is_paused:
		set_speed(1)
	else:
		set_speed(0)


func speed_up() -> void:
	set_speed(speed_index + 1)


func speed_down() -> void:
	set_speed(speed_index - 1)
