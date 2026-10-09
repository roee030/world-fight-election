class_name AudioManager
extends Node

const SCHEMA_VERSION := 1
const DEFAULTS := {
	&"master": 85.0,
	&"music": 45.0,
	&"sfx": 75.0,
	&"voice": 85.0,
}
const BUS_NAMES := {
	&"master": &"Master",
	&"music": &"Music",
	&"sfx": &"SFX",
	&"voice": &"Voice",
}

var settings_path := "user://audio_settings.cfg"
var _volumes := DEFAULTS.duplicate()
var _muted := false

func _ready() -> void:
	_ensure_buses()
	_apply_all()

func configure_for_tests(path: String) -> void:
	settings_path = path
	_volumes = DEFAULTS.duplicate()
	_muted = false
	_ensure_buses()
	_apply_all()

func load_settings() -> void:
	_volumes = DEFAULTS.duplicate()
	_muted = false
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		for category in DEFAULTS:
			var value = config.get_value("audio", String(category), DEFAULTS[category])
			if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
				_volumes[category] = clampf(float(value), 0.0, 100.0)
		_muted = bool(config.get_value("audio", "muted", false))
	_apply_all()

func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("audio", "schema_version", SCHEMA_VERSION)
	for category in DEFAULTS:
		config.set_value("audio", String(category), _volumes[category])
	config.set_value("audio", "muted", _muted)
	return config.save(settings_path)

func set_volume(category: StringName, percent: float, persist := true) -> void:
	if not DEFAULTS.has(category):
		push_warning("Unknown audio category: %s" % category)
		return
	_volumes[category] = clampf(percent, 0.0, 100.0)
	_apply_volume(category)
	if persist:
		save_settings()

func get_volume(category: StringName) -> float:
	return float(_volumes.get(category, 0.0))

func set_muted(value: bool, persist := true) -> void:
	_muted = value
	var master_index := AudioServer.get_bus_index(&"Master")
	if master_index >= 0:
		AudioServer.set_bus_mute(master_index, value)
	if persist:
		save_settings()

func is_muted() -> bool:
	return _muted

func reset_defaults() -> void:
	_volumes = DEFAULTS.duplicate()
	_muted = false
	_apply_all()
	save_settings()

func _ensure_buses() -> void:
	for bus_name in [&"Music", &"SFX", &"Voice"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func _apply_all() -> void:
	_ensure_buses()
	for category in DEFAULTS:
		_apply_volume(category)
	var master_index := AudioServer.get_bus_index(&"Master")
	if master_index >= 0:
		AudioServer.set_bus_mute(master_index, _muted)

func _apply_volume(category: StringName) -> void:
	var index := AudioServer.get_bus_index(BUS_NAMES[category])
	if index < 0:
		return
	var linear := maxf(float(_volumes[category]) / 100.0, 0.0001)
	AudioServer.set_bus_volume_db(index, linear_to_db(linear))
