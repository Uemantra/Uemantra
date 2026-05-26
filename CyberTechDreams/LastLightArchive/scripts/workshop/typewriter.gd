extends RefCounted

signal complete

const CURSOR_CHAR: String = "▌"

var _target: RichTextLabel
var _full_text: String
var _chars_per_tick: int
var _position: int = 0
var _timer: Timer
var _cursor_timer: Timer
var _cursor_visible: bool = true
var _done: bool = false


func _init(target: RichTextLabel, full_text: String, chars_per_tick: int = 2) -> void:
	_target = target
	_full_text = full_text
	_chars_per_tick = max(1, chars_per_tick)


func start() -> void:
	_position = 0
	_done = false
	_cursor_visible = true

	_timer = Timer.new()
	_timer.wait_time = 0.04
	_timer.one_shot = false
	_timer.timeout.connect(_on_tick)
	_target.add_child(_timer)
	_timer.start()

	_cursor_timer = Timer.new()
	_cursor_timer.wait_time = 0.5
	_cursor_timer.one_shot = false
	_cursor_timer.timeout.connect(_on_cursor_tick)
	_target.add_child(_cursor_timer)
	_cursor_timer.start()


func stop() -> void:
	_cleanup_timers()
	_done = true


func is_complete() -> bool:
	return _done


func skip_to_end() -> void:
	_position = _full_text.length()
	_done = true
	_cleanup_timers()
	_target.text = _full_text
	complete.emit()


func _on_tick() -> void:
	if _done:
		return
	_position = min(_position + _chars_per_tick, _full_text.length())
	var partial: String = _full_text.substr(0, _position)
	if _cursor_visible and _position < _full_text.length():
		_target.text = partial + CURSOR_CHAR
	else:
		_target.text = partial
	if _position >= _full_text.length():
		_done = true
		_cleanup_timers()
		_target.text = _full_text
		complete.emit()


func _on_cursor_tick() -> void:
	if _done:
		return
	_cursor_visible = not _cursor_visible
	var partial: String = _full_text.substr(0, _position)
	if _cursor_visible:
		_target.text = partial + CURSOR_CHAR
	else:
		_target.text = partial


func _cleanup_timers() -> void:
	if _timer and is_instance_valid(_timer):
		_timer.stop()
		_timer.queue_free()
		_timer = null
	if _cursor_timer and is_instance_valid(_cursor_timer):
		_cursor_timer.stop()
		_cursor_timer.queue_free()
		_cursor_timer = null
