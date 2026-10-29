extends Control
## Pumpkin Farm title screen. Scene owns presentation; this script wires actions and responsive layout.

const DisplayRotation = preload("res://scenes/display_rotation.gd")
const LABELS := {
	"Title": "ТЫКВЕННАЯ\nФЕРМА",
	"Subtitle": "осенняя история о росте и тепле",
	"Version": "v1.0 · уютный симулятор · 30 дней до фестиваля",
	"HowToPlayTitle": "Как играть",
	"HowToPlay": "Поливай · удобряй · общайся\nВыращивай тыкву-чемпиона к Хэллоуину!",
}
const BUTTON_LABELS := {
	"StartButton": "Начать игру",
	"ContinueButton": "Продолжить",
	"SettingsButton": "Настройки",
	"QuitButton": "Выйти",
}
const BUTTON_HINTS := {
	"StartButton": "Начать новую историю",
	"ContinueButton": "Продолжить последнюю игру",
	"SettingsButton": "Настройки игры",
	"QuitButton": "Выйти из игры",
}
const NO_SAVE_HINT := "Нет сохранений"

@onready var start_button: Button = %StartButton
@onready var continue_button: Button = %ContinueButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var menu_buttons: Array[Button] = [start_button, continue_button, settings_button, quit_button]
@onready var mascot: Node2D = %TykvoMascot
@onready var hero_card: Control = $HeroCard
@onready var ambient: AnimationPlayer = $Ambient
@onready var settings_panel: SettingsMenu = $SettingsPanel
@onready var title_block: VBoxContainer = $TitleBlock
@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
@onready var how_to_label: Label = %HowToPlay
@onready var how_to_title: Label = %HowToPlayTitle
@onready var version_label: Label = %Version
@onready var settings_store: Node = get_node_or_null("/root/SettingsStore")

var _leaving := false
var _layout_queued := false
var _continue_slot := -1


func _ready() -> void:
	ambient.play("ambient")
	_apply_settings()
	_translate_labels()
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	var reactions := {
		start_button: "happy",
		continue_button: "surprised",
		settings_button: "thinking",
		quit_button: "neutral",
	}
	for button: Button in reactions:
		button.mouse_entered.connect(_react.bind(str(reactions[button])))
		button.focus_entered.connect(_react.bind(str(reactions[button])))
		button.mouse_exited.connect(_reset_expression)
		button.focus_exited.connect(_reset_expression)
	settings_panel.closed.connect(_reset_expression)
	get_viewport().size_changed.connect(_queue_display_layout)
	if settings_store != null and settings_store.has_signal("settings_changed"):
		settings_store.settings_changed.connect(_on_shared_setting_changed)
	_apply_display_layout()
	_play_sfx("open")
	_update_continue_visibility()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_translate_labels()
		_update_continue_visibility()
		_queue_display_layout()


func _apply_settings() -> void:
	if settings_store != null and settings_store.has_method("apply_globals"):
		settings_store.apply_globals()


func _on_shared_setting_changed(key: String, _value: Variant) -> void:
	if key in ["rotation", "ui_scale", "force_portrait", "res_w", "res_h"]:
		_queue_display_layout()


func _queue_display_layout() -> void:
	if _layout_queued or not is_node_ready():
		return
	_layout_queued = true
	_apply_display_layout.call_deferred()


