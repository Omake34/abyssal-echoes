class_name ArenaSimulation
extends RefCounted
## Isolated arena rules. No RunState, global signals, rewards, or save writes.
## Positions are board cells; all timers use seconds at a fixed simulation step.

const STEP := 0.05
const BOARD_SIZE := Vector2i(16, 7)
const PREP_COLUMNS := 6
const TIME_LIMIT := 120.0
const DEFAULT_FORMATION := [Vector2i(5, 3), Vector2i(2, 2), Vector2i(2, 4), Vector2i(1, 3)]
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT]

var units: Array[Dictionary] = []
var events: Array[Dictionary] = []
var elapsed := 0.0
var running := false
var result := ""
var encounter := 0

func setup(starting_formation: Array = [], encounter_index: int = 0, use_ember: bool = false, loadouts: Array = []) -> void:
	units.clear()
	events.clear()
	elapsed = 0.0
	running = false
	result = ""
	encounter = encounter_index
	var roles := ["warrior", "archer", "mage", "cleric"]
	for i in range(roles.size()):
		var data := load("res://resources/heroes/%s.tres" % roles[i]) as HeroData
		var cell: Vector2i = starting_formation[i] if i < starting_formation.size() else DEFAULT_FORMATION[i]
		# Invalid/overlapping imported placement cannot strand a unit off board.
		if not is_preparation_cell(cell) or not unit_at(cell).is_empty():
			cell = _free_preparation_cell()
		var unit := _unit(data.display_name, roles[i], true, cell, data.base_hp, data.base_atk,
			data.base_def, data.base_magic_atk, data.base_magic_def, data.base_speed)
		unit["heal_multiplier"] = data.base_heal_power
		if i < loadouts.size():
			ArenaEquipment.replace_loadout(unit, loadouts[i])
		elif i == 1 and use_ember:
			ArenaEquipment.replace_loadout(unit, ["ember_volley"])
		units.append(unit)
	# Authored trial encounters, not recovered reference-game stats.
	if encounter == 0:
		units.append(_unit("Iron Raider", "raider", false, Vector2i(11, 3), 300, 19, 5, 0, 3, 5))
		units.append(_unit("Ash Hound", "hound", false, Vector2i(10, 1), 160, 14, 2, 0, 2, 7))
		units.append(_unit("Ash Hound", "hound", false, Vector2i(10, 5), 160, 14, 2, 0, 2, 7))
		units.append(_unit("Hex Weaver", "hexer", false, Vector2i(13, 3), 190, 0, 2, 18, 5, 5))
	else:
		units.append(_unit("Iron Raider", "raider", false, Vector2i(10, 3), 330, 20, 6, 0, 3, 5))
		units.append(_unit("Hex Weaver", "hexer", false, Vector2i(12, 1), 200, 0, 2, 18, 5, 5))
		units.append(_unit("Hex Weaver", "hexer", false, Vector2i(12, 5), 200, 0, 2, 18, 5, 5))
	for i in range(units.size()):
		units[i]["uid"] = i

func _unit(title: String, role: String, hero: bool, cell: Vector2i, hp: int, attack: int,
		defense: int, magic: int, magic_defense: int, speed: int) -> Dictionary:
	var profile := ArenaEquipment.profile_for(role)
	var unit := {"uid": units.size(), "name": title, "role": role, "hero": hero, "cell": cell,
		"hp": hp, "max_hp": hp, "atk": attack, "def": defense, "magic": magic,
		"magic_def": magic_defense, "range": profile.basic_attack_range, "alive": true,
		"basic_magic": profile.magic_basic_attack, "abilities": [], "ability_cooldowns": {},
		"attack_interval": 5.0 / maxf(1.0, speed), "attack_timer": 0.3,
		"move_interval": profile.move_interval_seconds, "move_timer": 0.0,
		"taunted_by": -1, "taunt_left": 0.0,
		"shield": 0, "burn_left": 0.0, "burn_timer": 0.0, "burn_source": -1,
		"burn_power": 0, "burn_interval": 1.0,
		"attacks": 0, "casts": 0, "hits_taken": 0, "damage": 0, "healing": 0,
		"prevented": 0, "target": -1, "heal_multiplier": 1.0}
	for ability in profile.abilities:
		ArenaEquipment.equip(unit, ability)
	return unit

