class_name SettingsMenu
extends PanelContainer
## Milk-glass settings menu. ONE authored scene (settings_menu.tscn) is used by the
## title screen AND the in-game dialogue balloon, so the player always meets the
## same settings with the same look (shared theme: assets/ui/milk_glass_theme.tres).
##
## Who drives the controls:
##  * In-game: vn_balloon.gd. Its instance sets drive_settings = false and the
##    balloon wires every row itself (text speed on the label, UI scale, stage...).
##  * Title screen: this script (drive_settings = true). It reads and writes the
##    same keys of user://settings.json through the SettingsStore autoload, so what
##    the player changes on the title is what the balloon loads, and vice versa.
## No node is built from code: add a row in the scene, then map it below.

signal closed

## Title screen: true (this script drives the rows). VN balloon: false.
@export var drive_settings: bool = true

## Slider -> [settings.json key, value label ("" = none), label format]
const SLIDERS := {
	"TextSpeedSlider": ["text_speed", "TextSpeedValue", "%.3f s"],
	"TextSizeSlider": ["text_size", "TextSizeValue", "%d px"],
	"AutoDelaySlider": ["auto_delay", "AutoDelayValue", "%.2f s"],
	"UIScaleSlider": ["ui_scale", "", ""],
	"SpriteScaleSlider": ["sprite_scale", "SpriteScaleValue", "%.2fx"],
	"SpriteYSlider": ["sprite_y", "SpriteYValue", "%d px"],
	"MasterVolSlider": ["vol_master", "MasterVolValue", "%d%%"],
	"MusicVolSlider": ["vol_music", "MusicVolValue", "%d%%"],
	"VoiceVolSlider": ["vol_voice", "VoiceVolValue", "%d%%"],
	"SfxVolSlider": ["vol_sfx", "SfxVolValue", "%d%%"],
}
## CheckBox -> settings.json key
const CHECKS := {
	"SyncVoiceCheck": "sync_voice",
	"PortraitCheck": "force_portrait",
	"FullscreenCheck": "fullscreen",
	"VsyncCheck": "vsync",
	"ProceduralMusicCheck": "procedural_music",
	"TypewriterSfxCheck": "sfx_typewriter",
	"ButtonSfxCheck": "sfx_buttons",
}
## OptionButton -> [key, stored value per item index ([] = store the index)]
const OPTIONS := {
	"LanguageOption": ["language", ["en", "ru"]],
	"SkipModeOption": ["skip_seen_only", [false, true]],
	"GlyphScaleOption": ["glyph_scale", [1, 2, 3, 4]],
	"GameFilterOption": ["game_filter", []],
	"MapFilterOption": ["map_filter", []],
}
const ROTATIONS := {"Rot0Button": 0, "Rot90Button": 90, "Rot180Button": 180, "Rot270Button": 270}
const KEY_BUTTONS := {
	"AdvanceKeyButton": &"dialogue_advance",
	"SkipKeyButton": &"dialogue_skip",
	"CloseKeyButton": &"dialogue_close",
	"HistoryKeyButton": &"dialogue_history",
	"QuickSaveKeyButton": &"dialogue_save",
	"QuickLoadKeyButton": &"dialogue_load",
	"PauseKeyButton": &"dialogue_pause",
	"PanicKeyButton": &"dialogue_panic",
}


