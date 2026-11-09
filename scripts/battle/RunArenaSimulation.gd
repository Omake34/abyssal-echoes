class_name RunArenaSimulation
extends ArenaSimulation
# PURPOSE: Execute saved-run skills on the shared arena without writing progression.

const TICK_SECONDS := 0.5
const HEAL_BASE := 20.0
const SUPPORTED_EFFECTS := ["damage_flat", "damage_atk_mult", "damage_magic_mult",
	"heal_flat", "heal_power_mult", "apply_stun", "apply_burn", "apply_bleed"]
var rng := RandomNumberGenerator.new()

func setup_run(party: Array, enemies: Array, placements: Array = []) -> void:
	units.clear()
	events.clear()
	elapsed = 0.0
	running = false
	result = ""
	rng.randomize()
	for i in range(party.size()):
		var snapshot := RunPartyAdapter.hero_snapshot(party[i], i)
		var data: HeroData = snapshot["data"]
		var cell := Vector2i(5 - clampi(int(party[i].get("slot_index", i)) % 4, 0, 3), 1 + clampi(int(party[i].get("slot_index", i)) / 4, 0, 2) * 2)
		if party[i].has("arena_cell"):
			cell = party[i]["arena_cell"]
		if i < placements.size():
			cell = placements[i]
		if not is_preparation_cell(cell) or not unit_at(cell).is_empty():
			cell = _free_preparation_cell()
		var unit := _unit(data.display_name, data.hero_class, true, cell, snapshot["max_hp"],
			snapshot["atk"], snapshot["def"], snapshot["magic_atk"], snapshot["magic_def"], snapshot["speed"])
		_initialize_run_unit(unit, data, snapshot["skills"])
		unit["hp"] = clampi(snapshot["current_hp"], 0, unit["max_hp"])
		unit["alive"] = unit["hp"] > 0
		unit["heal_multiplier"] = snapshot["heal_power"]
		unit["crit_chance"] = snapshot["crit_chance"]
		unit["crit_mult"] = snapshot["crit_mult"]
		unit["evasion"] = snapshot["evasion"]
		unit["trait"] = data.trait_effect_id
		unit["party_index"] = i
		unit["slots"] = data.skill_slots
		unit["abilities"] = []
		for ability_id in _trait_abilities(data.trait_effect_id):
			ArenaEquipment.equip(unit, ArenaEquipment.find_ability(ability_id))
		units.append(unit)
	for i in range(enemies.size()):
		var data: EnemyData = enemies[i]
		var role := "hexer" if data.base_magic_atk > data.base_atk else "raider"
		var unit := _unit(data.display_name, role, false, Vector2i(11 + i / 7, i % 7),
			data.base_hp, data.base_atk, data.base_def, data.base_magic_atk, data.base_magic_def, data.base_speed)
		var skills: Array = []
		for id in data.skill_ids:
			var skill = GameData.get_skill(id)
			if skill != null:
				skills.append(skill)
		_initialize_run_unit(unit, data, skills)
		unit["abilities"] = []
		unit["strategy"] = data.targeting_strategy
		unit["skill_chance"] = data.skill_use_chance
		unit["heal_multiplier"] = data.base_heal_power
		units.append(unit)
	for i in range(units.size()):
		units[i]["uid"] = i

func _initialize_run_unit(unit: Dictionary, data: Resource, skills: Array) -> void:
	unit["data"] = data
	unit["skills"] = skills.duplicate()
	unit["skill_timers"] = {}
	unit["skill_uses"] = {}
	unit["statuses"] = []
	unit["trait"] = ""
	unit["crit_chance"] = 0.05
	unit["crit_mult"] = 1.5
	unit["evasion"] = 0.0
	unit["skill_chance"] = 1.0
	unit["strategy"] = "nearest"

func _trait_abilities(trait_id: String) -> Array:
	match trait_id:
		"taunt": return ["challenge"]
		"holy_aura": return ["holy_aura"]
		"arcane_surge": return ["arcane_surge"]
	return []

func _skill_ready(unit: Dictionary, skill: SkillData) -> bool:
	return unit["skill_timers"].get(skill.id, 0.0) <= 0.0 and (skill.uses_per_battle == 0 or unit["skill_uses"].get(skill.id, 0) < skill.uses_per_battle)

