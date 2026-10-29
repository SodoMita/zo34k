extends Node
## Shared settings persistence (user://settings.json).
## The title screen and the VN balloon both read and write this file,
## so a change anywhere applies everywhere. Values use the same keys
## and 0..100 volume scale as the in-game settings panel.

const SETTINGS_PATH := "user://settings.json"

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
			data = parsed
	return data


func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()


func get_value(key: String, default: Variant = null) -> Variant:
	return data.get(key, default)


func set_value(key: String, value: Variant) -> void:
	set_values({key: value})


## Write several keys with one save (used by the shared settings menu on the title).
func set_values(values: Dictionary) -> void:
	data.merge(values, true)
	save_settings()
	apply_globals()
	for key: String in values:
		settings_changed.emit(key, values[key])


## Apply the display/audio settings that matter outside the VN scene too.
func apply_globals() -> void:
	var lang := str(data.get("language", ""))
	if lang.is_empty():
		lang = "ru" if TranslationServer.get_locale().left(2) == "ru" else "en"
	TranslationServer.set_locale(lang)
	if DisplayServer.get_name() != "headless":
		if data.has("fullscreen"):
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if bool(data.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED
			)
		if data.has("vsync"):
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if bool(data.vsync) else DisplayServer.VSYNC_DISABLED
			)
	for bus_name: String in ["Master", "Music", "Voice", "Sfx"]:
		if data.has("vol_%s" % bus_name.to_lower()):
			_set_bus_volume(bus_name, float(data["vol_%s" % bus_name.to_lower()]))


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	var linear: float = clampf(volume, 0.0, 100.0) / 100.0
	AudioServer.set_bus_volume_db(index, linear_to_db(linear) if linear > 0.0 else -80.0)
