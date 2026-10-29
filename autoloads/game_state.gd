## Тыквенная Ферма — состояние игры.
## Все эти поля доступны в диалогах через `using GameState`.
extends Node

# --- Игрок и ферма ---
@export var player_name: String = "Садовод"
@export var farm_name: String = "Тыквенный Уголок"

# --- Время ---
@export var day: int = 1  ## День октября (1-31, фестиваль 31-го)
@export var weather: String = "солнечно"  ## солнечно / облачно / дождь
@export var season_mood: String = "золотая осень"

# --- Ресурсы ---
@export var money: int = 25  ## Монеты
@export var seeds: int = 3   ## Семена тыквы
@export var water_cans: int = 5 ## запас воды
@export var fertilizer: int = 2 ## мешки удобрения

# --- Поле (центральная грядка) ---
# Стадии: 0=пусто, 1=семечко, 2=росток, 3=плеть, 4=цветок, 5=завязь, 6=зелёная тыква, 7=спелая, 8=гигант
@export var growth_stage: int = 0
@export var growth_points: int = 0 ## прогресс внутри стадии (0-100)
@export var water_level: int = 50  ## 0-100 влажность почвы
@export var health: int = 80       ## здоровье растения 0-100
@export var weeds: bool = false
@export var pests: bool = false

# --- Урожай ---
@export var pumpkins_harvested: int = 0
@export var total_weight: float = 0.0
@export var best_weight: float = 0.0
@export var pumpkin_weight: float = 0.0 ## текущая тыква на грядке
@export var quality: String = "обычная" ## обычная / хорошая / отличная / легендарная

# --- Репутация и отношения ---
@export var reputation: int = 0 ## уважение в деревне 0-100
@export var met_mira: bool = false
@export var met_scarecrow: bool = false
@export var met_tykvochka: bool = false
@export var friendship_mira: int = 0
@export var friendship_scarecrow: int = 0
@export var friendship_tykvochka: int = 0
@export var festival_invited: bool = false

# --- События и флаги ---
@export var crows_attacked: int = 0
@export var rainy_days: int = 0
@export var perfect_days: int = 0
@export var secret_found: bool = false
@export var ending: String = "" ## "" / "champion" / "cozy" / "market" / "missed"

@export var story_seed: int = 777
var input_values: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	_reseed()
	call_deferred("_reseed")

func reset() -> void:
	player_name = "Садовод"
	farm_name = "Тыквенный Уголок"
	day = 1
	weather = "солнечно"
	season_mood = "золотая осень"
	money = 25
	seeds = 3
	water_cans = 5
	fertilizer = 2
	growth_stage = 0
	growth_points = 0
	water_level = 50
	health = 80
	weeds = false
	pests = false
	pumpkins_harvested = 0
	total_weight = 0.0
	best_weight = 0.0
	pumpkin_weight = 0.0
	quality = "обычная"
	reputation = 0
	met_mira = false
	met_scarecrow = false
	met_tykvochka = false
	friendship_mira = 0
	friendship_scarecrow = 0
	friendship_tykvochka = 0
	festival_invited = false
	crows_attacked = 0
	rainy_days = 0
	perfect_days = 0
	secret_found = false
	ending = ""
	input_values = {}
	_reseed()

func _reseed() -> void:
	rng.seed = story_seed
	seed(story_seed)
	var manager := get_tree().root.get_node_or_null("DialogueManager")
	if manager != null and manager.has_method("reseed_randomizer"):
		manager.reseed_randomizer(story_seed)

func snapshot() -> Dictionary:
	var data: Dictionary = {}
	for property: Dictionary in get_script().get_script_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = get(property.name)
			if value is Object:
				continue
			data[property.name] = value
	data["rng_state"] = str(rng.state)
	var manager := get_tree().root.get_node_or_null("DialogueManager")
	if manager != null:
		var stream = manager.get("_rng")
		if stream != null:
			data["dm_rng_state"] = str(stream.state)
	return data

func restore(data: Dictionary) -> void:
	for key: String in data:
		if key == "rng_state":
			rng.state = int(data[key])
			continue
		if key == "dm_rng_state":
			var manager := get_tree().root.get_node_or_null("DialogueManager")
			if manager != null:
				var stream = manager.get("_rng")
				if stream != null:
					stream.state = int(data[key])
			continue
		set(key, data[key])

func input_value(key: String) -> Variant:
	return input_values.get(key, "")

# --- Хелперы для диалога ---

func stage_name() -> String:
	var names := ["пустая грядка", "семечко в земле", "нежный росток", "зелёная плеть", "яркий цветок", "маленькая завязь", "зелёная тыква", "спелая тыква 🎃", "ГИГАНТСКАЯ ТЫКВА!"]
	if growth_stage < 0 or growth_stage >= names.size():
		return "неизвестно"
	return names[growth_stage]

func weather_icon() -> String:
	match weather:
		"дождь": return "🌧️"
		"облачно": return "☁️"
		_: return "☀️"

func can_plant() -> bool:
	return seeds > 0 and growth_stage == 0

func can_water() -> bool:
	return water_cans > 0 or weather == "дождь"

func can_harvest() -> bool:
	return growth_stage >= 6

func weight_string() -> String:
	return "%.1f кг" % pumpkin_weight

func farm_status_short() -> String:
	return "День %d | %s %s | %s | %s" % [day, weather_icon(), weather, stage_name(), weight_string()]

# --- Логика роста (вызывается из диалога через do) ---

