extends SceneTree

func _initialize() -> void:
	var checks := 0
	for seed_value in range(50):
		var first := RandomNumberGenerator.new()
		var second := RandomNumberGenerator.new()
		first.seed = seed_value
		second.seed = seed_value
		for kind in ["battle", "elite", "boss", "unknown"]:
			var enemies := RunEncounterAdapter.enemies_for_node({"type": kind}, first)
			var replay := RunEncounterAdapter.enemies_for_node({"type": kind}, second)
			assert(enemies == replay, "Seeded encounter must replay exactly")
			checks += 1
			if kind == "battle":
				assert(enemies.size() in [2, 3])
			elif kind == "elite":
				assert(enemies.size() == 2 and enemies[0].id == "skeleton" and enemies[1].id == "goblin")
			else:
				assert(enemies.size() == 1)
			checks += 1
			for enemy in enemies:
				assert(enemy is EnemyData)
				if kind == "boss":
					assert(enemy.is_boss)
				elif kind == "battle":
					assert(enemy.id in RunEncounterAdapter.COMMON)
				elif kind == "unknown":
					assert(enemy.id == "slime")
	print("RUN ENCOUNTER: %d checks, 0 failures" % checks)
	quit()