## Authored UI text does not auto-translate, so reapply it whenever locale changes.
const UI_TEXT := {
	"SettingsTitle": "Settings", "LanguageRowLabel": "Language",
	"TextSpeedRowLabel": "Text speed", "TextSizeRowLabel": "Text size",
	"SyncVoiceRowLabel": "Sync text to voice", "SkipSpeedRowLabel": "Skip speed",
	"SkipModeRowLabel": "Skip texts", "ControlsHeader": "Controls",
	"AdvanceKeyRowLabel": "Advance", "SkipKeyRowLabel": "Skip mode",
	"CloseKeyRowLabel": "Close", "HistoryKeyRowLabel": "History",
	"QuickSaveKeyRowLabel": "Quick save", "QuickLoadKeyRowLabel": "Quick load",
	"PauseKeyRowLabel": "Pause", "PanicKeyRowLabel": "Panic",
	"AutoDelayRowLabel": "Auto delay", "UIScaleRowLabel": "UI scale",
	"DisplayHeader": "Display", "PortraitRowLabel": "Portrait layout",
	"RotationRowLabel": "Rotation", "FullscreenRowLabel": "Fullscreen",
	"VsyncRowLabel": "V-Sync", "ResolutionRowLabel": "Resolution",
	"ResCustomLabel": "Custom size", "GlyphScaleRowLabel": "Glyph scale",
	"GameFilterRowLabel": "Game filter", "MapFilterRowLabel": "Map filter",
	"AudioHeader": "Audio", "ProceduralMusicRowLabel": "Generated music",
	"MasterVolRowLabel": "Master volume", "MusicVolRowLabel": "Music volume",
	"VoiceVolRowLabel": "Voice volume", "SfxVolRowLabel": "SFX volume",
	"TypewriterSfxRowLabel": "Typewriter sound", "ButtonSfxRowLabel": "Button sound",
	"SpritesHeader": "Sprites", "SpriteScaleRowLabel": "Sprite scale",
	"SpriteYRowLabel": "Sprite Y offset",
	"SettingsHint": "Settings are saved automatically. Use Close or X to exit.",
}
const OPTION_ITEM_MSGIDS := {
	"LanguageOption": ["English", "Russian"],
	"SkipModeOption": ["Everything", "Seen only"],
	"ResolutionOption": ["1280 x 720", "1600 x 900", "1920 x 1080", "2560 x 1440", "Custom"],
	"GlyphScaleOption": ["1× Low", "2× Medium", "3× High", "4× Ultra"],
	"GameFilterOption": ["Nearest", "Linear", "Nearest mipmaps", "Linear mipmaps"],
	"MapFilterOption": ["Nearest", "Linear", "Nearest mipmaps", "Linear mipmaps"],
}

const HoldTiming = preload("res://scenes/ui/hold_timing.gd")

@onready var close_button: Button = %MenuCloseButton
@onready var hold_indicator: HoldIndicator = %TitleHoldIndicator

var _hold_active := false
var _hold_elapsed := 0.0
var _hold_from := Vector2.ZERO
var _hold_local := Vector2.ZERO


var _listening: StringName = &""
var _loading := false


func _ready() -> void:
	_translate_authored_text()
	# In-game the balloon owns the floating close button and every row.
	close_button.visible = drive_settings
	hold_indicator.hide_ring()
	if not drive_settings:
		return
	close_button.pressed.connect(close)
	gui_input.connect(_on_empty_press)
	for n: String in SLIDERS:
		_connect(n, &"value_changed", _on_slider_changed.bind(n))
	for n: String in CHECKS:
		_connect(n, &"toggled", _on_check_toggled.bind(n))
	for n: String in OPTIONS:
		_connect(n, &"item_selected", _on_option_selected.bind(n))
	for n: String in ROTATIONS:
		_connect(n, &"pressed", _on_rotation_pressed.bind(n))
	for n: String in KEY_BUTTONS:
		_connect(n, &"pressed", _on_key_button_pressed.bind(n))
	_connect("SkipSpeedSlider", &"value_changed", _on_skip_slider_changed)
	_connect("SkipSpeedValue", &"value_changed", _on_skip_spin_changed)
	_connect("UIScaleValue", &"value_changed", func(v: float) -> void: _set_range("UIScaleSlider", v, true))
	_connect("ResolutionOption", &"item_selected", _on_resolution_selected)
	_connect("ResWidthSpin", &"value_changed", func(_v: float) -> void: _store_resolution())
	_connect("ResHeightSpin", &"value_changed", func(_v: float) -> void: _store_resolution())
	_load_from_store()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_translate_authored_text()


func _translate_authored_text() -> void:
	for node_name: String in UI_TEXT:
		var control := find_child(node_name, true, false) as Control
		if control is Label:
			(control as Label).text = tr(str(UI_TEXT[node_name]))
	for option_name: String in OPTION_ITEM_MSGIDS:
		var option := find_child(option_name, true, false) as OptionButton
		if option == null:
			continue
		var msgids: Array = OPTION_ITEM_MSGIDS[option_name]
		for i: int in mini(option.item_count, msgids.size()):
			option.set_item_text(i, tr(str(msgids[i])))
	for check_name: String in CHECKS:
		var check := find_child(check_name, true, false) as BaseButton
		if check != null:
			check.text = tr("on")
	var close_tip := find_child("MenuCloseButton", true, false) as Button
	if close_tip != null:
		close_tip.tooltip_text = tr("Close")