func _apply_display_layout() -> void:
	_layout_queued = false
	if not is_node_ready():
		return
	var data: Dictionary = settings_store.data if settings_store != null else {}
	var angle := DisplayRotation.normalize(int(data.get("rotation", 0)))
	var factor := clampf(float(data.get("ui_scale", 1.0)), 0.5, 2.5)
	DisplayRotation.apply_control(self, get_viewport().get_visible_rect().size, angle)
	DisplayRotation.apply_control(settings_panel, size, 0, factor)
	settings_panel.sync_rotation(angle)

	var portrait := bool(data.get("force_portrait", false)) or size.y > size.x
	var short_edge := minf(size.x, size.y)
	var title_width := minf(560.0, size.x - 48.0)
	var title_top := 64.0 if portrait else 74.0
	title_block.position = Vector2(maxf(24.0, (size.x - title_width) * 0.5) if portrait else maxf(56.0, size.x * 0.055), title_top)
	title_block.size = Vector2(title_width, maxf(500.0, size.y - title_top - 42.0))
	title_label.add_theme_font_size_override("font_size", 42 if portrait else 54)
	subtitle_label.add_theme_font_size_override("font_size", 17 if portrait else 21)
	for button: Button in menu_buttons:
		button.custom_minimum_size = Vector2(maxf(250.0, title_width - 24.0), 52.0 if portrait else 54.0)

	var settings_vbox := settings_panel.get_node_or_null("%SettingsVBox") as BoxContainer
	if settings_vbox != null:
		for child: Node in settings_vbox.get_children():
			if child is BoxContainer:
				(child as BoxContainer).vertical = portrait
				if child.get_child_count() > 0 and child.get_child(0) is Label:
					(child.get_child(0) as Label).custom_minimum_size.x = 0.0 if portrait else 170.0
	var margin := settings_panel.get_node_or_null("%SettingsMargin") as MarginContainer
	if margin != null:
		for side: String in ["left", "right"]:
			margin.add_theme_constant_override("margin_" + side, roundi(32.0 / factor))
		for side: String in ["top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, roundi(40.0 / factor))

	var card_size := minf(short_edge * (0.48 if portrait else 0.56), 390.0)
	var card_center := Vector2(size.x * 0.5, size.y * 0.82) if portrait else Vector2(size.x * 0.745, size.y * 0.50)
	hero_card.position = card_center - Vector2.ONE * card_size * 0.5
	hero_card.size = Vector2.ONE * card_size
	mascot.position = card_center
	version_label.position = Vector2(56.0, size.y - 36.0)
	mascot.scale = Vector2.ONE * (card_size / 690.0)


func _translate_labels() -> void:
	for node_name: String in LABELS:
		var node := get_node_or_null("%" + node_name) as Label
		if node != null:
			node.text = tr(LABELS[node_name])
	for button: Button in menu_buttons:
		button.text = tr(BUTTON_LABELS[button.name])
		button.tooltip_text = tr(BUTTON_HINTS[button.name])


func _react(expression: String) -> void:
	if _leaving or settings_panel.visible:
		return
	if mascot.has_method("set_expression"):
		mascot.set_expression(expression)
	_play_sfx("click")


func _reset_expression() -> void:
	if _leaving:
		return
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
	_continue_slot = _latest_save_slot()
	if _continue_slot < 0:
		_update_continue_visibility()
		return
	_leaving = true
	_play_sfx("open")
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.pending_resume_slot = _continue_slot
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
		mascot.set_expression("neutral")
	await get_tree().create_timer(0.35).timeout
	get_tree().quit()


func _play_sfx(sfx_name: String) -> void:
	var director := get_node_or_null("/root/AudioDirector")
	if director != null and director.has_method("play_sfx"):
		director.play_sfx(sfx_name)


func _latest_save_slot() -> int:
	var directory := DirAccess.open("user://saves")
	if directory == null:
		return -1
	var slot_pattern := RegEx.new()
	slot_pattern.compile("^slot_([0-9]+)\\.json$")
	var best_slot := -1
	var best_timestamp := -1
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		var match_result := slot_pattern.search(file_name)
		if match_result != null:
			var slot := int(match_result.get_string(1))
			var path := "user://saves/%s" % file_name
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				var timestamp := _save_timestamp(parsed, path)
				if timestamp > best_timestamp or (timestamp == best_timestamp and slot > best_slot):
					best_timestamp = timestamp
					best_slot = slot
		file_name = directory.get_next()
	directory.list_dir_end()
	return best_slot


func _save_timestamp(save_data: Dictionary, path: String) -> int:
	var meta: Variant = save_data.get("meta", {})
	if meta is Dictionary:
		var when := str(meta.get("when", ""))
		if not when.is_empty():
			var parsed_time := Time.get_unix_time_from_datetime_string(when)
			if parsed_time > 0:
				return int(parsed_time)
	return int(FileAccess.get_modified_time(path))


func _update_continue_visibility() -> void:
	_continue_slot = _latest_save_slot()
	continue_button.disabled = _continue_slot < 0
	continue_button.tooltip_text = tr(NO_SAVE_HINT) if _continue_slot < 0 else tr(BUTTON_HINTS["ContinueButton"])
