# PURPOSE: SkillData — Defines a single skill's identity, stats, and effect.
# Skills are data-only resources. The actual LOGIC of what a skill does
# is handled by BattleManager reading the "effect_id" and "skill_type".
# HOW TO CREATE:
#   In Godot editor: right-click res://resources/skills/ → New Resource → SkillData

class_name SkillData
extends Resource

# ── IDENTITY ──────────────────────────────────────────────────────────────────

## Unique string ID (e.g. "slash", "fireball", "heal_minor")
@export var id: String = ""

## Display name shown in UI
@export var display_name: String = ""

## Tooltip description — explain clearly what the skill does and with what numbers
@export_multiline var description: String = ""

## Skill tier: 1 = Basic, 2 = Advanced, 3 = Master, 4 = EX
@export_range(1, 4) var tier: int = 1

# ── TYPE & TARGETING ──────────────────────────────────────────────────────────

## Skill type — determines color coding and some synergies
@export_enum("physical", "magic", "support", "utility") var skill_type: String = "physical"

## Who this skill targets
@export_enum("single_enemy", "all_enemies", "single_ally", "all_allies", "self") var target_type: String = "single_enemy"

# ── EFFECT DEFINITION ─────────────────────────────────────────────────────────

## The effect identifier — BattleManager looks this up to apply the right logic
## Examples: "damage_flat", "damage_atk_mult", "heal_flat", "aoe_damage", "apply_stun"
@export var effect_id: String = ""

## Primary power value — meaning depends on effect_id
## For damage: base damage amount or ATK multiplier
## For heal: base heal amount or HEAL_POWER multiplier
@export var power: float = 10.0

## Secondary value (optional) — used for DoT duration, buff %, etc.
@export var power_secondary: float = 0.0

## How many times this skill can be used per battle (0 = unlimited passive)
@export var uses_per_battle: int = 0  # 0 means it fires on cooldown

## Cooldown in ticks between uses (if uses_per_battle is 0)
@export var cooldown_ticks: int = 3

# ── MERGE RULES ───────────────────────────────────────────────────────────────

## Can this skill be merged with others? (EX skills cannot be merged further)
@export var can_merge: bool = true

## What skill does 3x of this produce? (leave empty to use generic tier-up)
## If set, merging 3 of this exact skill gives this specific skill ID
@export var merge_result_id: String = ""

## For EX skills only — which two Tier III skill IDs combine to make this
@export var ex_ingredient_a: String = ""
@export var ex_ingredient_b: String = ""

# ── VISUAL ────────────────────────────────────────────────────────────────────

## Color of the skill's type indicator badge
var type_color: Color:
	get:
		match skill_type:
			"physical": return Color(0.8, 0.1, 0.1)   # Red
			"magic":    return Color(0.1, 0.3, 0.9)   # Blue
			"support":  return Color(0.1, 0.7, 0.2)   # Green
			"utility":  return Color(0.85, 0.65, 0.0) # Gold
		return Color.WHITE

## Path to skill icon image (leave empty to use type-colored placeholder)
@export_file("*.png") var icon_path: String = ""

## VFX effect key — BattleScene uses this to play the right particle effect
@export var vfx_id: String = ""