func open() -> void:
	_cancel_hold()
	_translate_authored_text()
	if drive_settings:
		_load_from_store()
	show()
	var first := _ctl("LanguageOption")
	if first != null and first.is_visible_in_tree():
		first.grab_focus()


func close() -> void:
	_cancel_hold()
	if _listening != &"":
		_listening = &""
		_refresh_key_labels()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if drive_settings and visible and _listening == &"" and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _input(event: InputEvent) -> void:
	if drive_settings and _hold_active:
		if event is InputEventMouseMotion and (event as InputEventMouseMotion).position.distance_to(_hold_from) > HoldTiming.CANCEL_DIST:
			_cancel_hold()
		elif event is InputEventScreenDrag and (event as InputEventScreenDrag).position.distance_to(_hold_from) > HoldTiming.CANCEL_DIST:
			_cancel_hold()
		elif event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				if _hold_elapsed >= HoldTiming.SECONDS:
					get_viewport().set_input_as_handled()
					_finish_hold()
				else:
					_cancel_hold()
	if _listening == &"" or not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	_replace_action_key(_listening, key)
	_listening = &""
	_refresh_key_labels()
	_store({"key_bindings": _serialize_key_bindings()})


## Same timing, cancellation and ring/sound feedback as vn_balloon.gd.
## On title only; in-game the balloon handles the same scene's gui_input.
func _on_empty_press(event: InputEvent) -> void:
	if not drive_settings or not visible or _listening != &"":
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not _hits_interactive(self, get_global_transform() * mb.position):
			_hold_local = mb.position
			_hold_from = get_global_transform_with_canvas() * mb.position
			_hold_elapsed = 0.0
			_hold_active = true


func _hits_interactive(parent: Control, point: Vector2) -> bool:
	for child: Node in parent.get_children():
		if not child is Control or not (child as Control).visible or child == hold_indicator:
			continue
		var ctl := child as Control
		if ctl.mouse_filter != MOUSE_FILTER_IGNORE and (ctl is BaseButton or ctl is Range or ctl is LineEdit 				or ctl is TextEdit or ctl is ItemList or ctl is Tree) and Rect2(Vector2.ZERO, ctl.size).has_point(ctl.get_global_transform().affine_inverse() * point):
			return true
		if _hits_interactive(ctl, point):
			return true
	return false


func _process(delta: float) -> void:
	if not drive_settings or not visible or not _hold_active:
		return
	_hold_elapsed += delta
	if _hold_elapsed >= HoldTiming.APPEAR:
		if not hold_indicator.visible:
			var point := get_global_transform() * _hold_local
			hold_indicator.show_at(hold_indicator.get_global_transform().affine_inverse() * point)
			if _hold_sound_enabled():
				get_node("/root/AudioDirector").hold_start()
		hold_indicator.progress = clampf(_hold_elapsed / HoldTiming.SECONDS, 0.0, 1.0)
		if _hold_sound_enabled():
			get_node("/root/AudioDirector").hold_progress(hold_indicator.progress)
		if _hold_elapsed >= HoldTiming.SECONDS:
			_finish_hold()


func _hold_sound_enabled() -> bool:
	var store := _settings_store()
	return get_node_or_null("/root/AudioDirector") != null and (store == null or bool(store.get_value("sfx_buttons", true)))


func _cancel_hold() -> void:
	_hold_active = false
	hold_indicator.hide_ring()
	var audio := get_node_or_null("/root/AudioDirector")
	if audio != null:
		audio.hold_stop()


func _finish_hold() -> void:
	if not _hold_active:
		return
	_cancel_hold()
	close()



# --- load ---------------------------------------------------------------------

