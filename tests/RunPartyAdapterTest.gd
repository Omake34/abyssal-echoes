extends Node
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)

func _ready() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AbyssalEchoesRewardTest-"):
		get_tree().quit(1)
		return
	# Avoid routing the synthetic result to a real reward scene.
	EventBus.battle_ended.disconnect(SceneManager._on_battle_ended)
	for role in ["warrior", "archer", "mage", "cleric", "assassin", "captain"]:
		var data = load("res://resources/heroes/%s.tres" % role)
		var old_save := {"data": data, "current_hp": 37, "skills": []}
		var live := RunPartyAdapter.hero_snapshot(old_save, 2)
		check(live.current_hp == 37, "Wounded HP must survive conversion")
		check(live.max_hp == data.base_hp, "Legacy saves use base max HP")
		check(live.slot_index == 2 and live.position == Vector2i.ZERO, "Legacy placement defaults")
		check(live.party_index == 2 and live.data == data, "Party identity retained")
		old_save.max_hp_override = 999
		old_save.atk_override = 88
		old_save.speed_override = 9
		live = RunPartyAdapter.hero_snapshot(old_save, 2)
		check(live.max_hp == 999 and live.atk == 88 and live.speed == 9, "Meta bonuses retained")
		live.skills.append(null)
		live.status_effects.append({"type": "burn"})
		live.current_hp = 1
		check(old_save.skills.is_empty() and old_save.current_hp == 37, "Runtime state must not mutate saves")
	# Every owned skill, including tier IV, retains resource identity and synergy stats.
	var directory := DirAccess.open("res://resources/skills")
	for file in directory.get_files():
		if not file.ends_with(".tres"):
			continue
		var skill = load("res://resources/skills/" + file)
		if not skill is SkillData:
			continue
		var hero := {"data": load("res://resources/heroes/warrior.tres"), "skills": [skill], "current_hp": 42}
		var live := RunPartyAdapter.hero_snapshot(hero, 0)
		check(live.skills.size() == 1 and live.skills[0] == skill, "Owned skill preserved: " + file)
		var mods := SynergyManager.calculate_multipliers(SynergyManager.get_active_synergies([skill]))
		check(live.atk == int(hero.data.base_atk * mods.atk_mult), "Synergy preserved: " + file)
	RunState.start_new_run()
	RunState.add_hero_to_party(load("res://resources/heroes/warrior.tres"))
	var manager := BattleManager.new()
	add_child(manager)
	manager.init_battle(RunState.party, [])
	manager.heroes[0].current_hp = 31
	manager._end_battle("win")
	check(RunState.party[0].current_hp == 31, "Victory carries HP back")
	var wins: int = RunState.run_stats.battles_won
	manager._end_battle("win")
	check(RunState.run_stats.battles_won == wins, "Duplicate completion cannot award a second win")
	manager.begin_combat()
	check(not manager._running, "Finished battle cannot restart")
	manager.init_battle(RunState.party, [])
	manager.begin_combat()
	check(manager._running, "New encounter resets completion guard")
	manager._running = false
	print("RUN PARTY: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
