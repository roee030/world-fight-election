extends Control
class_name VirtualStick

signal axis_changed(value: Vector2)

var axis := Vector2.ZERO
var _finger_index := -1
var _mouse_held := false
var _radius := 74.0


func _ready() -> void:
	custom_minimum_size = Vector2(190, 190)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = DisplayServer.is_touchscreen_available()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger_index == -1:
			_finger_index = event.index
			_update_from_position(event.position)
			accept_event()
		elif not event.pressed and event.index == _finger_index:
			_finger_index = -1
			_set_axis(Vector2.ZERO)
			accept_event()
	elif event is InputEventScreenDrag and event.index == _finger_index:
		_update_from_position(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _finger_index == -1:
			_mouse_held = true
			_update_from_position(event.position)
		elif not event.pressed and _mouse_held:
			_mouse_held = false
			_set_axis(Vector2.ZERO)
		accept_event()
	elif event is InputEventMouseMotion and _mouse_held:
		_update_from_position(event.position)
		accept_event()


func _update_from_position(position: Vector2) -> void:
	var center := size * 0.5
	var offset := position - center
	if offset.length() > _radius:
		offset = offset.normalized() * _radius
	_set_axis(offset / _radius)


func _set_axis(value: Vector2) -> void:
	axis = value.limit_length(1.0)
	axis_changed.emit(axis)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	_radius = minf(size.x, size.y) * 0.38
	draw_circle(center, _radius + 18.0, Color(0.03, 0.06, 0.09, 0.55))
	draw_arc(center, _radius + 18.0, 0.0, TAU, 64, Color(0.50, 0.70, 0.77, 0.52), 3.0, true)
	draw_circle(center, _radius, Color(0.18, 0.27, 0.33, 0.38))
	draw_arc(center, _radius * 0.72, 0.0, TAU, 48, Color(0.34, 0.49, 0.56, 0.28), 1.0, true)
	draw_line(center + Vector2(-_radius, 0), center + Vector2(_radius, 0), Color(0.32, 0.47, 0.54, 0.20), 1.0)
	draw_line(center + Vector2(0, -_radius), center + Vector2(0, _radius), Color(0.32, 0.47, 0.54, 0.20), 1.0)
	var arrow_color := Color(0.60, 0.75, 0.79, 0.34)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var direction := Vector2.RIGHT.rotated(angle)
		var side := direction.rotated(PI * 0.5)
		var tip := center + direction * (_radius * 0.84)
		draw_colored_polygon(PackedVector2Array([tip, tip - direction * 9.0 + side * 5.0, tip - direction * 9.0 - side * 5.0]), arrow_color)
	var knob := center + axis * _radius * 0.72
	draw_circle(knob, _radius * 0.43, Color(0.22, 0.75, 0.75, 0.82))
	draw_arc(knob, _radius * 0.43, 0.0, TAU, 48, Color(0.85, 0.95, 0.96, 0.78), 2.0, true)
	draw_circle(knob, 5.0, Color(0.10, 0.86, 0.88, 0.90))

