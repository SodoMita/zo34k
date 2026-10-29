extends Node2D
## Тыквенная Ферма — точка входа. Диалог pumpkin.dialogue запускает симуляцию.
## Титульный экран передаёт сюда via GameState.pending_resume_slot.

@export var dialogue_resource: DialogueResource = preload("res://dialogue/pumpkin.dialogue")
@export var start_from_cue: String = "start"


func _ready() -> void:
	var gs = Engine.get_singleton("GameState")
	# Title screen Continue sets pending_resume_slot
	if gs != null and gs.has_pending_resume and gs.pending_resume_slot >= 0:
		var slot = gs.pending_resume_slot
		gs.has_pending_resume = false
		gs.pending_resume_slot = -1
		# Let balloon load the save after it appears
		Engine.get_singleton("DialogueManager").show_dialogue_balloon(dialogue_resource, start_from_cue)
		await get_tree().process_frame
		await get_tree().process_frame
		var balloon = get_tree().get_first_node_in_group("dialogue_balloon")
		if balloon == null:
			for c in get_tree().root.get_children():
				if c.has_method("load_game"):
					balloon = c
					break
		if balloon != null and balloon.has_method("load_game"):
			balloon.load_game(slot)
		return
	Engine.get_singleton("DialogueManager").show_dialogue_balloon(dialogue_resource, start_from_cue)
