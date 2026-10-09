extends Node
## Downloads the deferred Web content pack (finisher art) in the background.
##
## The first download only carries the menu, fighters and stages, so the game
## opens sooner. This node starts fetching the finisher pack as soon as the
## engine is running, which includes the time the player spends on the browser's
## rotate-phone and disclaimer screens. Outside the Web build every asset is
## already in the project, so the pack counts as loaded immediately.

signal pack_ready

const PACK_URL := "finishers.pck"
const PACK_PATH := "user://finishers.pck"
const MAX_ATTEMPTS := 4
const PROBE_ASSET := "res://assets/finishers/bibi/super-card.png"

var loaded := false
var _attempts := 0
var _request: HTTPRequest


func _ready() -> void:
	if not OS.has_feature("web"):
		_mark_loaded()
		return
	_start_download()


func is_loaded() -> bool:
	return loaded


func _mark_loaded() -> void:
	loaded = true
	pack_ready.emit()


func _start_download() -> void:
	_attempts += 1
	if is_instance_valid(_request):
		_request.queue_free()
	_request = HTTPRequest.new()
	_request.accept_gzip = false
	_request.request_completed.connect(_on_request_completed)
	add_child(_request)
	var url := str(JavaScriptBridge.eval("new URL('%s', location.href).href" % PACK_URL))
	# Revalidate: a stale cached pack from an older deploy would not match the game.
	var error := _request.request(url, PackedStringArray(["Cache-Control: no-cache"]))
	if error != OK:
		_retry_later()


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var pack_ok := false
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var file := FileAccess.open(PACK_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(body)
			file.close()
			pack_ok = ProjectSettings.load_resource_pack(PACK_PATH, true) and load(PROBE_ASSET) is Texture2D
	print("finisher pack: result=%d code=%d loaded=%s" % [result, code, pack_ok])
	if pack_ok:
		_mark_loaded()
		return
	_retry_later()


func _retry_later() -> void:
	if _attempts >= MAX_ATTEMPTS:
		push_warning("Finisher pack could not be downloaded; finishers stay unavailable.")
		return
	get_tree().create_timer(2.0 * _attempts).timeout.connect(_start_download)