func start() -> void:
	if running or not result.is_empty():
		return
	running = true
	for unit in units:
		if unit["alive"]:
			for ability in unit["abilities"]:
				if ability.activation == "battle_start":
					_execute_ability(unit, ability, {})

func step() -> void:
	if not running:
		return
	elapsed += STEP
	# World timers advance independently of action speed or whether a target exists.
	for unit in units:
		if not unit["alive"]:
			continue
		for timer in ["attack_timer", "move_timer", "taunt_left"]:
			unit[timer] = maxf(0.0, float(unit[timer]) - STEP)
		for id in unit["ability_cooldowns"]:
			unit["ability_cooldowns"][id] = maxf(0.0, float(unit["ability_cooldowns"][id]) - STEP)
		_tick_burn(unit)
	for unit in units:
		if not unit["alive"]:
			continue
		for ability in unit["abilities"]:
			if ability.activation == "proximity" and _ready_ability(unit, ability):
				_execute_ability(unit, ability, {})
		var target := _choose_target(unit)
		unit["target"] = int(target.get("uid", -1))
		if target.is_empty():
			continue
		var reach := float(unit["range"])
		var healing := _ready_healing(unit)
		if unit["hero"] == target["hero"] and healing != null:
			reach = healing.range_cells
		if distance(unit, target) > reach:
			if unit["move_timer"] <= 0.0:
				_move_toward(unit, target, reach)
			continue
		if unit["attack_timer"] <= 0.0:
			_act(unit, target)
			unit["attack_timer"] = unit["attack_interval"]
	if living(false).is_empty():
		_finish("Victory")
	elif living(true).is_empty():
		_finish("Defeat")
	elif elapsed >= TIME_LIMIT:
		_finish("Stalemate")

func _finish(outcome: String) -> void:
	running = false
	result = outcome
	events.append({"kind": "result", "text": outcome})

func living(hero: bool) -> Array[Dictionary]:
	return units.filter(func(u: Dictionary) -> bool: return u["hero"] == hero and u["alive"])

func distance(a: Dictionary, b: Dictionary) -> float:
	return Vector2(a["cell"]).distance_to(Vector2(b["cell"]))

func _choose_target(unit: Dictionary) -> Dictionary:
	var healing := _ready_healing(unit)
	if healing != null:
		var wounded := living(bool(unit["hero"])).filter(func(u: Dictionary) -> bool:
			return u["hp"] <= u["max_hp"] - healing.missing_hp_to_cast)
		wounded.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["hp"]) / a["max_hp"] < float(b["hp"]) / b["max_hp"])
		if not wounded.is_empty():
			return wounded[0]
	if unit["taunt_left"] > 0.0:
		var forced := get_unit(int(unit["taunted_by"]))
		if not forced.is_empty() and forced["alive"]:
			return forced
	var opponents := living(not bool(unit["hero"]))
	opponents.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := distance(unit, a)
		var db := distance(unit, b)
		return a["uid"] < b["uid"] if is_equal_approx(da, db) else da < db)
	return {} if opponents.is_empty() else opponents[0]

func _move_toward(unit: Dictionary, target: Dictionary, reach: float = -1.0) -> void:
	# Breadth-first search to any unoccupied cell within attack/heal range.
	# Occupancy comes from the same cells used for targeting and rendering.
	var origin: Vector2i = unit["cell"]
	if reach < 0.0:
		reach = float(unit["range"])
	var frontier: Array[Vector2i] = [origin]
	var previous := {origin: origin}
	var cursor := 0
	while cursor < frontier.size():
		var cell := frontier[cursor]
		cursor += 1
		if cell != origin and Vector2(cell).distance_to(Vector2(target["cell"])) <= reach:
			while previous[cell] != origin:
				cell = previous[cell]
			unit["cell"] = cell
			unit["move_timer"] = unit["move_interval"]
			return
		for direction in DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if inside_board(neighbor) and not previous.has(neighbor) and unit_at(neighbor).is_empty():
				previous[neighbor] = cell
				frontier.append(neighbor)
	unit["move_timer"] = unit["move_interval"]