func do_plant() -> void:
	if not can_plant():
		return
	seeds -= 1
	growth_stage = 1
	growth_points = 0
	water_level = 60
	health = 85
	weeds = false
	pests = false
	pumpkin_weight = 0.3
	quality = "обычная"

func do_water() -> void:
	if water_cans > 0:
		water_cans -= 1
	water_level = mini(100, water_level + 35)
	health = mini(100, health + 5)
	if growth_stage > 0:
		growth_points += 8
		if water_level > 90:
			growth_points += 4
	_check_growth()

func do_fertilize() -> void:
	if fertilizer <= 0:
		return
	fertilizer -= 1
	health = mini(100, health + 15)
	growth_points += 18
	if growth_stage == 0:
		return
	_check_growth()
	if rng.randf() < 0.15:
		pests = false

func do_weed() -> void:
	weeds = false
	health = mini(100, health + 10)
	growth_points += 6
	_check_growth()

func do_talk_care() -> void:
	health = mini(100, health + 8)
	growth_points += 5
	friendship_tykvochka += 1
	_check_growth()

func do_next_day() -> void:
	day += 1
	# погода
	var r := rng.randf()
	if r < 0.25:
		weather = "дождь"
		rainy_days += 1
		water_level = mini(100, water_level + 25)
	elif r < 0.55:
		weather = "облачно"
	else:
		weather = "солнечно"
		water_level = maxi(0, water_level - 12)

	# естественный рост
	if growth_stage > 0:
		var base_gain := 10
		if water_level >= 30 and water_level <= 85:
			base_gain += 8
		elif water_level < 20:
			base_gain -= 6
			health = maxi(0, health - 8)
		if weeds:
			base_gain -= 5
			health = maxi(0, health - 5)
		if pests:
			base_gain -= 7
			health = maxi(0, health - 7)
		if health > 70:
			base_gain += 5
		growth_points += base_gain
		# вес тыквы растёт с прогрессом
		if growth_stage >= 5:
			var add := rng.randf_range(0.4, 1.2) * (1.0 + health/100.0)
			if quality == "отличная":
				add *= 1.3
			elif quality == "легендарная":
				add *= 1.7
			pumpkin_weight += add
		_check_growth()
		# случайные сорняки/вредители
		if rng.randf() < 0.18:
			weeds = true
		if rng.randf() < 0.12:
			pests = true
	else:
		# пустая грядка сохнет медленнее
		water_level = maxi(0, water_level - 5)

	# качество зависит от здоровья
	if health >= 85 and water_level >= 40:
		if growth_stage >= 3 and rng.randf() < 0.25:
			if quality == "обычная":
				quality = "хорошая"
			elif quality == "хорошая" and perfect_days >= 3:
				quality = "отличная"
			elif quality == "отличная" and perfect_days >= 6 and health >= 90:
				quality = "легендарная"

	if health >= 50 and water_level >= 30 and water_level <= 80 and not weeds and not pests:
		perfect_days += 1
	else:
		# не сбрасываем, просто не растёт
		pass

	# фестиваль
	if day == 28:
		festival_invited = true
	if day >= 31:
		_decide_ending()

func _check_growth() -> void:
	while growth_points >= 100 and growth_stage < 8:
		growth_points -= 100
		growth_stage += 1
		if growth_stage == 6:
			pumpkin_weight = max(pumpkin_weight, 3.5)
		elif growth_stage == 7:
			pumpkin_weight = max(pumpkin_weight, 8.0)
		elif growth_stage == 8:
			pumpkin_weight = max(pumpkin_weight, 25.0)

func do_harvest() -> void:
	if not can_harvest():
		return
	pumpkins_harvested += 1
	total_weight += pumpkin_weight
	if pumpkin_weight > best_weight:
		best_weight = pumpkin_weight
	var price := int(pumpkin_weight * 3.0)
	if quality == "хорошая":
		price = int(price * 1.5)
	elif quality == "отличная":
		price = int(price * 2.0)
	elif quality == "легендарная":
		price = int(price * 3.0)
	money += price
	reputation += 5 + int(pumpkin_weight / 5.0)
	# очистка грядки
	growth_stage = 0
	growth_points = 0
	pumpkin_weight = 0.0
	quality = "обычная"
	water_level = 50
	health = 80
	weeds = false
	pests = false

func do_buy_seeds(count: int = 1) -> void:
	var price := 8 * count
	if money >= price:
		money -= price
		seeds += count

func do_buy_fertilizer(count: int = 1) -> void:
	var price := 10 * count
	if money >= price:
		money -= price
		fertilizer += count

func do_buy_water(count: int = 2) -> void:
	var price := 5 * count
	if money >= price:
		money -= price
		water_cans += count

func scare_crows() -> void:
	crows_attacked += 1
	if rng.randf() < 0.6:
		health = maxi(0, health - 12)
		growth_points = maxi(0, growth_points - 10)

func befriend_mira() -> void:
	friendship_mira += 2
	reputation += 2
	met_mira = true

func befriend_scarecrow() -> void:
	friendship_scarecrow += 2
	met_scarecrow = true

func befriend_tykvochka() -> void:
	friendship_tykvochka += 2
	met_tykvochka = true

func _decide_ending() -> void:
	if best_weight >= 30.0 and reputation >= 20:
		ending = "champion"
	elif best_weight >= 12.0:
		ending = "market"
	elif pumpkins_harvested >= 2:
		ending = "cozy"
	else:
		ending = "missed"