func _load_from_store() -> void:
	var store = _settings_store()
	if store == null:
		return
	var data: Dictionary = store.load_settings()
	_loading = true
	for n: String in SLIDERS:
		var key: String = SLIDERS[n][0]
		if data.has(key):
			_set_range(n, float(data[key]), false)
		_update_value_label(n)
	_set_range("UIScaleValue", _range_value("UIScaleSlider"), false)
	for n: String in CHECKS:
		var check := _ctl(n) as BaseButton
		if check != null and data.has(CHECKS[n]):
			check.set_pressed_no_signal(bool(data[CHECKS[n]]))
	for n: String in OPTIONS:
		var option := _ctl(n) as OptionButton
		var key: String = OPTIONS[n][0]
		if option == null:
			continue
		if data.has(key):
			var index := _option_index(OPTIONS[n][1], data[key])
			if index >= 0 and index < option.item_count:
				option.select(index)
		elif key == "language":
			option.select(1 if TranslationServer.get_locale().begins_with("ru") else 0)
	var skip := _ctl("SkipSpeedSlider") as Range
	if skip != null:
		if data.has("skip_delay"):
			skip.set_value_no_signal(clampf(skip.min_value + skip.max_value - float(data.skip_delay), skip.min_value, skip.max_value))
		elif data.has("skip_speed"):
			skip.set_value_no_signal(float(data.skip_speed))
		_set_range("SkipSpeedValue", skip.min_value + skip.max_value - skip.value, false)
	if data.has("res_w") and data.has("res_h"):
		_set_range("ResWidthSpin", float(data.res_w), false)
		_set_range("ResHeightSpin", float(data.res_h), false)
		_select_resolution_item(int(data.res_w), int(data.res_h))
	_sync_rotation(int(data.get("rotation", 0)))
	_apply_saved_key_bindings(data.get("key_bindings", {}))
	_refresh_key_labels()
	_loading = false


# --- handlers -----------------------------------------------------------------

func _on_slider_changed(value: float, slider_name: String) -> void:
	_update_value_label(slider_name)
	if slider_name == "UIScaleSlider":
		_set_range("UIScaleValue", value, false)
	_store({SLIDERS[slider_name][0]: value})


func _on_check_toggled(on: bool, check_name: String) -> void:
	_store({CHECKS[check_name]: on})


func _on_option_selected(index: int, option_name: String) -> void:
	var values: Array = OPTIONS[option_name][1]
	_store({OPTIONS[option_name][0]: values[index] if index < values.size() else index})


func _on_rotation_pressed(button_name: String) -> void:
	_sync_rotation(ROTATIONS[button_name])
	_store({"rotation": ROTATIONS[button_name]})


## The slider reads as speed (right = faster); the number field and the timer use
## the delay in seconds - the same convention as vn_balloon.gd.
func _on_skip_slider_changed(value: float) -> void:
	var skip := _ctl("SkipSpeedSlider") as Range
	var delay := skip.min_value + skip.max_value - value
	_set_range("SkipSpeedValue", delay, false)
	_store({"skip_speed": value, "skip_delay": delay})


func _on_skip_spin_changed(delay: float) -> void:
	var skip := _ctl("SkipSpeedSlider") as Range
	skip.value = clampf(skip.min_value + skip.max_value - delay, skip.min_value, skip.max_value)


func _on_resolution_selected(index: int) -> void:
	var parts := (_ctl("ResolutionOption") as OptionButton).get_item_text(index).split("x")
	if parts.size() != 2:
		return
	_set_range("ResWidthSpin", float(parts[0].strip_edges()), false)
	_set_range("ResHeightSpin", float(parts[1].strip_edges()), false)
	_store_resolution()


func _store_resolution() -> void:
	var w := int(_range_value("ResWidthSpin"))
	var h := int(_range_value("ResHeightSpin"))
	_store({"res_w": w, "res_h": h})
	if not _loading and DisplayServer.get_name() != "headless" \
			and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(Vector2i(w, h))


func _on_key_button_pressed(button_name: String) -> void:
	_refresh_key_labels()
	_listening = KEY_BUTTONS[button_name]
	(_ctl(button_name) as Button).text = tr("Press any key...")


# --- helpers ------------------------------------------------------------------

func _store(values: Dictionary) -> void:
	var store = _settings_store()
	if not _loading and store != null:
		store.set_values(values)


## The SettingsStore autoload (looked up, so the scene also loads in tools/tests).
func _settings_store() -> Node:
	return get_node_or_null(^"/root/SettingsStore")


func _ctl(node_name: String) -> Control:
	return get_node_or_null("%" + node_name) as Control


func _connect(node_name: String, sig: StringName, callable: Callable) -> void:
	var node := _ctl(node_name)
	if node != null and node.has_signal(sig):
		node.connect(sig, callable)