func skill_reach(unit: Dictionary, skill: SkillData) -> float:
	return 4.0 if skill.skill_type in ["magic", "support", "utility"] else ArenaEquipment.profile_for(unit["role"]).basic_attack_range

func _healing_skill(unit: Dictionary) -> SkillData:
	for skill in unit["skills"]:
		if skill.effect_id in ["heal_flat", "heal_power_mult"] and _skill_ready(unit, skill):
			return skill
	return null

func _choose_target(unit: Dictionary) -> Dictionary:
	var healing := _healing_skill(unit)
	if healing != null:
		var wounded := living(unit["hero"]).filter(func(u): return u["hp"] < u["max_hp"])
		wounded.sort_custom(func(a, b): return float(a["hp"]) / a["max_hp"] < float(b["hp"]) / b["max_hp"])
		if not wounded.is_empty():
			unit["range"] = skill_reach(unit, healing)
			return wounded[0]
	unit["range"] = ArenaEquipment.profile_for(unit["role"]).basic_attack_range
	for skill in unit["skills"]:
		if skill.target_type in ["single_enemy", "all_enemies"] and _skill_ready(unit, skill):
			unit["range"] = maxf(unit["range"], skill_reach(unit, skill))
	if unit["taunt_left"] > 0.0:
		return super._choose_target(unit)
	var candidates := living(not unit["hero"])
	if candidates.is_empty():
		return {}
	match unit["strategy"]:
		"random":
			var current := get_unit(unit["target"])
			if not current.is_empty() and current["alive"] and current["hero"] != unit["hero"]:
				return current
			return candidates[rng.randi_range(0, candidates.size() - 1)]
		"lowest_hp": candidates.sort_custom(func(a, b): return a["hp"] < b["hp"])
		"highest_hp": candidates.sort_custom(func(a, b): return a["hp"] > b["hp"])
		"front_row": candidates.sort_custom(func(a, b): return a["cell"].x > b["cell"].x)
		"back_row": candidates.sort_custom(func(a, b): return a["cell"].x < b["cell"].x)
		_: return super._choose_target(unit)
	return candidates[0]

func _move_toward(unit: Dictionary, target: Dictionary, reach: float = -1.0) -> void:
	if not _stunned(unit):
		super._move_toward(unit, target, reach)

func _stunned(unit: Dictionary) -> bool:
	return unit["statuses"].any(func(s): return s["effect"] == "apply_stun")

func _ready_ability(unit: Dictionary, ability: ArenaAbilityData) -> bool:
	return not _stunned(unit) and super._ready_ability(unit, ability)

func _act(unit: Dictionary, target: Dictionary) -> void:
	if _stunned(unit):
		return
	for skill in unit["skills"]:
		if not _skill_ready(unit, skill):
			continue
		var targets := skill_targets(unit, skill)
		if targets.is_empty() or rng.randf() > unit["skill_chance"]:
			continue
		unit["casts"] += 1
		for victim in targets:
			apply_skill(unit, victim, skill)
		unit["skill_timers"][skill.id] = skill.cooldown_ticks * TICK_SECONDS
		unit["skill_uses"][skill.id] = int(unit["skill_uses"].get(skill.id, 0)) + 1
		return
	if target["hero"] == unit["hero"]:
		return
	var profile := ArenaEquipment.profile_for(unit["role"])
	if distance(unit, target) > profile.basic_attack_range:
		_move_toward(unit, target, profile.basic_attack_range)
		return
	super._act(unit, target)
	if unit["trait"] == "pierce":
		_execute_ability(unit, ArenaEquipment.find_ability("pierce"), target, unit["atk"])

func skill_targets(unit: Dictionary, skill: SkillData) -> Array[Dictionary]:
	var allies := skill.target_type in ["single_ally", "all_allies", "self"]
	var candidates := living(unit["hero"] if allies else not unit["hero"])
	if skill.target_type == "self":
		candidates.assign([unit])
	candidates = candidates.filter(func(u): return distance(unit, u) <= skill_reach(unit, skill))
	if skill.effect_id in ["heal_flat", "heal_power_mult"]:
		candidates = candidates.filter(func(u): return u["hp"] < u["max_hp"])
		candidates.sort_custom(func(a, b): return float(a["hp"]) / a["max_hp"] < float(b["hp"]) / b["max_hp"])
	else:
		var selected := get_unit(unit["target"])
		candidates.sort_custom(func(a, b):
			if a["uid"] == b["uid"]:
				return false
			if a["uid"] == selected.get("uid", -1):
				return true
			if b["uid"] == selected.get("uid", -1):
				return false
			return distance(unit, a) < distance(unit, b))
	if skill.target_type in ["single_enemy", "single_ally", "self"] and candidates.size() > 1:
		candidates.resize(1)
	return candidates

