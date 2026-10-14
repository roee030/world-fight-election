extends Node3D

const MAX_PULSE := 1.0
const MAX_LIGHT_ENERGY := 1.15
const DECAY_PER_SECOND := 1.8
const MOVE_IMPULSE := {
	"light": 0.22,
	"heavy": 0.50,
	"kick": 0.62,
	"special": 0.80,
}

var stage_id := ""
var stage_kind := ""
var _pulse := 0.0
var _phase := 0.0
var _lights: Array[OmniLight3D] = []
var _glows: Array[MeshInstance3D] = []
var _prop_root: Node3D


func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func configure(stage: Dictionary) -> void:
	stage_id = str(stage.get("id", "unknown"))
	stage_kind = str(stage.get("kind", "generic"))
	_pulse = 0.0
	_phase = 0.0
	_ensure_lights()
	_ensure_glows()
	var accent := Color(str(stage.get("accent", "#65d8ff")))
	_rebuild_props(accent)
	for light in _lights:
		light.light_color = accent
	for glow in _glows:
		(glow.material_override as ShaderMaterial).set_shader_parameter("glow_color", accent)
	_update_lights()


func react_to_strike(move: String, blocked: bool, combo: int) -> void:
	var impulse := float(MOVE_IMPULSE.get(move, MOVE_IMPULSE.light))
	if blocked:
		impulse *= 0.42
	else:
		impulse += float(clampi(combo - 1, 0, 4)) * 0.04
	_pulse = minf(MAX_PULSE, _pulse + impulse)
	_update_lights()


func advance(delta: float) -> void:
	var step := maxf(0.0, delta)
	_phase += step
	_pulse = maxf(0.0, _pulse - DECAY_PER_SECOND * step)
	_update_lights()
	_update_props()


func _physics_process(delta: float) -> void:
	advance(delta)


func _ensure_lights() -> void:
	if not _lights.is_empty():
		return
	for light_data in [
		{"name": "LeftPulse", "position": Vector3(-3.4, 2.5, 0.6)},
		{"name": "RightPulse", "position": Vector3(3.4, 2.5, 0.6)},
	]:
		var light := OmniLight3D.new()
		light.name = str(light_data.name)
		light.position = light_data.position
		light.omni_range = 6.5
		light.omni_attenuation = 1.7
		light.shadow_enabled = false
		add_child(light)
		_lights.append(light)


func _ensure_glows() -> void:
	if not _glows.is_empty():
		return
	var glow_shader := Shader.new()
	glow_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 glow_color : source_color = vec4(0.4, 0.85, 1.0, 1.0);
uniform float strength = 0.0;
void fragment() {
	float halo = smoothstep(0.5, 0.05, distance(UV, vec2(0.5)));
	ALBEDO = glow_color.rgb;
	EMISSION = glow_color.rgb * strength;
	ALPHA = halo * strength * 0.24;
}
"""
	for glow_data in [
		{"name": "LeftGlow", "position": Vector3(-3.1, 1.4, -6.4)},
		{"name": "RightGlow", "position": Vector3(3.1, 1.4, -6.4)},
	]:
		var glow := MeshInstance3D.new()
		glow.name = str(glow_data.name)
		glow.position = glow_data.position
		var quad := QuadMesh.new()
		quad.size = Vector2(6.2, 5.0)
		glow.mesh = quad
		var material := ShaderMaterial.new()
		material.shader = glow_shader
		glow.material_override = material
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(glow)
		_glows.append(glow)


func _rebuild_props(accent: Color) -> void:
	if is_instance_valid(_prop_root):
		_prop_root.free()
	var root_name := "StudioSweep" if stage_kind == "studio" else ("StreetDust" if stage_kind == "street" else "CrowdWave")
	_prop_root = Node3D.new()
	_prop_root.name = root_name
	add_child(_prop_root)
	var specs: Array
	match root_name:
		"StudioSweep":
			specs = [Vector3(-3.2, 2.25, -6.25), Vector3(0.0, 2.0, -6.25), Vector3(3.2, 2.25, -6.25)]
		"StreetDust":
			specs = [Vector3(-4.0, 0.32, -6.2), Vector3(-1.35, 0.25, -6.2), Vector3(1.35, 0.25, -6.2), Vector3(4.0, 0.32, -6.2)]
		_:
			specs = [Vector3(-4.2, 0.78, -6.22), Vector3(-1.4, 0.68, -6.22), Vector3(1.4, 0.68, -6.22), Vector3(4.2, 0.78, -6.22)]
	for index in range(specs.size()):
		var prop := MeshInstance3D.new()
		prop.name = "%s_%d" % [root_name, index]
		prop.position = specs[index]
		prop.set_meta("base_position", specs[index])
		var quad := QuadMesh.new()
		quad.size = Vector2(2.2, 0.12) if root_name == "StudioSweep" else (Vector2(2.3, 0.42) if root_name == "StreetDust" else Vector2(0.48, 1.05))
		prop.mesh = quad
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(accent, 0.08)
		material.emission_enabled = true
		material.emission = accent
		material.emission_energy_multiplier = 0.18
		prop.material_override = material
		prop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_prop_root.add_child(prop)
	_update_props()


func _update_props() -> void:
	if not is_instance_valid(_prop_root):
		return
	for index in range(_prop_root.get_child_count()):
		var prop := _prop_root.get_child(index) as MeshInstance3D
		var base: Vector3 = prop.get_meta("base_position")
		var wave := sin(_phase * (5.0 if stage_kind != "street" else 2.6) + float(index) * 1.3)
		if _prop_root.name == "StudioSweep":
			prop.position = base + Vector3(wave * 0.34 * _pulse, wave * 0.05 * _pulse, 0.0)
			prop.rotation.z = wave * 0.12 * _pulse
		elif _prop_root.name == "StreetDust":
			prop.position = base + Vector3(wave * 0.22 * _pulse, absf(wave) * 0.12 * _pulse, 0.0)
			prop.scale.x = 1.0 + 0.35 * _pulse
		else:
			prop.position = base + Vector3(0.0, wave * 0.16 * _pulse, 0.0)
			prop.rotation.z = wave * 0.10 * _pulse
		var material := prop.material_override as StandardMaterial3D
		material.albedo_color.a = 0.08 + _pulse * 0.24
		material.emission_energy_multiplier = 0.18 + _pulse * 0.72


func _update_lights() -> void:
	var energy := _pulse * MAX_LIGHT_ENERGY
	for light in _lights:
		light.light_energy = energy
	for glow in _glows:
		(glow.material_override as ShaderMaterial).set_shader_parameter("strength", _pulse)
