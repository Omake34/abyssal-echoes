# PURPOSE: Exercise reward persistence and scene navigation in an isolated test project.
# Run only in a copy with application/config/use_custom_user_dir enabled and a unique
# application/config/custom_user_dir_name; these tests intentionally create run saves.
class_name RewardFlowTest
extends Node

var failures: int = 0
var checks: int = 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _new_encounter(node_type: String = "battle") -> void:
	RunState.start_new_run()
	RunState.current_map = MapGenerator.new().generate_map()
	RunState.current_node_id = "node_1_0"
	RunState.current_map[1][0]["type"] = node_type
	RunState.completed_node_ids.append("node_0_0")
	for id in ["warrior", "archer", "mage", "cleric"]:
		RunState.add_hero_to_party(GameData.get_hero(id))

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _run() -> void:
	await get_tree().process_frame
	# Refuse to touch the real player's save directory if invoked in the main project.
	var isolated_user_dir = bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false))
	var test_user_dir = str(ProjectSettings.get_setting("application/config/custom_user_dir_name", ""))
	if not isolated_user_dir or not test_user_dir.begins_with("AbyssalEchoesRewardTest-"):
		printerr("Run RewardFlowTest only in an isolated project copy with a unique test user directory.")
		get_tree().quit(2)
		return
	# Keep the runner alive as a root child while the game changes its current scene.
	get_tree().current_scene = null

	_new_encounter()
	RunState.prepare_reward(RunState.current_node_id, 23)
	var original_options = RunState.pending_reward_options.duplicate()
	_check(original_options.size() == 3, "three skills are offered")
	_check(RunState.pending_reward_gold == 23, "encounter gold is retained")
	RunState.prepare_reward(RunState.current_node_id, 999)
	_check(RunState.pending_reward_options == original_options, "revisiting does not reroll")
	_check(RunState.pending_reward_gold == 23, "revisiting does not change gold")
	RunState.clear_pending_reward()
	_check(RunState.load_run(), "saved run loads")
	_check(RunState.pending_reward_node_id == "node_1_0", "pending reward survives reload")
	_check(RunState.pending_reward_options == original_options, "choices survive reload")
	_check(RunState.pending_reward_gold == 23, "gold survives reload")

	SceneManager.resume_run()
	await _settle()
	_check(get_tree().current_scene is RewardScene, "continue opens unclaimed reward")
	_check(get_tree().current_scene.skill_container.get_child_count() == 3, "reward UI displays all choices")
	_check(get_tree().current_scene._target_gold == 23, "UI shows encounter gold rather than lifetime gold")
	get_tree().current_scene._on_back_pressed()
	await _settle()
	_check(get_tree().current_scene.scene_file_path == SceneManager.BATTLE_SCENE, "check team opens battle preparation")
	_check(get_tree().current_scene.start_button.text == "RETURN TO REWARDS", "won encounter cannot be started again")
	get_tree().current_scene.start_button.pressed.emit()
	await _settle()
	_check(get_tree().current_scene is RewardScene, "return to rewards works")
	_check(RunState.pending_reward_options == original_options, "team check preserves choices")

	var offered = load(original_options[0])
	var invalid_skill = GameData.get_skills_by_tier(2)[0]
	_check(not RunState.claim_reward(invalid_skill), "unoffered skill cannot be claimed")
	_check(RunState.inventory.is_empty(), "invalid claim does not change inventory")
	for i in range(RunState.MAX_INVENTORY_SLOTS):
		RunState.inventory.append(offered)
	get_tree().current_scene._on_skill_selected(offered, get_tree().current_scene.skill_container.get_child(0))
	get_tree().current_scene._on_continue_pressed()
	_check(not get_tree().current_scene._leaving, "full inventory prevents leaving after a failed claim")
	_check(get_tree().current_scene.choose_label.text.contains("Inventory full"), "UI explains full inventory")
	_check(not RunState.pending_reward_node_id.is_empty(), "failed claim retains reward")
	_check(not RunState.completed_node_ids.has("node_1_0"), "failed claim leaves node unfinished")
	RunState.inventory.clear()
	get_tree().current_scene._on_continue_pressed()
	get_tree().current_scene._on_continue_pressed()
	_check(RunState.inventory.size() == 1, "double click grants one item")
	_check(RunState.completed_node_ids.count("node_1_0") == 1, "node completes once")
	_check(RunState.pending_reward_node_id.is_empty(), "successful claim clears reward")
	_check(not RunState.claim_reward(offered), "claimed reward cannot be claimed again")
	await get_tree().create_timer(0.4).timeout
	await _settle()
	_check(get_tree().current_scene is MapView, "claim returns to map")
	_check(RunState.load_run(), "completed checkpoint loads")
	SceneManager.resume_run()
	await _settle()
	_check(get_tree().current_scene is MapView, "continue after claim opens map instead of replaying battle")

	_new_encounter("treasure")
	RunState.prepare_reward(RunState.current_node_id)
	SceneManager.resume_run()
	await _settle()
	_check(get_tree().current_scene.reward_title.text == "TREASURE", "treasure has the correct heading")
	_check(not get_tree().current_scene.back_button.visible, "treasure does not create a fake battle")
	_check(get_tree().current_scene._target_gold == 0, "treasure does not display previously earned gold")
	get_tree().current_scene._skip_button.pressed.emit()
	_check(RunState.inventory.is_empty(), "skip does not grant a skill")
	_check(RunState.pending_reward_node_id.is_empty(), "skip clears pending reward")
	_check(RunState.completed_node_ids.has("node_1_0"), "skip completes encounter")
	await get_tree().create_timer(0.4).timeout
	await _settle()

	_new_encounter()
	RunState.prepare_reward(RunState.current_node_id, 17)
	RunState.start_new_run()
	_check(RunState.pending_reward_node_id.is_empty(), "new run clears pending node")
	_check(RunState.pending_reward_options.is_empty(), "new run clears pending choices")
	_check(RunState.pending_reward_gold == 0, "new run clears pending gold")

	_new_encounter()
	RunState.save_run()
	var file = FileAccess.open(RunState.SAVE_PATH, FileAccess.READ)
	var legacy_data = JSON.parse_string(file.get_as_text())
	file.close()
	for key in ["pending_reward_node_id", "pending_reward_options", "pending_reward_gold", "encounter_gold_start"]:
		legacy_data.erase(key)
	file = FileAccess.open(RunState.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy_data))
	file.close()
	RunState.prepare_reward(RunState.current_node_id)
	# Restore the legacy fixture after preparing the in-memory reward wrote a newer save.
	file = FileAccess.open(RunState.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy_data))
	file.close()
	_check(RunState.load_run(), "legacy save remains loadable")
	_check(RunState.pending_reward_node_id.is_empty(), "legacy save does not inherit stale pending reward")
	_check(RunState.pending_reward_options.is_empty(), "legacy save clears stale choices")

	# Exercise the real encounter entry/victory handler and its immediate checkpoint.
	_new_encounter()
	RunState.add_gold(50)
	SceneManager._on_map_node_selected("node_1_0")
	await _settle()
	_check(RunState.encounter_gold_start == 150, "battle records starting earnings")
	RunState.add_gold(19)
	SceneManager._on_battle_ended("win")
	_check(RunState.pending_reward_gold == 19, "battle reward counts this encounter's earnings only")
	RunState.clear_pending_reward()
	_check(RunState.load_run(), "victory checkpoint is written before transition delay")
	_check(RunState.pending_reward_gold == 19, "victory checkpoint retains earned gold")
	await get_tree().create_timer(2.2).timeout
	await _settle()
	_check(get_tree().current_scene is RewardScene, "battle victory transitions to rewards")
	_check(get_tree().current_scene._target_gold == 19, "battle victory UI displays correct gold")

	print("REWARD FLOW: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

