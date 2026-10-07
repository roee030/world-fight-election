class_name FinisherDirector
extends Node

signal sequence_started(attacker_id: String)
signal final_hit(defender_index: int)
signal celebration_started(id: String)
signal result_ready(winner_index: int)
signal cancelled(reason: String)

var catalog: Variant
const TimelineScript = preload("res://scripts/finishers/finisher_timeline.gd")
const ActorScript = preload("res://scripts/finishers/finisher_actor.gd")
var timeline := TimelineScript.new()
var active := false
var diagnostic := ""
var reduced_motion := false
var effect_density := "desktop"
var _host: Node
var _arena: Node3D
var _camera: Camera3D
var _camera_transform := Transform3D.IDENTITY
var _camera_size := 1.0
var _attacker: GameFighter
var _defender: GameFighter
var _definition: Dictionary
var _actors: Dictionary = {}
var _presentation: Array[Node] = []
var _paused := false
var _final := false
var _celebrating := false
var _lightbox := false
var _hit_ids := PackedStringArray()
var _impact_remaining := 0.0
var _impact_origin := Vector3.ZERO
var _lifetimes: Dictionary = {}
var _clocks: Array[Dictionary] = []

func configure(host: Node, arena: Node3D, camera: Camera3D) -> void:
	_host = host
	_arena = arena
	_camera = camera

func begin(attacker: GameFighter, defender: GameFighter, definition: Dictionary) -> bool:
	if active or attacker == null or defender == null or defender.health <= 0 or not definition.get("implemented", false): return false
	var cost := float(definition.get("meter_cost", 100))
	if attacker.meter < cost: return false
	var celebration := _celebration(str(definition.get("celebration_id", "")))
	if celebration.is_empty(): return false
	_attacker = attacker
	_defender = defender
	_definition = definition.duplicate(true)
	_final = false
	_celebrating = false
	_lightbox = false
	_hit_ids.clear()
	_paused = false
	active = true
	diagnostic = ""
	if _camera:
		_camera_transform = _camera.transform
		_camera_size = _camera.size
	var direction := 1.0 if defender.position.x >= attacker.position.x else -1.0
	var midpoint := clampf((attacker.position.x + defender.position.x) * 0.5, -3.8, 3.8)
	attacker.enter_cinematic_lock(Vector3(midpoint - direction * 0.8, 0, 0), direction)
	defender.enter_cinematic_lock(Vector3(midpoint + direction * 0.8, 0, 0), -direction)
	attacker.meter -= cost
	attacker.meter_changed.emit(attacker.who, attacker.meter)
	timeline.start(_definition)
	_camera_preset(str(_definition.get("camera_preset", "wide_stage")))
	sequence_started.emit(attacker.character_id)
	return true

func _celebration(id: String) -> Dictionary:
	var source = catalog
	if source == null and _host != null: source = _host.get("_finisher_catalog")
	if source is Dictionary: return source.get(id, {}).duplicate(true)
	if source != null and source.has_method("celebration_for"): return source.celebration_for(id)
	return {}

func advance(delta: float) -> void:
	if not active or _paused: return
	for actor in _actors.values(): actor.advance(delta)
	for node in _lifetimes.keys():
		_lifetimes[node] -= delta
		if _lifetimes[node] <= 0:
			_lifetimes.erase(node)
			_presentation.erase(node)
			node.free()
	for clock in _clocks:
		clock.elapsed = minf(clock.duration, clock.elapsed + delta)
		var seconds := int(lerpf(clock.from, clock.to, clock.elapsed / maxf(clock.duration, 0.001)))
		clock.label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	if _impact_remaining > 0 and _camera:
		_impact_remaining = maxf(0, _impact_remaining - delta)
		if _impact_remaining == 0: _camera.position = _impact_origin
	var was_celebrating := _celebrating
	for event in timeline.advance(delta):
		if not active: break
		_dispatch(event)
		if _celebrating != was_celebrating: break
	if active and timeline.is_finished():
		_fail("Timeline ended without a celebration or result marker")

