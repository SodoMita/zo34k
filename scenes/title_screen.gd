extends Control
## Тыквенная Ферма — главный экран, вдохновлён TastyMilka/title_screen.
## Визуал в title_screen.tscn, логика только связывает кнопки.

const DisplayRotation = preload("res://scenes/display_rotation.gd")
const LABEL_KEYS := {
	"Title": "ТЫКВЕННАЯ ФЕРМА",
	"Subtitle": "осенняя история о росте и тепле",
	"Version": "v1.0 · уютный симулятор · 30 дней до фестиваля",
	"HowToPlayTitle": "Как играть",
	"HowToPlay": "Поливай · Удобряй · Общайся\nСобери тыкву-чемпиона к Хэллоуину! \nH · История   F5/F9 · Save   Esc · Пауза   F12 · Паника",
}

@onready var start_button: Button = %StartButton
@onready var continue_button: Button = %ContinueButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var mascot: Node2D = %TykvoMascot
@onready var ambient: AnimationPlayer = $Ambient
@onready var settings_panel: SettingsMenu = $SettingsPanel
@onready var title_block: VBoxContainer = $TitleBlock
var _leaving := false
var _layout_queued := false

func _ready() -> void:
	ambient.play("ambient")
	_apply_settings()
	_translate_labels()
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	var reactions := {start_button: "happy", continue_button: "surprised", settings_button: "thinking", quit_button: "sad"}
	for button: Button in reactions:
		button.mouse_entered.connect(_react.bind(str(reactions[button])))
		button.focus_entered.connect(_react.bind(str(reactions[button])))
		button.mouse_exited.connect(_reset_expression)
		button.focus_exited.connect(_reset_expression)
	settings_panel.closed.connect(_reset_expression)
	get_viewport().size_changed.connect(_queue_display_layout)
	var store := get_node_or_null("/root/SettingsStore")
	if store != null:
		store.settings_changed.connect(_on_shared_setting_changed)
	_apply_display_layout()
	_play_sfx("open")
	_update_continue_visibility()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_translate_labels()
		_queue_display_layout()

func _apply_settings() -> void:
	var store := get_node_or_null("/root/SettingsStore")
	if store != null and store.has_method("apply_globals"):
		store.apply_globals()

func _on_shared_setting_changed(key: String, _value: Variant) -> void:
	if key in ["rotation", "ui_scale", "force_portrait", "res_w", "res_h"]:
		_queue_display_layout()

func _queue_display_layout() -> void:
	if _layout_queued or not is_node_ready():
		return
	_layout_queued = true
	call_deferred("_apply_display_layout")

func _apply_display_layout() -> void:
	_layout_queued = false
	if not is_node_ready():
		return
	var store := get_node_or_null("/root/SettingsStore")
	var data: Dictionary = store.data if store != null else {}
	var angle := DisplayRotation.normalize(int(data.get("rotation", 0)))
	var window_size := get_viewport().get_visible_rect().size
	DisplayRotation.apply_control(self, window_size, angle)
	var factor := clampf(float(data.get("ui_scale", 1.0)), 0.5, 2.5)
	DisplayRotation.apply_control(settings_panel, size, 0, factor)
	var portrait := bool(data.get("force_portrait", false)) or settings_panel.size.y > settings_panel.size.x or settings_panel.size.x < 740.0
	for child: Node in settings_panel.get_node("%SettingsVBox").get_children():
		if child is BoxContainer:
			(child as BoxContainer).vertical = portrait
			if child.get_child_count() > 0 and child.get_child(0) is Label:
				(child.get_child(0) as Label).custom_minimum_size.x = 0.0 if portrait else 170.0
	var margin := settings_panel.get_node("%SettingsMargin") as MarginContainer
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, roundi(32.0 / factor))
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, roundi(40.0 / factor))
	settings_panel._sync_rotation(angle)
	var tall := size.y > size.x
	title_block.position.x = maxf(24.0, (size.x - title_block.size.x) * 0.5) if tall else maxf(24.0, size.x * 0.075)
	mascot.position = Vector2(size.x * (0.5 if tall else 0.703125), size.y * (0.77 if tall else 0.777778))

func _translate_labels() -> void:
	for node_name: String in LABEL_KEYS:
		var label := get_node_or_null("%" + node_name)
		if label is Label:
			(label as Label).text = tr(str(LABEL_KEYS[node_name]))
	var tooltip_keys := {
		"StartButton": "Начать новую историю",
		"ContinueButton": "Продолжить",
		"SettingsButton": "Настройки",
		"QuitButton": "Выйти",
	}
	for button_name: String in tooltip_keys:
		var button := find_child(button_name, true, false) as Button
		if button != null:
			button.tooltip_text = tr(str(tooltip_keys[button_name]))

func _react(expression: String) -> void:
	if not _leaving and not settings_panel.visible:
		if mascot.has_method("set_expression"):
			mascot.set_expression(expression)
		_play_sfx("click")

func _reset_expression() -> void:
	if not _leaving:
		if mascot.has_method("set_expression"):
			mascot.set_expression("thinking" if settings_panel.visible else "neutral")

func _on_start_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	_play_sfx("confirm")
	if mascot.has_method("set_expression"):
		mascot.set_expression("happy")
	if mascot.has_method("greet"):
		mascot.greet()
	await get_tree().create_timer(0.55).timeout
	get_tree().change_scene_to_file("res://scenes/vn_scene.tscn")

func _on_continue_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	_play_sfx("open")
	var game_state := get_node_or_null("/root/GameState")
	var slot := _latest_save_slot()
	if game_state != null and slot >= 0:
		game_state.pending_resume_slot = slot
		game_state.has_pending_resume = true
	get_tree().change_scene_to_file("res://scenes/vn_scene.tscn")

func _on_settings_pressed() -> void:
	if _leaving:
		return
	_play_sfx("open")
	settings_panel.open()
	if mascot.has_method("set_expression"):
		mascot.set_expression("thinking")

func _on_quit_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	_play_sfx("close")
	if mascot.has_method("set_expression"):
		mascot.set_expression("sad")
	await get_tree().create_timer(0.35).timeout
	get_tree().quit()

func _play_sfx(sfx_name: String) -> void:
	var ad := get_node_or_null("/root/AudioDirector")
	if ad != null and ad.has_method("play_sfx"):
		ad.play_sfx(sfx_name)

func _latest_save_slot() -> int:
	var dir := DirAccess.open("user://saves")
	if dir == null:
		return -1
	var best := -1
	var best_when := ""
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("slot_") and file_name.ends_with(".json"):
			var slot := int(file_name.trim_prefix("slot_").trim_suffix(".json"))
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://saves/%s" % file_name))
			var when := ""
			if parsed is Dictionary and parsed.get("meta", {}) is Dictionary:
				when = str(parsed.meta.get("when", ""))
			if when > best_when:
				best_when = when
				best = slot
		file_name = dir.get_next()
	dir.list_dir_end()
	return best

func _update_continue_visibility() -> void:
	# Disable continue if no saves
	var slot := _latest_save_slot()
	continue_button.disabled = slot < 0
	if slot < 0:
		continue_button.tooltip_text = "Нет сохранений"
