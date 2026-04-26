# PURPOSE: GameData — Loads and stores ALL static game data (heroes, skills, enemies).
# This data never changes during gameplay — it is read-only reference data.
# Think of it as the "database" of the game.
# HOW TO USE:
#   var warrior = GameData.get_hero("warrior")
#   var all_skills = GameData.skills  # Dictionary of all SkillData resources

extends Node

# ── DATA DICTIONARIES ─────────────────────────────────────────────────────────
# These are filled automatically when the game starts by scanning resource folders.

## All hero base data. Key = hero ID string (e.g. "warrior")
var heroes: Dictionary = {}

## All skill data. Key = skill ID string (e.g. "slash")
var skills: Dictionary = {}

## All enemy data. Key = enemy ID string (e.g. "goblin")
var enemies: Dictionary = {}

## All item data. Key = item ID string
var items: Dictionary = {}

# ── RESOURCE FOLDER PATHS ─────────────────────────────────────────────────────
const HERO_PATH    = "res://resources/heroes/"
const SKILL_PATH   = "res://resources/skills/"
const ENEMY_PATH   = "res://resources/enemies/"
const ITEM_PATH    = "res://resources/items/"

# ── LIFECYCLE ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Load all data when the game starts
	_load_resources(HERO_PATH,  heroes)
	_load_resources(SKILL_PATH, skills)
	_load_resources(ENEMY_PATH, enemies)
	_load_resources(ITEM_PATH,  items)
	print("[GameData] Loaded: %d heroes, %d skills, %d enemies, %d items" % [
		heroes.size(), skills.size(), enemies.size(), items.size()
	])

# ── INTERNAL LOADER ───────────────────────────────────────────────────────────

## Scans a folder for .tres resource files and loads them into a dictionary.
## The resource's "id" property becomes the dictionary key.
func _load_resources(folder_path: String, target_dict: Dictionary) -> void:
	var dir = DirAccess.open(folder_path)
	if dir == null:
		push_warning("[GameData] Folder not found: " + folder_path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		# Only load .tres files (skip .import files and folders)
		if file_name.ends_with(".tres"):
			var full_path = folder_path + file_name
			var resource = load(full_path)
			if resource == null:
				push_error("[GameData] Failed to load resource: " + full_path)
			elif not "id" in resource:
				push_error("[GameData] Resource has no 'id' property: " + full_path)
			else:
				target_dict[resource.id] = resource
		file_name = dir.get_next()

	dir.list_dir_end()

# ── PUBLIC API ────────────────────────────────────────────────────────────────

## Returns a HeroData resource by ID. Returns null if not found.
func get_hero(hero_id: String) -> Resource:
	if not heroes.has(hero_id):
		push_error("[GameData] Hero not found: " + hero_id)
		return null
	return heroes[hero_id]

## Returns a SkillData resource by ID. Returns null if not found.
func get_skill(skill_id: String) -> Resource:
	if not skills.has(skill_id):
		push_error("[GameData] Skill not found: " + skill_id)
		return null
	return skills[skill_id]

## Returns an EnemyData resource by ID. Returns null if not found.
func get_enemy(enemy_id: String) -> Resource:
	if not enemies.has(enemy_id):
		push_error("[GameData] Enemy not found: " + enemy_id)
		return null
	return enemies[enemy_id]

## Returns all skills of a given tier (1, 2, or 3)
func get_skills_by_tier(tier: int) -> Array:
	var result = []
	for skill in skills.values():
		if skill.tier == tier:
			result.append(skill)
	return result

## Returns all skills of a given type ("physical", "magic", "support", "utility")
func get_skills_by_type(skill_type: String) -> Array:
	var result = []
	for skill in skills.values():
		if skill.skill_type == skill_type:
			result.append(skill)
	return result