func _range_value(node_name: String) -> float:
	var r := _ctl(node_name) as Range
	return r.value if r != null else 0.0


func _set_range(node_name: String, value: float, emit: bool) -> void:
	var r := _ctl(node_name) as Range
	if r == null:
		return
	if emit:
		r.value = value
	else:
		r.set_value_no_signal(value)


func _update_value_label(slider_name: String) -> void:
	var label_name: String = SLIDERS[slider_name][1]
	if label_name.is_empty():
		return
	var label := _ctl(label_name) as Label
	if label == null:
		return
	var fmt: String = tr(str(SLIDERS[slider_name][2]))
	var v := _range_value(slider_name)
	if fmt.contains("%d"):
		label.text = fmt % roundi(v)
	else:
		label.text = fmt % v


func _option_index(values: Array, stored: Variant) -> int:
	if values.is_empty():
		return int(stored)
	for i in values.size():
		var v: Variant = values[i]
		if typeof(v) == TYPE_INT and (typeof(stored) == TYPE_INT or typeof(stored) == TYPE_FLOAT):
			if int(stored) == v:
				return i
		elif typeof(v) == typeof(stored) and v == stored:
			return i
	return -1


func _select_resolution_item(w: int, h: int) -> void:
	var option := _ctl("ResolutionOption") as OptionButton
	if option == null:
		return
	for i in option.item_count:
		if option.get_item_text(i).replace(" ", "") == "%dx%d" % [w, h]:
			option.select(i)
			return
	option.select(option.item_count - 1)


func _sync_rotation(deg: int) -> void:
	deg = preload("res://scenes/display_rotation.gd").normalize(deg)
	for n: String in ROTATIONS:
		var b := _ctl(n) as BaseButton
		if b != null:
			b.set_pressed_no_signal(ROTATIONS[n] == deg)


# Key bindings: same JSON shape as vn_balloon.gd (_serialize_key_bindings).

func _apply_saved_key_bindings(saved: Variant) -> void:
	if not saved is Dictionary:
		return
	for action: StringName in KEY_BUTTONS.values():
		var item: Variant = (saved as Dictionary).get(String(action))
		if item is Dictionary and (int(item.get("keycode", 0)) != 0 or int(item.get("physical_keycode", 0)) != 0):
			var key := InputEventKey.new()
			key.keycode = int(item.get("keycode", 0)) as Key
			key.physical_keycode = int(item.get("physical_keycode", 0)) as Key
			key.alt_pressed = bool(item.get("alt", false))
			key.shift_pressed = bool(item.get("shift", false))
			key.ctrl_pressed = bool(item.get("ctrl", false))
			key.meta_pressed = bool(item.get("meta", false))
			_replace_action_key(action, key)


func _replace_action_key(action: StringName, source: InputEventKey) -> void:
	if not InputMap.has_action(action):
		return
	var keep: Array[InputEvent] = []
	for old: InputEvent in InputMap.action_get_events(action):
		if not old is InputEventKey:
			keep.append(old)
	InputMap.action_erase_events(action)
	var key := source.duplicate() as InputEventKey
	key.pressed = false
	key.echo = false
	key.unicode = 0
	InputMap.action_add_event(action, key)
	for old: InputEvent in keep:
		InputMap.action_add_event(action, old)


func _serialize_key_bindings() -> Dictionary:
	var result: Dictionary = {}
	for action: StringName in KEY_BUTTONS.values():
		if not InputMap.has_action(action):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				var key := event as InputEventKey
				result[String(action)] = {
					"keycode": int(key.keycode), "physical_keycode": int(key.physical_keycode),
					"alt": key.alt_pressed, "shift": key.shift_pressed,
					"ctrl": key.ctrl_pressed, "meta": key.meta_pressed,
				}
				break
	return result


func _refresh_key_labels() -> void:
	for n: String in KEY_BUTTONS:
		var b := _ctl(n) as Button
		if b == null:
			continue
		b.text = tr("Unbound")
		var action: StringName = KEY_BUTTONS[n]
		if not InputMap.has_action(action):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				var k := event as InputEventKey
				b.text = OS.get_keycode_string(k.keycode if k.keycode != 0 else k.physical_keycode)
				break
