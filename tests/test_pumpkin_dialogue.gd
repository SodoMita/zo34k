## Regression checks for conditional response syntax in the shipped farm story.
extends Node

var fails := 0
var passes := 0
var resource: DialogueResource
var game_state: Node


func _ready() -> void:
	await _run()
	print("pumpkin-dialogue %d passed, %d failed" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		passes += 1
		print("[PASS] %s" % message)
	else:
		fails += 1
		printerr("[FAIL] %s" % message)


func _responses_at(cue: String) -> Array[DialogueResponse]:
	var line: DialogueLine = await resource.get_next_dialogue_line(cue, [game_state])
	for i in 150:
		if line == null or not line.responses.is_empty():
			break
		line = await resource.get_next_dialogue_line(str(line.next_id), [game_state])
	return line.responses if line != null else []


func _run() -> void:
	resource = load("res://dialogue/pumpkin.dialogue") as DialogueResource
	game_state = get_tree().root.get_node("GameState")
	_check(resource != null, "pumpkin dialogue imports as a resource")
	if resource == null:
		return

	var source := FileAccess.get_file_as_string("res://dialogue/pumpkin.dialogue")
	var inline_condition := RegEx.new()
	inline_condition.compile("(?m)^\\s*- .*\\s+if\\s+[^\\r\\n]+$")
	_check(inline_condition.search(source) == null, "choice labels contain no visible inline if suffixes")
	_check(source.contains("[if can_plant() /]") and source.contains("[if money >= 20 /]"),
		"choices use Dialogue Manager's hidden conditional-response syntax")

	game_state.reset()
	game_state.seeds = 0
	game_state.growth_stage = 0
	game_state.fertilizer = 2
	game_state.water_cans = 5
	game_state.weeds = false
	game_state.pests = false
	var day_responses := await _responses_at("day_loop")
	var allowed_day: Array[String] = []
	for response: DialogueResponse in day_responses:
		if response.is_allowed:
			allowed_day.append(response.text)
	_check(not allowed_day.any(func(text: String) -> bool: return text.begins_with("🌱")),
		"planting is hidden when no seeds remain")
	_check(not allowed_day.any(func(text: String) -> bool: return text.begins_with("🌿")),
		"fertilizing is hidden before planting")
	_check(allowed_day.any(func(text: String) -> bool: return text.begins_with("💧")),
		"watering remains available when water is in stock")

	game_state.growth_stage = 1
	game_state.water_cans = 0
	game_state.fertilizer = 0
	game_state.weeds = true
	game_state.pests = true
	game_state.weather = "солнечно"
	day_responses = await _responses_at("day_loop")
	allowed_day.clear()
	for response: DialogueResponse in day_responses:
		if response.is_allowed:
			allowed_day.append(response.text)
	_check(allowed_day.any(func(text: String) -> bool: return text.begins_with("🧹"))
		and allowed_day.any(func(text: String) -> bool: return text.begins_with("🐛")),
		"weed and pest actions appear only when their conditions are true")
	_check(not allowed_day.any(func(text: String) -> bool: return text.begins_with("💧"))
		and not allowed_day.any(func(text: String) -> bool: return text.begins_with("🌿")),
		"watering and fertilizer actions disappear when unavailable")

	game_state.money = 0
	var market_responses := await _responses_at("market")
	var allowed_market: Array[String] = []
	for response: DialogueResponse in market_responses:
		if response.is_allowed:
			allowed_market.append(response.text)
	_check(not allowed_market.any(func(text: String) -> bool: return text.begins_with("Купить")),
		"market purchase options are hidden when the player has no money")
	game_state.money = 20
	market_responses = await _responses_at("market")
	allowed_market.clear()
	for response: DialogueResponse in market_responses:
		if response.is_allowed:
			allowed_market.append(response.text)
	_check(allowed_market.any(func(text: String) -> bool: return text.begins_with("Купить 3 семечка")),
		"bulk seeds appear once the wallet meets their price")