func _dispatch(event: Dictionary) -> void:
	match str(event.get("type", "")):
		"hit":
			if _celebrating or _final: return
			var id := str(event.get("id", ""))
			if id.is_empty():
				_fail("Authored hit has no event ID")
				return
			if _hit_ids.has(id): return
			var ending := bool(event.get("final", false))
			var damage := float(event.get("damage", 0))
			if ending: damage = maxf(damage, _defender.health)
			else: damage = minf(damage, maxf(0, _defender.health - 1))
			if not ending and damage <= 0 and _defender.health > 0:
				_hit_ids.append(id)
				return
			if not _defender.apply_authored_hit(id, damage, _attacker.facing, str(event.get("reaction", "hit"))):
				_fail("Authored hit rejected: " + id)
				return
			_hit_ids.append(id)
			if ending:
				_final = true
				final_hit.emit(_defender.who)
		"celebration_start":
			if not _final or _celebrating:
				_fail("Celebration requires one final hit")
				return
			_cleanup_presentation()
			_celebrating = true
			var id := str(_definition.get("celebration_id", ""))
			timeline.start(_celebration(id))
			celebration_started.emit(id)
		"result_marker":
			if not _celebrating or not _final:
				_fail("Result marker outside celebration")
				return
			var winner := _attacker.who
			cancel()
			result_ready.emit(winner)
		"spawn_actor", "spawn_prop":
			var id := str(event.get("id", event.get("asset", "")))
			if _actors.has(id):
				_fail("Duplicate actor ID: " + id)
				return
			if effect_density == "mobile" and _actors.size() >= 12: return
			var actor := ActorScript.new()
			if not actor.configure(event):
				actor.free()
				_fail("Missing or invalid transparent actor resource: " + str(event.get("asset", "")))
				return
			_arena.add_child(actor)
			actor.reduced_motion = reduced_motion
			_actors[id] = actor
		"move_actor", "launch_prop":
			var id := str(event.get("id", event.get("actor", "")))
			if not _actors.has(id):
				_fail("Motion references missing actor: " + id)
				return
			var target := ActorScript.vector_from(event.get("position", [0, 0, 0]))
			if event.get("target", "") == "defender": target = _defender.position + Vector3(0, 1, 0)
			_actors[id].move_to(target, float(event.get("duration", 0.3)), reduced_motion)
		"fighter_clip", "defender_reaction":
			var fighter := _defender if event.get("target", "attacker") == "defender" or event.type == "defender_reaction" else _attacker
			if not fighter._visual.is_empty():
				var clip := str(event.get("clip", event.get("reaction", "idle")))
				if fighter._visual.sprite.sprite_frames.has_animation(clip): fighter._visual.sprite.play(clip)
				fighter._visual.motion.play_state(clip, false, float(event.get("duration", 0.0)))
		"portrait_lightbox":
			if _lightbox:
				_fail("Duplicate portrait lightbox")
				return
			_lightbox = true
			_caption(_attacker.character_id.to_upper(), true)
		"caption":
			var label := _caption(str(event.get("text", "")), false)
			if event.has("clock_from"):
				_clocks.append({"label": label, "from": float(event.clock_from), "to": float(event.get("clock_to", 0)), "elapsed": 0.0, "duration": float(event.get("duration", 1))})
		"sound":
			var path := str(event.get("asset", ""))
			var stream = ResourceLoader.load(path) if ResourceLoader.exists(path) else null
			if not stream is AudioStream:
				_fail("Missing sound: " + path)
				return
			var player := AudioStreamPlayer.new()
			player.stream = stream
			add_child(player)
			_presentation.append(player)
			player.play()
		"camera_preset": _camera_preset(str(event.get("preset", "wide_stage")))
		"camera_impact":
			if _camera and not reduced_motion:
				if _impact_remaining > 0: _camera.position = _impact_origin
				_impact_origin = _camera.position
				_impact_remaining = 0.12
				_camera.position.x += minf(float(event.get("strength", 0.2)), 0.12 if effect_density == "mobile" else 0.3)
		"screen_flash":
			if not reduced_motion: _caption("", false, true)
		"cleanup": _cleanup_presentation()
		_: _fail("Unknown finisher event: " + str(event.get("type", "")))

func _camera_preset(preset: String) -> void:
	if not _camera: return
	match preset:
		"close_side": _camera.size = _camera_size * 0.85
		"wide_stage", "overhead_pass": _camera.size = _camera_size * 1.12
		"projectile_track": _camera.size = _camera_size
		"victory_low": _camera.size = _camera_size * 0.92
		_: _fail("Unknown camera preset: " + preset)

func _caption(text: String, portrait: bool, flash: bool = false) -> Label:
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	_presentation.append(layer)
	var label := Label.new()
	label.text = text
	label.position = Vector2(390, 135 if portrait else 565)
	label.size = Vector2(500, 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 38 if portrait else 26)
	layer.add_child(label)
	if portrait:
		var path := "res://assets/characters/portraits/%s.png" % _attacker.character_id
		if ResourceLoader.exists(path):
			var image := TextureRect.new()
			image.texture = ResourceLoader.load(path)
			image.position = Vector2(530, 195)
			image.size = Vector2(220, 220)
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			layer.add_child(image)
		_lifetimes[layer] = 0.35
	if flash:
		var rect := ColorRect.new()
		rect.color = Color(1, 1, 1, 0.15)
		rect.size = Vector2(1280, 720)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(rect)
		_lifetimes[layer] = 0.08
	return label

func set_paused(value: bool) -> void:
	_paused = value
	timeline.set_paused(value)
	for node in _presentation:
		if node is AudioStreamPlayer: node.stream_paused = value

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	for actor in _actors.values(): actor.reduced_motion = value
func set_effect_density(value: String) -> void: effect_density = "mobile" if value == "mobile" else "desktop"
func temporary_actor_count() -> int: return _actors.size()
func consumed_hit_ids() -> PackedStringArray: return _hit_ids.duplicate()
func current_event_key() -> String: return timeline.current_event_key()

func _cleanup_presentation() -> void:
	for actor in _actors.values(): actor.free()
	_actors.clear()
	for node in _presentation:
		if is_instance_valid(node): node.free()
	_presentation.clear()
	_lifetimes.clear()
	_clocks.clear()
	_impact_remaining = 0

func cancel() -> void:
	var was_active := active
	active = false
	timeline.cancel()
	_cleanup_presentation()
	if is_instance_valid(_attacker): _attacker.exit_cinematic_lock()
	if is_instance_valid(_defender): _defender.exit_cinematic_lock()
	if was_active and is_instance_valid(_camera):
		_camera.transform = _camera_transform
		_camera.size = _camera_size

func _exit_tree() -> void:
	if active: cancel()

func _fail(reason: String) -> void:
	diagnostic = reason
	push_warning(reason)
	cancel()
	cancelled.emit(reason)
