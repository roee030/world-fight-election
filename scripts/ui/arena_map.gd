class_name ArenaMap
extends Control

signal stage_selected(stage_id: String)

const NODE_RADIUS := 16.0
const MARGIN := Vector2(42, 36)

var stages: Array[Dictionary] = []
var selected_stage_id := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func set_stages(values: Array) -> void:
	stages.clear()
	for value in values:
		if value is Dictionary and not str(value.get("id", "")).is_empty():
			stages.append(Dictionary(value).duplicate(true))
	if selected_stage_id.is_empty() and not stages.is_empty():
		selected_stage_id = str(stages[0].id)
	queue_redraw()


func stage_ids() -> Array[String]:
	var ids: Array[String] = []
	for stage in stages:
		ids.append(str(stage.id))
	return ids


func select_stage(stage_id: String) -> bool:
	if not stage_ids().has(stage_id):
		return false
	if selected_stage_id != stage_id:
		selected_stage_id = stage_id
		queue_redraw()
		stage_selected.emit(stage_id)
	return true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for stage in stages:
			if event.position.distance_to(_stage_position(stage)) <= NODE_RADIUS * 1.75:
				select_stage(str(stage.id))
				accept_event()
				return


func _draw() -> void:
	var frame := Rect2(Vector2.ZERO, size)
	draw_style_box(_panel_style(), frame)
	if stages.is_empty():
		return
	var points := PackedVector2Array()
	for stage in stages:
		points.append(_stage_position(stage))
	if points.size() > 1:
		draw_polyline(points, Color("37566a"), 2.0, true)
	for stage in stages:
		var point := _stage_position(stage)
		var selected := str(stage.id) == selected_stage_id
		var accent := Color(str(stage.get("accent", "#46dcd8")))
		draw_circle(point, NODE_RADIUS + 7.0, Color(accent, 0.13 if selected else 0.05))
		draw_circle(point, NODE_RADIUS, accent if selected else Color("203a4a"))
		draw_arc(point, NODE_RADIUS + 3.0, 0.0, TAU, 28, Color("f2d98c") if selected else Color("6e8996"), 2.0)
		var label := str(stage.get("name", stage.id)).replace(" • ", " ")
		var font := ThemeDB.fallback_font
		var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, point + Vector2(-label_width * 0.5, 39), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f4f7f6") if selected else Color("afc0c5"))
	var title_font := ThemeDB.fallback_font
	draw_string(title_font, Vector2(22, 25), "INTERACTIVE ARENA MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e8b94f"))


func _stage_position(stage: Dictionary) -> Vector2:
	var normalized: Vector2 = stage.get("map_position", Vector2(0.5, 0.5))
	var usable := size - MARGIN * 2.0
	return MARGIN + Vector2(normalized.x * usable.x, normalized.y * usable.y)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101c28")
	style.border_color = Color("3b6270")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
