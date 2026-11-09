extends Node
# PURPOSE: Verify the production arena's save, ownership, effects, and completion boundaries.
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AbyssalEchoesRewardTest-"):
		get_tree().quit(2)
		return
	RunState.start_new_run()
	RunState.current_node_id = "arena_test"
	RunState.current_map = [[{"id": "arena_test", "type": "battle"}]]
	for id in ["assassin", "captain", "mage", "cleric"]:
		RunState.add_hero_to_party(GameData.get_hero(id))
	RunState.party[0]["current_hp"] = 31
	var scene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	check(scene.simulation is RunArenaSimulation, "normal battle entry uses arena")
	check(scene.simulation.units[0]["hp"] == 31, "wounded HP retained")
	check(scene.simulation.units[0]["role"] == "assassin", "actual party retained")
	check(scene.simulation.units[1]["trait"] == "defense_aura", "captain trait retained")
	var cells: Array = scene.simulation.formation()
	check(cells.size() == 4 and cells[0] != cells[1], "old overlapping slots migrate")
	scene.simulation.place_hero(0, Vector2i(4, 6))
	scene._save_formation()
	RunState.save_run()
	RunState.load_run()
	check(RunState.party[0]["arena_cell"] == Vector2i(4, 6), "arena placement survives save and load")
	var skill: SkillData = GameData.get_skill("skill_execute")
	RunState.party[0]["skills"] = []
	RunState.inventory = [skill, skill]
	scene._select_hero(0)
	scene._rebuild_preparation()
	var map_size: Vector2 = scene.board.size
	scene._equip_inventory(0)
	check(RunState.inventory.size() == 1 and RunState.party[0]["skills"].size() == 1, "one owned copy equipped")
	scene._unequip_slot(0, 0)
	check(RunState.inventory.size() == 2 and RunState.party[0]["skills"].is_empty(), "one copy returned")
	scene._equip_inventory(0)
	while RunState.inventory.size() < RunState.MAX_INVENTORY_SLOTS:
		RunState.inventory.append(skill)
	scene._unequip_slot(0, 0)
	check(RunState.party[0]["skills"].size() == 1, "full inventory rejects unequip atomically")
	await get_tree().process_frame
	check(scene.board.size == map_size, "equipment leaves board size stable")
	var model: RunArenaSimulation = scene.simulation
	for path in DirAccess.get_files_at("res://resources/skills"):
		if not path.ends_with(".tres"):
			continue
		var resource: SkillData = load("res://resources/skills/" + path)
		check(resource.effect_id in model.SUPPORTED_EFFECTS, "supported effect " + resource.id)
		var source := model.units[2]
		var target := model.units[4]
		target["hp"] = target["max_hp"]
		target["alive"] = true
		source["casts"] = 1
		if resource.effect_id in ["heal_flat", "heal_power_mult"]:
			target = model.units[0]
			target["hp"] = 1
		model.apply_skill(source, target, resource)
		check(target["hp"] > 1 if resource.effect_id.begins_with("heal") else target["hp"] < target["max_hp"] or not target["statuses"].is_empty(), "effect executes " + resource.id)
	scene._rebuild_preparation()
	scene.begin_battle()
	var owned_before := RunState.inventory.size()
	scene._equip_inventory(0)
	scene._unequip_slot(0, 0)
	check(RunState.inventory.size() == owned_before, "equipment locked during combat")
	scene.toggle_pause()
	var elapsed: float = scene.simulation.elapsed
	scene._process(0.2)
	check(scene.simulation.elapsed == elapsed, "pause stops simulation")
	scene.toggle_pause()
	# Observe production settlement without the global scene transition removing this test.
	EventBus.battle_ended.disconnect(SceneManager._on_battle_ended)
	for unit in scene.simulation.units:
		if not unit["hero"]:
			unit["hp"] = 0
			unit["alive"] = false
	scene.simulation.step()
	scene._commit_result()
	var gold: int = RunState.gold
	var wins: int = RunState.run_stats["battles_won"]
	scene._commit_result()
	check(wins == 1 and RunState.run_stats["battles_won"] == wins and RunState.gold == gold, "settlement awards once")
	check(RunState.party[0]["current_hp"] == scene.simulation.units[0]["hp"], "result carries HP")
	EventBus.battle_ended.connect(SceneManager._on_battle_ended)
	scene.free()
	# Every class and encounter type must finish with the same board rules.
	for hero_id in ["warrior", "archer", "mage", "cleric", "assassin", "captain"]:
		var party := [{"data": GameData.get_hero(hero_id), "skills": GameData.get_hero(hero_id).starting_skills.duplicate()}]
		var sim := RunArenaSimulation.new()
		sim.setup_run(party, RunEncounterAdapter.enemies_for_node({"type": "battle"}))
		sim.rng.seed = 31
		sim.start()
		for tick in range(2500):
			if not sim.running:
				break
			sim.step()
		check(not sim.result.is_empty(), "complete encounter for " + hero_id)
	for kind in ["elite", "boss"]:
		var party: Array = []
		for id in ["warrior", "archer", "mage", "cleric"]:
			party.append({"data": GameData.get_hero(id), "skills": GameData.get_hero(id).starting_skills.duplicate()})
		var sim := RunArenaSimulation.new()
		sim.setup_run(party, RunEncounterAdapter.enemies_for_node({"type": kind}))
		sim.rng.seed = 19
		sim.start()
		for tick in range(2500):
			if not sim.running:
				break
			sim.step()
		check(not sim.result.is_empty(), kind + " encounter completes")
	var limits := RunArenaSimulation.new()
	limits.setup_run([{"data": GameData.get_hero("mage"), "skills": []}], [load("res://resources/enemies/slime.tres")])
	var caster := limits.units[0]
	var victim := limits.units[1]
	var limited := SkillData.new()
	limited.id = "limited_test"
	limited.effect_id = "damage_flat"
	limited.target_type = "single_enemy"
	limited.skill_type = "magic"
	limited.power = 1
	limited.uses_per_battle = 1
	caster["skills"] = [limited]
	check(limits.skill_targets(caster, limited).is_empty(), "out-of-range skills cannot hit")
	victim["cell"] = caster["cell"] + Vector2i.RIGHT
	limits._act(caster, victim)
	check(caster["skill_uses"].get(limited.id, 0) == 1, "limited skill consumes a use")
	caster["skill_timers"][limited.id] = 0.0
	check(not limits._skill_ready(caster, limited), "exhausted skill stays unavailable after cooldown")
	var stun := SkillData.new()
	stun.effect_id = "apply_stun"
	stun.power = 2
	limits.apply_skill(caster, victim, stun)
	var position: Vector2i = victim["cell"]
	limits._move_toward(victim, caster)
	check(victim["cell"] == position and limits._stunned(victim), "stun blocks movement")
	for tick in range(20):
		limits._tick_burn(victim)
	check(not limits._stunned(victim), "stun expires in world time")
	victim["hp"] = 0
	victim["alive"] = false
	limits.heal(caster, victim, 99, "Heal")
	check(victim["hp"] == 0, "ordinary healing cannot revive fallen units")
	print("RUN ARENA: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
