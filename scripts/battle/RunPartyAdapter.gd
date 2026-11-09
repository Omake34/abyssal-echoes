class_name RunPartyAdapter
extends RefCounted
## Read-only boundary between saved party state and live battle state.
## Keeps legacy skills intact; never substitutes arena trial equipment.

static func hero_snapshot(hero_instance: Dictionary, index: int) -> Dictionary:
	var data = hero_instance["data"]
	var skills = hero_instance.get("skills", [])
	
	# Calculate Synergies
	var active_syns = SynergyManager.get_active_synergies(skills)
	var mods = SynergyManager.calculate_multipliers(active_syns)
	
	# Use meta-progression overrides if they exist, then apply synergy
	var max_hp = int(hero_instance.get("max_hp_override", data.base_hp) * mods["hp_mult"])
	var atk    = int(hero_instance.get("atk_override", data.base_atk) * mods["atk_mult"])
	var magic_atk = int(data.base_magic_atk * mods["magic_atk_mult"])
	var heal_power = data.base_heal_power * mods["heal_power_mult"]
	var speed  = int(hero_instance.get("speed_override", data.base_speed) + mods["speed_add"])
	
	return {
		"id":           data.id,
		"party_index":  index,
		"display_name": data.display_name,
		"is_hero":      true,
		"data":         data,
		"current_hp":   hero_instance.get("current_hp", max_hp),
		"max_hp":       max_hp,
		"atk":          atk,
		"magic_atk":    magic_atk,
		"heal_power":   heal_power,
		"def":          data.base_def,
		"magic_def":    data.base_magic_def,
		"speed":        speed,
		"crit_chance":  data.base_crit_chance,
		"crit_mult":    data.base_crit_multiplier,
		"evasion":      data.base_evasion,
		"skills":       skills.duplicate(),
		"active_synergies": active_syns,
		"skill_cooldowns": {},  # skill_id → ticks remaining
		"status_effects":  [],
		"position":     hero_instance.get("position", Vector2i.ZERO),
		"slot_index":   hero_instance.get("slot_index", index),
		"alive":        true,
		"tick_progress": 0,   # Accumulates each tick based on speed
	}

