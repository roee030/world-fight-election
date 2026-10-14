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
var _lights: Array[OmniLight3D] = []
var _glows: Array[MeshInstance3D] = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func configure(stage: Dictionary) -> void:
	stage_id = str(stage.get("id", "unknown"))
	stage_kind = str(stage.get("kind", "generic"))
	_pulse = 0.0
	_ensure_lights()
	_ensure_glows()
	var accent := Color(str(stage.get("accent", "#65d8ff")))
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
	_pulse = maxf(0.0, _pulse - DECAY_PER_SECOND * maxf(0.0, delta))
	_update_lights()


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


func _update_lights() -> void:
	var energy := _pulse * MAX_LIGHT_ENERGY
	for light in _lights:
		light.light_energy = energy
	for glow in _glows:
		(glow.material_override as ShaderMaterial).set_shader_parameter("strength", _pulse)