func _act(unit: Dictionary, target: Dictionary) -> void:
	if unit["hero"] == target["hero"]:
		var healing := _ready_healing(unit)
		if healing != null:
			_execute_ability(unit, healing, target)
			unit["casts"] += 1
		return
	unit["attacks"] += 1
	var magic: bool = unit["basic_magic"]
	var power := int(unit["magic"] if magic else unit["atk"])
	var title := "Bolt" if magic else "Strike"
	if magic:
		unit["casts"] += 1
	for ability in unit["abilities"]:
		if ability.activation == "before_attack" and _counter_triggered(unit, ability):
			power = roundi(power * ability.power)
			title = ability.display_name
			unit["ability_cooldowns"][ability.id] = ability.cooldown_seconds
	deal_damage(unit, target, power, magic, title)
	for ability in unit["abilities"]:
		if ability.activation == "after_attack" and _counter_triggered(unit, ability):
			_execute_ability(unit, ability, target, power)

func _ready_ability(unit: Dictionary, ability: ArenaAbilityData) -> bool:
	return float(unit["ability_cooldowns"].get(ability.id, 0.0)) <= 0.0

func _counter_triggered(unit: Dictionary, ability: ArenaAbilityData) -> bool:
	var count := int(unit.get(ability.counter, 0))
	return count > 0 and count % ability.trigger_count == 0 and _ready_ability(unit, ability)

func _ready_healing(unit: Dictionary) -> ArenaAbilityData:
	for ability in unit["abilities"]:
		if ability.activation == "heal_action" and _ready_ability(unit, ability):
			return ability
	return null

func _execute_ability(unit: Dictionary, ability: ArenaAbilityData, target: Dictionary, attack_power: int = 0) -> void:
	match ability.effect_id:
		"heal_max_hp":
			for ally in living(bool(unit["hero"])):
				heal(unit, ally, maxi(1, roundi(ally["max_hp"] * ability.power)), ability.display_name)
		"taunt_shield":
			var affected := false
			for enemy in living(not bool(unit["hero"])):
				if distance(unit, enemy) <= ability.range_cells:
					enemy["taunted_by"] = unit["uid"]
					enemy["taunt_left"] = ability.duration_seconds
					affected = true
			if not affected:
				return
			unit["shield"] += roundi(ability.power)
			_event("taunt", unit, unit, roundi(ability.power), ability.display_name)
		"heal":
			heal(unit, target, roundi(ability.power * float(unit["heal_multiplier"])), ability.display_name)
		"burn":
			if not target.get("alive", false):
				return
			target["burn_left"] = ability.duration_seconds
			target["burn_source"] = unit["uid"]
			target["burn_timer"] = ability.interval_seconds
			target["burn_interval"] = ability.interval_seconds
			target["burn_power"] = roundi(ability.power)
			_event("burn", unit, target, 0, ability.display_name)
		"pierce":
			var shot := Vector2(target["cell"]) - Vector2(unit["cell"])
			for extra in living(not bool(unit["hero"])):
				var offset := Vector2(extra["cell"]) - Vector2(target["cell"])
				if extra["uid"] != target["uid"] and offset.dot(shot) > 0.0 \
						and absf(offset.cross(shot.normalized())) <= ability.line_half_width and distance(unit, extra) <= ability.secondary_range_cells:
					deal_damage(unit, extra, roundi(attack_power * ability.power), unit["basic_magic"], ability.display_name)
					break
	unit["ability_cooldowns"][ability.id] = ability.cooldown_seconds

func deal_damage(source: Dictionary, target: Dictionary, power: int, magic: bool, title: String) -> void:
	if not source.get("alive", false) or not target.get("alive", false):
		return
	var amount := maxi(1, power - int(target["magic_def"] if magic else target["def"]))
	var absorbed := mini(int(target["shield"]), amount)
	target["shield"] -= absorbed
	target["prevented"] += absorbed
	amount = mini(amount - absorbed, int(target["hp"]))
	target["hp"] -= amount
	source["damage"] += amount
	target["hits_taken"] += 1
	_event("damage", source, target, amount, title)
	if target["hp"] <= 0:
		target["alive"] = false
		target["target"] = -1
		_event("death", source, target, 0, "Fallen")

