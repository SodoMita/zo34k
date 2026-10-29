extends Node
## Shared settings persistence for the title screen and VN balloon.

const SETTINGS_PATH := "user://settings.json"
const BOOLEAN_KEYS := [
	"sync_voice", "skip_seen_only", "force_portrait", "fullscreen", "vsync",
	"procedural_music", "sfx_typewriter", "sfx_buttons",
]
const NUMERIC_KEYS := [
	"text_speed", "text_size", "skip_speed", "auto_delay", "ui_scale", "sprite_scale",
	"sprite_y", "vol_master", "vol_music", "vol_voice", "vol_sfx", "rotation", "res_w",
	"res_h", "glyph_scale", "game_filter", "map_filter",
]

signal settings_changed(key: String, value: Variant)

var data: Dictionary = {}


func _ready() -> void:
	load_settings()
	apply_globals()


func load_settings() -> Dictionary:
	data = {}
	if FileAccess.file_exists(SETTINGS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if parsed is Dictionary:
			data = parsed.duplicate(true)
	_normalize_data()
	return data


func save_settings() -> bool:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write settings to %s (error %d)" % [SETTINGS_PATH, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true


func get_value(key: String, default: Variant = null) -> Variant:
	return data.get(key, default)


func set_value(key: String, value: Variant) -> void:
	set_values({key: value})


## Apply a batch atomically and emit only after the persisted shape is normalized.
func set_values(values: Dictionary) -> void:
	data.merge(values, true)
	_normalize_data()
	save_settings()
	apply_globals()
	for key: String in values:
		if data.has(key):
			settings_changed.emit(key, data[key])


func _normalize_data() -> void:
	for key: String in BOOLEAN_KEYS:
		if data.has(key) and not data[key] is bool:
			data.erase(key)
	for key: String in NUMERIC_KEYS:
		if data.has(key) and not (data[key] is int or data[key] is float):
			data.erase(key)
	if data.has("language") and (not data.language is String or not data.language in ["ru", "en"]):
		data.erase("language")
	if data.has("rotation"):
		var rotation := posmod(int(data.rotation), 360)
		data.rotation = rotation if rotation in [0, 90, 180, 270] else 0
	for key: String in ["vol_master", "vol_music", "vol_voice", "vol_sfx"]:
		if data.has(key):
			data[key] = clampf(float(data[key]), 0.0, 100.0)
	if data.has("ui_scale"):
		data.ui_scale = clampf(float(data.ui_scale), 0.5, 2.5)


## Apply the display/audio settings that matter outside the VN scene too.
func apply_globals() -> void:
	var lang := str(data.get("language", ""))
	if lang.is_empty():
		lang = "ru" if TranslationServer.get_locale().left(2) == "ru" else "en"
	TranslationServer.set_locale(lang)
	if DisplayServer.get_name() != "headless":
		if data.has("fullscreen"):
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if data.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
			)
		if data.has("vsync"):
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if data.vsync else DisplayServer.VSYNC_DISABLED
			)
	for bus_name: String in ["Master", "Music", "Voice", "Sfx"]:
		var key := "vol_%s" % bus_name.to_lower()
		if data.has(key):
			_set_bus_volume(bus_name, float(data[key]))


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	var linear := clampf(volume, 0.0, 100.0) / 100.0
	AudioServer.set_bus_volume_db(index, linear_to_db(linear) if linear > 0.0 else -80.0)
