# PURPOSE: SynergyManager — Calculates bonuses based on skill combinations.
# Scans a list of skills and returns a dictionary of active stat bonuses.

class_name SynergyManager
extends Node

## Defines a single synergy's requirements and bonuses
## { "name": String, "type": String, "count": int, "bonus": Dictionary }
const SYNERGIES = [
	{
		"id": "physical_3",
		"display_name": "Soldier's Might",
		"description": "3 Physical skills: +15% Attack",
		"type_req": "physical",
		"count_req": 3,
		"bonus": { "atk_mult": 0.15 }
	},
	{
		"id": "magic_3",
		"display_name": "Arcane Resonance",
		"description": "3 Magic skills: +20% Magic Attack",
		"type_req": "magic",
		"count_req": 3,
		"bonus": { "magic_atk_mult": 0.20 }
	},
	{
		"id": "support_2",
		"display_name": "Guardian's Grace",
		"description": "2 Support skills: +10% Max HP, +15% Healing",
		"type_req": "support",
		"count_req": 2,
		"bonus": { "hp_mult": 0.10, "heal_power_mult": 0.15 }
	},
	{
		"id": "utility_2",
		"display_name": "Tactical Edge",
		"description": "2 Utility skills: +1 Speed",
		"type_req": "utility",
		"count_req": 2,
		"bonus": { "speed_add": 1 }
	}
]

## Returns a list of active synergy dictionaries for a given list of SkillData resources
static func get_active_synergies(skills: Array) -> Array:
	var active = []
	
	# Count types
	var counts = {
		"physical": 0,
		"magic": 0,
		"support": 0,
		"utility": 0
	}
	
	for skill in skills:
		if skill and skill is SkillData:
			counts[skill.skill_type] = counts.get(skill.skill_type, 0) + 1
			
	# Check against definitions
	for syn in SYNERGIES:
		if counts.get(syn["type_req"], 0) >= syn["count_req"]:
			active.append(syn)
			
	return active

## Calculates total stat modifiers from a list of active synergies
static func calculate_multipliers(active_synergies: Array) -> Dictionary:
	var mods = {
		"hp_mult": 1.0,
		"atk_mult": 1.0,
		"magic_atk_mult": 1.0,
		"heal_power_mult": 1.0,
		"speed_add": 0
	}
	
	for syn in active_synergies:
		var bonus = syn["bonus"]
		if "hp_mult" in bonus: mods["hp_mult"] += bonus["hp_mult"]
		if "atk_mult" in bonus: mods["atk_mult"] += bonus["atk_mult"]
		if "magic_atk_mult" in bonus: mods["magic_atk_mult"] += bonus["magic_atk_mult"]
		if "heal_power_mult" in bonus: mods["heal_power_mult"] += bonus["heal_power_mult"]
		if "speed_add" in bonus: mods["speed_add"] += bonus["speed_add"]
		
	return mods
