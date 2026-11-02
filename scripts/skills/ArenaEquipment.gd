class_name ArenaEquipment
extends RefCounted
## One validated equipment route for the trial shelf, removals, and loadout restore.
## The trial offers a reusable catalog, not items owned by a saved run.

const MAX_SLOTS := 3
const ABILITY_IDS := ["challenge", "power_strike", "pierce", "ember_volley", "arcane_surge", "mend", "holy_aura"]

static func find_ability(id: String) -> ArenaAbilityData:
	if id not in catalog_ids():
		return null
	return load("res://resources/arena/abilities/%s.tres" % id) as ArenaAbilityData

static func variant_id(family: String, tier: int) -> String:
	return family if tier == 1 else "%s_tier%d" % [family, tier]

static func catalog_ids() -> Array[String]:
	var ids: Array[String] = []
	for tier in range(1, 4):
		for family in ABILITY_IDS:
			ids.append(variant_id(family, tier))
	return ids

static func profile_for(role: String) -> ArenaUnitProfile:
	var path := "res://resources/arena/units/%s.tres" % role
	return load(path) as ArenaUnitProfile if ResourceLoader.exists(path) else ArenaUnitProfile.new()

static func can_equip(unit: Dictionary, ability: ArenaAbilityData) -> Dictionary:
	if ability == null or not ability.validation_errors().is_empty():
		return {"ok": false, "reason": "This ability definition is invalid."}
	if ability.requires_magic_attack and not unit.get("basic_magic", false):
		return {"ok": false, "reason": "Requires a magic basic attack."}
	for equipped in unit.get("abilities", []):
		if equipped.id == ability.id:
			return {"ok": false, "reason": "Already equipped."}
		if equipped.family_key() == ability.family_key():
			return {"ok": false, "reason": "Another tier of this skill is equipped. Unequip it first."}
	if unit.get("abilities", []).size() >= MAX_SLOTS:
		return {"ok": false, "reason": "All three slots are full. Remove an ability first."}
	return {"ok": true, "reason": ""}

static func equip(unit: Dictionary, ability: ArenaAbilityData) -> Dictionary:
	var check := can_equip(unit, ability)
	if check["ok"]:
		unit["abilities"].append(ability)
		unit["ability_cooldowns"][ability.id] = 0.0
	return check

static func remove(unit: Dictionary, id: String) -> bool:
	for ability in unit.get("abilities", []):
		if ability.id == id:
			unit["abilities"].erase(ability)
			unit["ability_cooldowns"].erase(id)
			return true
	return false

static func replace_loadout(unit: Dictionary, ids: Array) -> Dictionary:
	# Validate the whole replacement before changing anything on the live unit.
	var candidate := {"abilities": [], "ability_cooldowns": {}, "basic_magic": unit["basic_magic"]}
	for id in ids:
		var check := equip(candidate, find_ability(str(id)))
		if not check["ok"]:
			return check
	unit["abilities"] = candidate["abilities"]
	unit["ability_cooldowns"] = candidate["ability_cooldowns"]
	return {"ok": true, "reason": ""}

static func has_ability(unit: Dictionary, id: String) -> bool:
	return unit.get("abilities", []).any(func(ability): return ability.id == id)

static func loadout_ids(unit: Dictionary) -> Array:
	return unit.get("abilities", []).map(func(ability): return ability.id)
