extends SceneTree

const AudioManagerScript = preload("res://scripts/audio/audio_manager.gd")
const SETTINGS_PATH := "user://audio-settings-test.cfg"

func _init() -> void:
	call_deferred("_run")

func _fresh():
	var manager = AudioManagerScript.new()
	root.add_child(manager)
	manager.configure_for_tests(SETTINGS_PATH)
	return manager

func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	var manager = _fresh()
	for bus in [&"Master", &"Music", &"SFX", &"Voice"]:
		assert(AudioServer.get_bus_index(bus) >= 0, "missing audio bus %s" % bus)
	assert(manager.get_volume(&"master") == 85.0)
	assert(manager.get_volume(&"music") == 45.0)
	assert(manager.get_volume(&"sfx") == 75.0)
	assert(manager.get_volume(&"voice") == 85.0)
	manager.set_volume(&"music", 23.0)
	assert(manager.get_volume(&"music") == 23.0 and manager.get_volume(&"sfx") == 75.0)
	manager.set_muted(true)
	assert(manager.is_muted() and manager.get_volume(&"music") == 23.0)
	manager.set_muted(false)
	manager.free()

	manager = _fresh()
	manager.load_settings()
	assert(manager.get_volume(&"music") == 23.0 and not manager.is_muted(), "settings did not reload")
	manager.reset_defaults()
	assert(manager.get_volume(&"master") == 85.0 and manager.get_volume(&"music") == 45.0)
	manager.free()

	var cfg := ConfigFile.new()
	cfg.set_value("audio", "schema_version", 1)
	cfg.set_value("audio", "master", 250.0)
	cfg.set_value("audio", "music", "broken")
	cfg.set_value("audio", "sfx", 31.0)
	cfg.set_value("audio", "voice", -8.0)
	cfg.set_value("audio", "muted", false)
	assert(cfg.save(SETTINGS_PATH) == OK)
	manager = _fresh()
	manager.load_settings()
	assert(manager.get_volume(&"master") == 100.0)
	assert(manager.get_volume(&"music") == 45.0)
	assert(manager.get_volume(&"sfx") == 31.0)
	assert(manager.get_volume(&"voice") == 0.0)
	manager.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	print("PASS: audio settings defaults, buses, persistence, mute, reset and malformed fields")
	quit(0)
