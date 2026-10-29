extends Node
## Optional browser-host backup. Native exports and ordinary web exports never
## contact a server. A host opts in by providing window.MILKA_CLOUD_URL.
## The normal user:// save format stays the source of truth; network failure
## never blocks play, overwrites local saves, or changes native behaviour.

var _url := ""
var _http: HTTPRequest
var _busy := false
var _restored := false
var _elapsed := 0.0
var _last_sent := ""
var _pending := ""
var _uploading := false

func _ready() -> void:
	if not OS.has_feature("web"):
		set_process(false)
		return
	var value: Variant = JavaScriptBridge.eval("window.MILKA_CLOUD_URL || ''")
	if not value is String or value.is_empty():
		set_process(false)
		return
	_url = value
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	add_child(_http)
	_http.request_completed.connect(_completed)
	_restore()

func _process(delta: float) -> void:
	_elapsed += delta
	if _busy or _elapsed < 5.0:
		return
	_elapsed = 0.0
	if not _restored:
		_restore()
		return
	var snapshot := _snapshot()
	var text := JSON.stringify(snapshot)
	var digest := text.sha256_text()
	if digest == _last_sent or (snapshot.settings.is_empty() and snapshot.saves.is_empty()):
		return
	_pending = digest
	_uploading = true
	_busy = true
	if _http.request(_url, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, text) != OK:
		_busy = false

func _restore() -> void:
	_uploading = false
	_busy = true
	if _http.request(_url) != OK:
		_busy = false

func _completed(result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		return # Retry later; never upload over a backup we failed to restore.
	if _uploading:
		_last_sent = _pending
		return
	var remote: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not remote is Dictionary:
		return
	var settings: Dictionary = remote.get("settings", {}) if remote.get("settings", {}) is Dictionary else {}
	if not settings.is_empty() and not FileAccess.file_exists("user://settings.json"):
		_write("user://settings.json", settings)
		var store := get_node_or_null("/root/SettingsStore")
		if store != null:
			store.load_settings()
			store.apply_globals()
			# A backup can arrive after the title's _ready. Notify its layout
			# listeners so restored rotation/scale apply without re-entering.
			for key: String in settings:
				store.settings_changed.emit(key, settings[key])
	var saves: Dictionary = remote.get("saves", {}) if remote.get("saves", {}) is Dictionary else {}
	DirAccess.make_dir_recursive_absolute("user://saves")
	for file_name: String in saves:
		if not file_name.begins_with("slot_") or not file_name.ends_with(".json"):
			continue
		var number := file_name.trim_prefix("slot_").trim_suffix(".json")
		if not number.is_valid_int() or int(number) < 0 or number.length() > 4 or not saves[file_name] is Dictionary:
			continue
		var path := "user://saves/" + file_name
		var local: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if local == null or _when(saves[file_name]) > _when(local):
			_write(path, saves[file_name])
	_restored = true
	_last_sent = JSON.stringify({"settings": settings, "saves": saves}).sha256_text()

func _when(data: Variant) -> String:
	if data is Dictionary and data.get("meta", {}) is Dictionary:
		return str(data.get("meta", {}).get("when", ""))
	return ""

func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))

func _snapshot() -> Dictionary:
	var settings: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json")) if FileAccess.file_exists("user://settings.json") else {}
	var saves := {}
	var dir := DirAccess.open("user://saves")
	if dir != null:
		for file_name in dir.get_files():
			if file_name.begins_with("slot_") and file_name.ends_with(".json"):
				var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://saves/" + file_name))
				if data is Dictionary:
					saves[file_name] = data
	return {"settings": settings if settings is Dictionary else {}, "saves": saves}
