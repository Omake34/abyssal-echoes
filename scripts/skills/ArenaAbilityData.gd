class_name ArenaAbilityData
extends Resource
## Arena-only ability definition. Runtime cooldowns and counters belong to units.

@export var id := ""
@export var display_name := ""
@export var family_id := ""
@export_enum("physical", "magic", "healing") var skill_type := "physical"
@export_range(1, 3) var tier := 1
@export_file("*.png") var icon_path := ""
@export_enum("battle_start", "proximity", "before_attack", "after_attack", "heal_action") var activation := "after_attack"
@export_enum("heal_max_hp", "taunt_shield", "damage_multiplier", "pierce", "burn", "heal") var effect_id := "burn"
@export_enum("attacks", "casts") var counter := "attacks"
@export_range(1, 100) var trigger_count := 1
## Multiplier, flat HP/shield/damage, or maximum-HP fraction, depending on effect.
@export var power := 1.0
@export var cooldown_seconds := 0.0
@export var range_cells := 4.0
@export var duration_seconds := 0.0
@export var interval_seconds := 1.0
@export var secondary_range_cells := 5.5
@export var line_half_width := 1.0
@export var missing_hp_to_cast := 12
@export var requires_magic_attack := false

var type_color: Color:
	get: return SkillVisualStyle.color_for(skill_type)

func family_key() -> String:
	return family_id if not family_id.is_empty() else id

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var triggers := {"heal_max_hp": "battle_start", "taunt_shield": "proximity",
		"damage_multiplier": "before_attack", "pierce": "after_attack", "burn": "after_attack", "heal": "heal_action"}
	if id.is_empty() or display_name.is_empty():
		errors.append("Ability identity is missing.")
	if skill_type not in ["physical", "magic", "healing"] or tier < 1 or tier > 3:
		errors.append("Skill type or tier is invalid.")
	if not triggers.has(effect_id) or triggers.get(effect_id) != activation:
		errors.append("Effect and activation do not match.")
	if counter not in ["attacks", "casts"] or trigger_count < 1:
		errors.append("The trigger counter must be valid and positive.")
	if not is_finite(power) or power <= 0.0 or not is_finite(cooldown_seconds) or cooldown_seconds < 0.0:
		errors.append("Power must be positive and cooldown must be nonnegative.")
	if not is_finite(range_cells) or range_cells <= 0.0:
		errors.append("Range must be positive.")
	if effect_id in ["burn", "taunt_shield"] and (not is_finite(duration_seconds) or duration_seconds <= 0.0):
		errors.append("Status duration must be positive.")
	if effect_id == "burn" and (not is_finite(interval_seconds) or interval_seconds < 0.05 or duration_seconds < interval_seconds):
		errors.append("Burn interval must be at least one simulation step and fit inside its duration.")
	if effect_id == "pierce" and (not is_finite(secondary_range_cells) or secondary_range_cells <= 0.0 or not is_finite(line_half_width) or line_half_width < 0.0):
		errors.append("Pierce geometry is invalid.")
	if effect_id == "heal_max_hp" and power > 1.0:
		errors.append("Maximum-HP healing is a fraction between zero and one.")
	if missing_hp_to_cast < 1:
		errors.append("Healing threshold must be positive.")
	return errors

func get_icon_texture() -> Texture2D:
	return load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null

func description_for(unit: Dictionary = {}) -> String:
	match effect_id:
		"taunt_shield":
			return "Taunt enemies within %s cells for %ss and gain %s shield. Cooldown: %ss." % [_number(range_cells), _number(duration_seconds), _number(power), _number(cooldown_seconds)]
		"damage_multiplier":
			return "Every %d %s, the attack deals %s%% damage.%s" % [trigger_count, counter, _number(power * 100), " Requires a magic basic attack." if requires_magic_attack else ""]
		"pierce":
			return "An attack can hit one enemy behind its target for %s%% damage. Extra-target reach: %s cells, within %s cell of the shot's path." % [_number(power * 100), _number(secondary_range_cells), _number(line_half_width)]
		"burn":
			return "Every %d attacks, burn the target for %s damage every %ss over %ss." % [trigger_count, _number(power), _number(interval_seconds), _number(duration_seconds)]
		"heal":
			return "Heal a wounded ally within %s cells for %d HP. Cooldown: %ss. Healing power scales the base %s HP." % [_number(range_cells), roundi(power * float(unit.get("heal_multiplier", 1.0))), _number(cooldown_seconds), _number(power)]
		"heal_max_hp":
			return "At battle start, heal all allies for %s%% of their maximum HP." % _number(power * 100)
	return ""

func _number(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")

func progress_text(unit: Dictionary) -> String:
	if activation == "battle_start":
		return display_name + " · at start"
	if activation in ["proximity", "heal_action"]:
		var remaining := float(unit.get("ability_cooldowns", {}).get(id, 0.0))
		return display_name + (" · ready" if remaining <= 0.0 else " · %.1fs" % remaining)
	if trigger_count == 1:
		return display_name + " · each hit"
	return "%s · %d/%d" % [display_name, int(unit.get(counter, 0)) % trigger_count, trigger_count]
