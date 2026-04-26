# PURPOSE: HeroData — Defines the BASE stats and identity of a hero class.
# This is READ-ONLY reference data. It never changes during gameplay.
# The "live" version of a hero (current HP, equipped skills, position) lives in RunState.
# HOW TO CREATE:
#   In Godot editor: right-click res://resources/heroes/ → New Resource → HeroData
#   Fill in the @export fields in the Inspector panel.

class_name HeroData
extends Resource

# ── IDENTITY ──────────────────────────────────────────────────────────────────

## Unique string ID used to reference this hero (e.g. "warrior", "archer")
@export var id: String = ""

## Display name shown in UI
@export var display_name: String = ""

## Short description shown in hero selection
@export var description: String = ""

## Hero class type — used for formation bonuses and advanced class merging
@export_enum("warrior", "archer", "mage", "assassin", "cleric", "captain") var hero_class: String = "warrior"

## Color used for placeholder art (remove when real sprites are added)
@export var placeholder_color: Color = Color.WHITE

# ── BASE STATS ────────────────────────────────────────────────────────────────
# These are the stats at the START of a run. They scale with upgrades.

## Maximum hit points
@export var base_hp: int = 100

## Physical attack power
@export var base_atk: int = 10

## Magic attack power
@export var base_magic_atk: int = 5

## Physical defense (damage reduction)
@export var base_def: int = 5

## Magic defense
@export var base_magic_def: int = 3

## How fast this hero acts (higher = acts more often per battle tick)
## Range: 1 (slow) to 10 (very fast)
@export_range(1, 10) var base_speed: int = 5

## Critical hit chance (0.0 = never, 1.0 = always)
@export_range(0.0, 1.0) var base_crit_chance: float = 0.05

## Critical hit damage multiplier (1.5 = 50% bonus damage on crit)
@export var base_crit_multiplier: float = 1.5

## Evasion chance — chance to dodge a hit entirely
@export_range(0.0, 1.0) var base_evasion: float = 0.0

## Healing power — multiplied with heal skills (if this hero is a healer)
@export var base_heal_power: float = 1.0

# ── SKILL SLOTS ───────────────────────────────────────────────────────────────

## Number of skill slots this hero has. Base classes get 3. Advanced classes get 4.
@export_range(1, 4) var skill_slots: int = 3

## Default skills this hero starts with (array of SkillData resource paths)
## Leave empty for no starting skills
@export var starting_skills: Array[Resource] = []

# ── UNIQUE TRAIT ──────────────────────────────────────────────────────────────

## Name of this hero's unique passive trait
@export var trait_name: String = ""

## Description of the trait (shown in tooltip)
@export var trait_description: String = ""

## The trait effect key — used by BattleManager to apply the trait
## Examples: "taunt", "pierce", "overload", "shadow_step", "aura", "formation_bonus"
@export var trait_effect_id: String = ""

# ── FORMATION PREFERENCES ─────────────────────────────────────────────────────

## Preferred formation row: 0 = front, 1 = back
## Used to suggest placement in the formation screen
@export_enum("front", "back") var preferred_row: String = "front"

# ── UNLOCK & META ─────────────────────────────────────────────────────────────

## Whether this hero is unlocked by default (true) or must be unlocked via meta-progression
@export var unlocked_by_default: bool = false

## How to unlock this hero (shown in the unlock screen)
@export var unlock_condition: String = ""

# ── SPRITE (placeholder until real art is added) ──────────────────────────────

## Path to hero sprite sheet (leave empty to use placeholder ColorRect)
@export_file("*.png") var sprite_path: String = ""