func heal(source: Dictionary, target: Dictionary, power: int, title: String) -> void:
	if not source.get("alive", false) or not target.get("alive", false):
		return
	var amount := clampi(power, 0, int(target["max_hp"]) - int(target["hp"]))
	if amount == 0:
		return
	target["hp"] += amount
	source["healing"] += amount
	_event("heal", source, target, amount, title)

func _tick_burn(unit: Dictionary) -> void:
	if unit["burn_left"] <= 0.0:
		return
	var active_seconds := minf(STEP, float(unit["burn_left"]))
	unit["burn_left"] = maxf(0.0, float(unit["burn_left"]) - active_seconds)
	unit["burn_timer"] -= active_seconds
	if unit["burn_timer"] <= 0.0001:
		unit["burn_timer"] += unit["burn_interval"]
		var source := get_unit(int(unit["burn_source"]))
		# Existing burns expire normally even if their caster falls.
		if not source.is_empty():
			var amount := mini(int(unit["burn_power"]), int(unit["hp"]))
			unit["hp"] -= amount
			source["damage"] += amount
			_event("damage", source, unit, amount, "Burn")
			if unit["hp"] <= 0:
				unit["alive"] = false
				unit["target"] = -1
				_event("death", source, unit, 0, "Fallen")

func _event(kind: String, source: Dictionary, target: Dictionary, amount: int, title: String) -> void:
	events.append({"kind": kind, "source": source["uid"], "target": target["uid"],
		"from": Vector2(source["cell"]), "to": Vector2(target["cell"]), "amount": amount,
		"text": title, "time": elapsed})

func take_events() -> Array[Dictionary]:
	var batch := events.duplicate()
	events.clear()
	return batch

func get_unit(uid: int) -> Dictionary:
	return units[uid] if uid >= 0 and uid < units.size() else {}

func unit_at(cell: Vector2i) -> Dictionary:
	for unit in units:
		if unit["alive"] and unit["cell"] == cell:
			return unit
	return {}

func inside_board(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < BOARD_SIZE.x and cell.y < BOARD_SIZE.y

func is_preparation_cell(cell: Vector2i) -> bool:
	return inside_board(cell) and cell.x < PREP_COLUMNS

func place_hero(uid: int, cell: Vector2i) -> bool:
	if running or not result.is_empty() or not is_preparation_cell(cell):
		return false
	var unit := get_unit(uid)
	if unit.is_empty() or not unit["hero"]:
		return false
	var occupant := unit_at(cell)
	if not occupant.is_empty():
		if not occupant["hero"]:
			return false
		occupant["cell"] = unit["cell"]
	unit["cell"] = cell
	return true

func formation() -> Array:
	return units.filter(func(u: Dictionary) -> bool: return u["hero"]).map(func(u: Dictionary) -> Vector2i: return u["cell"])

func hero_loadouts() -> Array:
	return units.filter(func(u: Dictionary) -> bool: return u["hero"]).map(func(u: Dictionary) -> Array: return ArenaEquipment.loadout_ids(u))

func equip_ability(uid: int, id: String) -> Dictionary:
	var unit := get_unit(uid)
	if running or not result.is_empty() or unit.is_empty() or not unit["hero"]:
		return {"ok": false, "reason": "Abilities can only be changed during preparation."}
	return ArenaEquipment.equip(unit, ArenaEquipment.find_ability(id))

func remove_ability(uid: int, id: String) -> bool:
	var unit := get_unit(uid)
	if running or not result.is_empty() or unit.is_empty() or not unit["hero"]:
		return false
	return ArenaEquipment.remove(unit, id)

func _free_preparation_cell() -> Vector2i:
	for x in range(PREP_COLUMNS - 1, -1, -1):
		for y in range(BOARD_SIZE.y):
			var cell := Vector2i(x, y)
			if unit_at(cell).is_empty():
				return cell
	return Vector2i.ZERO
