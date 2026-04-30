# PURPOSE: EnemyData — Defines a single enemy type's stats, behavior, and loot.
# Like HeroData, this is READ-ONLY. The live battle instance is managed by BattleManager.

class_name EnemyData
extends Resource

# ── IDENTITY ──────────────────────────────────────────────────────────────────

@export var id: String = ""
@export var display_name: String = ""
@export var enemy_type: String = "void" # void, undead, beast, humanoid
@export_multiline var description: String = ""

## Is this a boss enemy? Bosses get special UI treatment and bigger rewards.
@export var is_boss: bool = false

## Placeholder color (replace with real sprite later)
@export var placeholder_color: Color = Color(0.8, 0.2, 0.2)

# ── STATS ─────────────────────────────────────────────────────────────────────

@export var base_hp: int = 50
@export var base_atk: int = 10
@export var base_magic_atk: int = 0
@export var base_def: int = 5
@export var base_magic_def: int = 5
@export_range(1, 10) var base_speed: int = 5
@export var base_heal_power: float = 0.0

# ── BEHAVIOR ──────────────────────────────────────────────────────────────────

## How this enemy chooses its target
@export_enum("random", "lowest_hp", "highest_hp", "front_row", "back_row") var targeting_strategy: String = "random"

## The skills this enemy uses (referenced by skill ID)
@export var skill_ids: Array[String] = []

## Chance this enemy uses a skill instead of a basic attack (0.0 to 1.0)
@export_range(0.0, 1.0) var skill_use_chance: float = 0.3

# ── LOOT ──────────────────────────────────────────────────────────────────────

## Gold dropped when this enemy dies
@export var gold_drop_min: int = 5
@export var gold_drop_max: int = 15

## Possible item/skill drops — array of item IDs with weights
## Format: [{"id": "slash", "weight": 10}, {"id": "fireball", "weight": 5}]
@export var loot_table: Array[Dictionary] = []

## Guaranteed drop for boss enemies
@export var boss_guaranteed_drop_id: String = ""

# ── SPRITE ────────────────────────────────────────────────────────────────────

@export_file("*.png") var sprite_path: String = ""
