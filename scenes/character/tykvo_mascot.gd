extends Node2D
## Тыквочка — анимированный тыквенный маскот для главного меню.
## Дыхание + случайное моргание + смена выражений.

@export var blink_interval_min: float = 2.2
@export var blink_interval_max: float = 5.5

@onready var sprite: Sprite2D = $Sprite
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var blink_timer: Timer = $BlinkTimer
@onready var blink_end_timer: Timer = $BlinkEndTimer

var _expression: String = "neutral"
var textures := {}

func _ready() -> void:
	textures = {
		"neutral": preload("res://assets/characters/tykvochka.webp"),
		"happy": preload("res://assets/characters/tykvochka_smile.webp"),
		"surprised": preload("res://assets/characters/tykvochka.webp"),
		"blink": preload("res://assets/characters/tykvochka.webp"),
		"thinking": preload("res://assets/characters/tykvochka.webp"),
		"sad": preload("res://assets/characters/mira.webp"),
	}
	anim.animation_finished.connect(_on_animation_finished)
	blink_timer.timeout.connect(_on_blink_timer_timeout)
	blink_end_timer.timeout.connect(_on_blink_end_timer_timeout)
	anim.play("idle")
	_schedule_blink()

func set_expression(expression_name: String) -> void:
	if not textures.has(expression_name):
		return
	_expression = expression_name
	sprite.texture = textures[expression_name]

func get_expression() -> String:
	return _expression

func greet() -> void:
	if anim.current_animation != "greet":
		anim.play("greet")

func _schedule_blink() -> void:
	blink_timer.wait_time = randf_range(blink_interval_min, blink_interval_max)
	blink_timer.start()

func _on_blink_timer_timeout() -> void:
	if _expression == "neutral":
		sprite.texture = textures["blink"]
		blink_end_timer.start()
	else:
		_schedule_blink()

func _on_blink_end_timer_timeout() -> void:
	if _expression == "neutral":
		sprite.texture = textures["neutral"]
		_schedule_blink()

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "greet":
		anim.play("idle")