func apply_skill(unit: Dictionary, target: Dictionary, skill: SkillData) -> void:
	var power := skill.power
	if unit["trait"] == "arcane_surge" and skill.skill_type == "magic" and unit["casts"] % 3 == 0:
		power *= 1.5
	match skill.effect_id:
		"damage_flat": deal_damage(unit, target, roundi(power), skill.skill_type == "magic", skill.display_name)
		"damage_atk_mult":
			if skill.id == "skill_execute" and float(target["hp"]) / target["max_hp"] <= skill.power_secondary:
				power *= 2.0
			deal_damage(unit, target, roundi(unit["atk"] * power), false, skill.display_name)
			if unit["trait"] == "pierce":
				_execute_ability(unit, ArenaEquipment.find_ability("pierce"), target, roundi(unit["atk"] * power))
		"damage_magic_mult": deal_damage(unit, target, roundi(unit["magic"] * power), true, skill.display_name)
		"heal_flat": heal(unit, target, roundi(power), skill.display_name)
		"heal_power_mult": heal(unit, target, roundi(HEAL_BASE * unit["heal_multiplier"] * power), skill.display_name)
		"apply_stun", "apply_burn", "apply_bleed":
			var duration := skill.power if skill.effect_id == "apply_stun" else skill.power_secondary
			var status := {"effect": skill.effect_id, "left": duration * TICK_SECONDS, "timer": TICK_SECONDS,
				"power": skill.power, "source": unit["uid"]}
			var previous: Array = target["statuses"].filter(func(s): return s["effect"] == skill.effect_id)
			if not previous.is_empty():
				status["left"] = maxf(status["left"], previous[0]["left"])
				target["statuses"].erase(previous[0])
			target["statuses"].append(status)
			_event("burn", unit, target, 0, skill.display_name)

func _tick_burn(unit: Dictionary) -> void:
	super._tick_burn(unit)
	for id in unit["skill_timers"]:
		unit["skill_timers"][id] = maxf(0.0, unit["skill_timers"][id] - STEP)
	for status in unit["statuses"].duplicate():
		status["left"] -= STEP
		status["timer"] -= STEP
		if status["timer"] <= 0.0001 and status["effect"] != "apply_stun" and unit["alive"]:
			status["timer"] += TICK_SECONDS
			var amount := roundi(unit["max_hp"] * status["power"]) if status["effect"] == "apply_burn" else roundi(status["power"])
			amount = mini(amount, unit["hp"])
			var source := get_unit(status["source"])
			unit["hp"] -= amount
			source["damage"] += amount
			_event("damage", source, unit, amount, "Burn" if status["effect"] == "apply_burn" else "Bleed")
			if unit["hp"] <= 0:
				unit["alive"] = false
				_event("death", source, unit, 0, "Fallen")
		if status["left"] <= 0.0001:
			unit["statuses"].erase(status)

func deal_damage(source: Dictionary, target: Dictionary, power: int, magic: bool, title: String) -> void:
	if rng.randf() < target.get("evasion", 0.0):
		_event("damage", source, target, 0, "Evade")
		return
	var defense_key := "magic_def" if magic else "def"
	var base_defense: int = target[defense_key]
	if not magic:
		target[defense_key] += 2 * living(target["hero"]).filter(func(u): return u["trait"] == "defense_aura").size()
	if rng.randf() < source.get("crit_chance", 0.0):
		var multiplier: float = source["crit_mult"] * (1.2 if source["trait"] == "crit_bonus" else 1.0)
		power = roundi(maxi(1, power - target[defense_key]) * multiplier) + target[defense_key]
		title += " · Critical"
	super.deal_damage(source, target, power, magic, title)
	target[defense_key] = base_defense
