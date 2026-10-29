extends Node2D
## Тыквенная Ферма — точка входа. Диалог pumpkin.dialogue запускает симуляцию.
## Можно поменять dialogue_resource в инспекторе для тестов.

@export var dialogue_resource: DialogueResource = preload("res://dialogue/pumpkin.dialogue")
@export var start_from_cue: String = "start"


func _ready() -> void:
	Engine.get_singleton("DialogueManager").show_dialogue_balloon(dialogue_resource, start_from_cue)
