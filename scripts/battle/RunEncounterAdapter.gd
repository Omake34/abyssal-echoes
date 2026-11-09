class_name RunEncounterAdapter
extends RefCounted
## Shared encounter selection for run combat. Does not mutate saves or rewards.
## Inject a seeded RNG for reproducible tests and future arena encounters.

const COMMON := ["slime", "goblin", "skeleton"]
const BOSSES := ["boss_abyssal_behemoth", "boss_spectral_weaver", "boss_void_reaper"]

static func enemies_for_node(node: Dictionary, rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var ids: Array = []
	match node.get("type", "battle"):
		"boss":
			ids.append(BOSSES[rng.randi_range(0, BOSSES.size() - 1)])
		"elite":
			ids = ["skeleton", "goblin"]
		"battle":
			for i in range(rng.randi_range(2, 3)):
				ids.append(COMMON[rng.randi_range(0, COMMON.size() - 1)])
		_:
			ids = ["slime"]
	var enemies: Array = []
	for id in ids:
		enemies.append(load("res://resources/enemies/%s.tres" % id))
	return enemies
