extends Node
## Behaviour checks for the isolated combat slice and its actual UI controls.

var checks := 0
var failures := 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _duel(role: String = "warrior", start: Vector2i = Vector2i(2, 3), enemy_cell: Vector2i = Vector2i(8, 3)) -> ArenaSimulation:
	var model := ArenaSimulation.new()
	model.units.append(model._unit("Hero", role, true, start, 200, 20, 0, 18, 0, 5))
	model.units.append(model._unit("Enemy", "raider", false, enemy_cell, 1000, 12, 0, 0, 0, 5))
	model.units[0]["uid"] = 0
	model.units[1]["uid"] = 1
	# Duel fixtures isolate attacks unless a test explicitly equips Challenge.
	ArenaEquipment.remove(model.units[0], "challenge")
	return model

func _steps(model: ArenaSimulation, count: int) -> void:
	for i in range(count):
		model.step()

func _run() -> void:
	var before := JSON.stringify([RunState.party, RunState.inventory, RunState.gold, RunState.meta,
		RunState.run_stats, RunState.pending_reward_node_id, RunState.current_node_id])
	var save_before := FileAccess.get_file_as_bytes(RunState.SAVE_PATH) if FileAccess.file_exists(RunState.SAVE_PATH) else PackedByteArray()
	var meta_before := FileAccess.get_file_as_bytes(RunState.META_SAVE_PATH) if FileAccess.file_exists(RunState.META_SAVE_PATH) else PackedByteArray()
	var model := ArenaSimulation.new()
	model.setup()
	_check(model.units.size() == 8, "trial has four heroes and an authored encounter")
	_check(model.place_hero(0, Vector2i(2, 2)), "occupied hero cell can be swapped")
	_check(model.units[1]["cell"] == Vector2i(5, 3), "swap moves the other hero to the original cell")
	_check(model.units[0]["cell"] == Vector2i(2, 2), "formation changes the authoritative combat cell")
	_check(not model.place_hero(0, Vector2i(9, 3)), "preparation cannot place heroes into the enemy half")
	model.setup([Vector2i(-1, 20), Vector2i(2, 2), Vector2i(2, 2), Vector2i(1, 3)])
	var occupied := {}
	for unit in model.units:
		_check(model.inside_board(unit["cell"]) and not occupied.has(unit["cell"]), "invalid formation is normalized without overlapping actors")
		occupied[unit["cell"]] = true
	model.start()
	_check(not model.place_hero(0, Vector2i(0, 0)), "placement is locked during battle")

	model = _duel()
	model.units[0]["attack_timer"] = 0.0
	model.start()
	model.step()
	_check(model.units[1]["hp"] == 1000, "melee cannot deal damage outside its range")
	_check(model.units[0]["cell"] != Vector2i(2, 3), "melee moves toward a legal attack cell")
	_steps(model, 80)
	_check(model.units[1]["hp"] < 1000, "melee damages its target after reaching range")
	_check(model.units[0]["cell"] != model.units[1]["cell"], "opponents never occupy the same cell")
	model = _duel("warrior", Vector2i(2, 3), Vector2i(5, 3))
	model.units.append(model._unit("Blocker", "warrior", true, Vector2i(3, 3), 100, 1, 0, 0, 0, 5))
	model.units[2]["uid"] = 2
	model._move_toward(model.units[0], model.units[1])
	_check(model.units[0]["cell"] == Vector2i(2, 2), "pathfinding routes around an occupied cell")
	model = _duel("archer", Vector2i(2, 3), Vector2i(6, 3))
	model.units[0]["attack_timer"] = 0.0
	model.units[1]["move_timer"] = 10.0
	model.start()
	model.step()
	_check(model.units[1]["hp"] == 980, "ranged attacker fires at four cells")
	_check(model.units[0]["cell"] == Vector2i(2, 3), "ranged attacker holds position within range")
	model.units[0]["alive"] = false
	var hp_before: int = model.units[1]["hp"]
	_steps(model, 60)
	_check(model.units[1]["hp"] == hp_before and model.result == "Defeat", "dead units cannot act and defeat stops the battle")

	_check(_first_enemy_target(false) == 0, "a forward Warrior takes the first melee engagement")
	_check(_first_enemy_target(true) == 1, "moving the Warrior behind the Mage exposes the Mage first")
	model = _duel("warrior", Vector2i(4, 3), Vector2i(6, 3))
	model.equip_ability(0, "challenge")
	model.start()
	model.step()
	_check(model.units[1]["taunted_by"] == 0 and model.units[1]["taunt_left"] > 0, "Challenge forces nearby enemies to target the Warrior")
	_check(model.units[0]["shield"] == 18, "Challenge grants its declared shield")
	model.deal_damage(model.units[1], model.units[0], 12, false, "Test")
	_check(model.units[0]["hp"] == 200 and model.units[0]["prevented"] == 12, "shield absorbs and attributes effective prevention")

	model.setup()
	model.units[0]["hp"] = 70
	model.units[3]["cell"] = Vector2i(4, 3)
	model.units[3]["attack_timer"] = 0.0
	model.start()
	_check(model.units[0]["hp"] == 78, "Holy Aura restores five percent maximum HP at battle start")
	model.step()
	_check(model.units[0]["hp"] == 108 and model.units[3]["healing"] == 38, "Cleric Mend restores meaningful HP and counts only effective healing")
	model.heal(model.units[3], model.units[0], 1000, "Test")
	_check(model.units[0]["hp"] == 160 and model.units[3]["healing"] == 90, "healing clamps at maximum HP")
	model.units[0]["alive"] = false
	model.units[0]["hp"] = 0
	model.heal(model.units[3], model.units[0], 100, "Test")
	_check(model.units[0]["hp"] == 0, "ordinary healing cannot resurrect fallen allies")
	model = _duel()
	model.units[0]["ability_cooldowns"]["mend"] = 3.0
	model.units[0]["attack_interval"] = 0.2
	model.units[1]["ability_cooldowns"]["mend"] = 3.0
	model.units[1]["attack_interval"] = 4.0
	model.start()
	_steps(model, 20)
	_check(is_equal_approx(model.units[0]["ability_cooldowns"]["mend"], 2.0) and is_equal_approx(model.units[1]["ability_cooldowns"]["mend"], 2.0), "cooldowns use world seconds independently of attack cadence")

	model = _duel("mage", Vector2i(2, 3), Vector2i(6, 3))
	model._act(model.units[0], model.units[1])
	model._act(model.units[0], model.units[1])
	model._act(model.units[0], model.units[1])
	_check(model.units[1]["hp"] == 937, "every third Mage spell deals 50 percent more damage")
	model = _duel("archer", Vector2i(2, 3), Vector2i(5, 3))
	model.units.append(model._unit("Rear enemy", "raider", false, Vector2i(7, 3), 100, 5, 0, 0, 0, 5))
	model.units[2]["uid"] = 2
	model._act(model.units[0], model.units[1])
	_check(model.units[2]["hp"] == 88, "Pierce damages an enemy behind the first target")
	model.units[2]["cell"] = Vector2i(7, 6)
	model._act(model.units[0], model.units[1])
	_check(model.units[2]["hp"] == 88, "Pierce cannot hit an enemy outside the shot line")
	model = _duel("archer", Vector2i(2, 3), Vector2i(6, 3))
	ArenaEquipment.replace_loadout(model.units[0], ["ember_volley"])
	for i in range(4):
		model._act(model.units[0], model.units[1])
	_check(model.units[1]["burn_left"] == 4.0, "Ember Volley activates after four arrows")
	model.units[0]["attack_timer"] = 10.0
	model.units[1]["attack_timer"] = 10.0
	model.units[1]["move_timer"] = 10.0
	model.start()
	_steps(model, 80)
	_check(model.units[1]["hp"] == 892, "four seconds of burn cause four attributed seven-damage ticks")
	_check(model.units[0]["damage"] == 108, "burn contribution is credited to the Archer")
	_test_equipment_and_resources()

	var first := _complete_trial(0, false)
	_check(first == _complete_trial(0, false), "replaying the same trial is deterministic")
	_check(first["result"] != "Stalemate" and first["elapsed"] > 3.0, "authored breach reaches a real battle conclusion")
	var second := _complete_trial(1, true)
	_check(second["result"] != "Stalemate", "crossfire with Ember Volley reaches a real conclusion")
	_check(first["healing"] > 0, "healing contributes during the full authored encounter")
	_check(is_equal_approx(first["elapsed"], 12.1) and first["hp"] == [57, 95, 80, 110] and first["archer_damage"] == 356, "resource-driven defaults preserve the original breach outcome")
	_check(is_equal_approx(second["elapsed"], 12.7) and second["hp"] == [53, 48, 110] and second["archer_damage"] == 328, "resource-driven defaults preserve the original crossfire/Ember outcome")
	print("ARENA BALANCE: breach=", first, " crossfire/ember=", second)

	var scene = load("res://scenes/battle/ArenaTrial.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	await _test_stable_layout(scene)
	_test_drag_placement(scene)
	_test_equipment_ui(scene)
	_test_skill_tiers_and_unequip(scene)
	scene.begin_battle()
	var battle_formation: Array = scene.simulation.formation()
	_drag_mouse(scene.board, _hero_pointer(scene.board, 0), scene.board.cell_center(Vector2(0, 0)))
	_check(scene.simulation.formation() == battle_formation and scene.board._drag_uid == -1, "mouse drag cannot reposition heroes after combat starts")
	scene.toggle_pause()
	var elapsed_before: float = scene.simulation.elapsed
	scene._process(1.0)
	_check(scene.simulation.elapsed == elapsed_before, "Pause freezes actual UI-driven simulation")
	scene.toggle_pause()
	scene._process(0.2)
	_check(scene.simulation.elapsed > elapsed_before, "Resume continues actual simulation")
	scene.reset_trial()
	_check(not scene.simulation.running and scene.simulation.elapsed == 0.0, "Reposition resets battle health and timers")
	_check(scene.simulation.formation() == scene.formation, "Reposition preserves the chosen starting formation")
	scene.build_picker.select(1)
	scene.build_picker.item_selected.emit(1)
	_check(ArenaEquipment.has_ability(scene.simulation.units[1], "ember_volley") and scene.hero_cards[1]["icons"].get_child(0).tooltip_text.contains("Ember Volley"), "build selector changes the real simulation and its explanation")
	scene.free()
	var menu = load("res://scenes/MainMenu.tscn").instantiate()
	add_child(menu)
	var entry: Button = menu.get_node("MainLayout/LeftSection/ArenaTrialButton")
	_check(entry.visible and not entry.pressed.get_connections().is_empty(), "main menu exposes a connected Arena Trial entry")
	menu.free()
	var after := JSON.stringify([RunState.party, RunState.inventory, RunState.gold, RunState.meta,
		RunState.run_stats, RunState.pending_reward_node_id, RunState.current_node_id])
	_check(before == after, "arena and its UI do not mutate live run state or meta progress")
	_check(save_before == (FileAccess.get_file_as_bytes(RunState.SAVE_PATH) if FileAccess.file_exists(RunState.SAVE_PATH) else PackedByteArray()), "trial leaves saved run bytes unchanged")
	_check(meta_before == (FileAccess.get_file_as_bytes(RunState.META_SAVE_PATH) if FileAccess.file_exists(RunState.META_SAVE_PATH) else PackedByteArray()), "trial leaves meta save bytes unchanged")
	print("ARENA COMBAT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _test_equipment_and_resources() -> void:
	for id in ArenaEquipment.ABILITY_IDS:
		var definition := ArenaEquipment.find_ability(id)
		_check(definition != null and definition.id == id, "arena definition loads: " + id)
		_check(definition.validation_errors().is_empty(), "arena definition validates: " + id)
		_check(definition.get_icon_texture() != null and not definition.description_for().is_empty(), "definition supplies art and explanation: " + id)
	var model := ArenaSimulation.new()
	model.setup()
	_check(model.equip_ability(0, "ember_volley")["ok"], "cross-class ability equips through the shared API")
	_check(not model.equip_ability(0, "mend")["ok"], "three-slot capacity prevents overfilling")
	_check(not model.equip_ability(0, "ember_volley")["ok"], "duplicate ability is rejected")
	_check(model.remove_ability(0, "power_strike"), "equipped ability can be removed during preparation")
	_check(model.equip_ability(0, "mend")["ok"], "freed equipment slot can be reused")
	_check(not model.equip_ability(0, "unknown")["ok"], "unknown ability IDs cannot be equipped")
	_check(not model.equip_ability(4, "mend")["ok"], "the shelf cannot equip an enemy")
	model.remove_ability(0, "mend")
	_check(not model.equip_ability(0, "arcane_surge")["ok"], "a magic-only trigger cannot be equipped on a physical attacker")
	var before := ArenaEquipment.loadout_ids(model.units[0])
	var failed := ArenaEquipment.replace_loadout(model.units[0], ["mend", "mend"])
	_check(not failed["ok"] and before == ArenaEquipment.loadout_ids(model.units[0]), "invalid replacement does not partially consume a loadout")
	failed = ArenaEquipment.replace_loadout(model.units[0], ["mend", "unknown"])
	_check(not failed["ok"] and before == ArenaEquipment.loadout_ids(model.units[0]), "unknown replacement ingredient leaves equipment intact")
	model.units[0]["ability_cooldowns"]["challenge"] = 4.0
	_check(float(model.units[1]["ability_cooldowns"].get("challenge", 0)) == 0, "cooldown state is owned by each unit")
	var restored := model.hero_loadouts()
	model.setup([], 0, false, restored)
	_check(model.hero_loadouts() == restored and model.units[0]["ability_cooldowns"]["challenge"] == 0.0, "loadout restore preserves IDs while resetting runtime cooldowns")
	model.start()
	_check(not model.equip_ability(1, "ember_volley")["ok"] and not model.remove_ability(1, "pierce"), "combat locks both equipment paths")

	# Change a resource copy, then observe combat rather than inspecting dispatch code.
	model = _duel("mage", Vector2i(2, 3), Vector2i(6, 3))
	var surge := ArenaEquipment.find_ability("arcane_surge").duplicate(true) as ArenaAbilityData
	surge.trigger_count = 2
	surge.power = 2.0
	ArenaEquipment.replace_loadout(model.units[0], [])
	ArenaEquipment.equip(model.units[0], surge)
	model._act(model.units[0], model.units[1])
	model._act(model.units[0], model.units[1])
	_check(model.units[1]["hp"] == 946, "edited resource counter and multiplier change real spell damage")
	_check(surge.description_for().contains("200%") and surge.description_for().contains("2 casts"), "tooltip follows the same edited values used in combat")
	_check(ArenaEquipment.find_ability("arcane_surge").power == 1.5, "runtime test edits do not mutate the shared asset")
	var invalid := surge.duplicate() as ArenaAbilityData
	invalid.trigger_count = 0
	_check(not ArenaEquipment.can_equip(model.units[0], invalid)["ok"], "zero-count trigger is rejected before combat")
	invalid = ArenaEquipment.find_ability("ember_volley").duplicate() as ArenaAbilityData
	invalid.interval_seconds = 0.0
	_check(not ArenaEquipment.can_equip(model.units[0], invalid)["ok"], "zero-interval burn is rejected")
	invalid = ArenaEquipment.find_ability("mend").duplicate() as ArenaAbilityData
	invalid.activation = "after_attack"
	_check(not invalid.validation_errors().is_empty(), "unsupported activation/effect combinations are rejected")

	model = _duel("archer", Vector2i(2, 3), Vector2i(5, 3))
	model.units.append(model._unit("Rear", "raider", false, Vector2i(7, 3), 100, 1, 0, 0, 0, 5))
	model.units[2]["uid"] = 2
	model.equip_ability(0, "ember_volley")
	for i in range(4):
		model._act(model.units[0], model.units[1])
	_check(model.units[2]["hp"] == 52 and model.units[1]["burn_left"] == 4.0, "equipped piercing and burn both trigger in one build")
	model = _duel("warrior", Vector2i(2, 3), Vector2i(4, 3))
	model.equip_ability(0, "mend")
	model.units[0]["hp"] = 100
	model.start()
	model.step()
	# First action becomes a heal after its initial attack delay.
	_steps(model, 6)
	_check(model.units[0]["healing"] == 20, "Mend works on another class using its own healing multiplier")
	model = _duel("archer", Vector2i(2, 3), Vector2i(6, 3))
	var burn := ArenaEquipment.find_ability("ember_volley").duplicate() as ArenaAbilityData
	burn.power = 11
	burn.interval_seconds = 0.5
	burn.duration_seconds = 1.25
	ArenaEquipment.replace_loadout(model.units[0], [])
	ArenaEquipment.equip(model.units[0], burn)
	for i in range(4):
		model._act(model.units[0], model.units[1])
	model.units[0]["attack_timer"] = 10.0
	model.units[1]["attack_timer"] = 10.0
	model.units[1]["move_timer"] = 10.0
	model.start()
	_steps(model, 30)
	_check(model.units[1]["hp"] == 898, "burn damage, tick interval, and duration come from the equipped resource")

func _layout_snapshot(scene: Control) -> Dictionary:
	scene.board._layout_board()
	var cards: Array = []
	for card in scene.hero_cards:
		cards.append([card["panel"].get_global_rect(), card["icons"].get_global_rect(),
			card["health"].get_global_rect(), card["bar"].get_global_rect()])
	var toolbar: Array = []
	for button in [scene.encounter_picker, scene.build_picker, scene.speed_button, scene.pause_button, scene.reset_button, scene.start_button]:
		toolbar.append(button.get_global_rect())
	return {"board": scene.board.get_global_rect(), "tiles": scene.board.board_rect,
		"cell_size": scene.board.cell_size, "cards": cards,
		"shelf": scene.board.get_parent().get_child(1).get_global_rect(), "toolbar": toolbar,
		"instructions": scene.instruction_label.get_global_rect(), "status": scene.status_label.get_global_rect(),
		"footer": scene.footer_label.get_global_rect()}

func _settle_layout() -> void:
	for i in range(4):
		await get_tree().process_frame

func _check_layout(expected: Dictionary, actual: Dictionary, context: String) -> void:
	_check(expected == actual, "stable map, panels, slots, health, controls, and text regions: " + context)
	if expected != actual:
		for key in expected:
			if expected[key] != actual[key]:
				printerr("  layout changed ", key, ": ", expected[key], " -> ", actual[key])

func _test_stable_layout(scene: Control) -> void:
	var original: Array = scene.loadouts.duplicate(true)
	await _settle_layout()
	var expected := _layout_snapshot(scene)
	var cases := [
		[[], [], [], []],
		[["challenge"], ["pierce"], ["arcane_surge"], ["mend"]],
		[["challenge", "power_strike", "mend"], ["pierce", "ember_volley", "power_strike"], ["arcane_surge", "ember_volley", "mend"], ["mend", "holy_aura", "challenge"]],
		[["challenge_tier3", "power_strike_tier3", "mend_tier3"], ["pierce_tier3", "ember_volley_tier3", "power_strike_tier3"], ["arcane_surge_tier3", "ember_volley_tier3", "mend_tier3"], ["mend_tier3", "holy_aura_tier3", "challenge_tier3"]]
	]
	for i in range(cases.size()):
		scene.loadouts = cases[i]
		scene.reset_trial()
		await _settle_layout()
		_check_layout(expected, _layout_snapshot(scene), "loadout case %d" % i)
	for uid in range(4):
		scene._select_hero(uid)
		await _settle_layout()
		_check_layout(expected, _layout_snapshot(scene), "hero selection %d" % uid)
	for tier in range(3):
		scene.tier_picker.select(tier)
		scene.tier_picker.item_selected.emit(tier)
		await _settle_layout()
		_check_layout(expected, _layout_snapshot(scene), "shelf tier %d" % tier)
	scene._select_hero(0)
	scene.hero_cards[0]["icons"].get_child(0).pressed.emit()
	await _settle_layout()
	_check_layout(expected, _layout_snapshot(scene), "actual Unequip click")
	scene.shelf_buttons["challenge"].pressed.emit()
	await _settle_layout()
	_check_layout(expected, _layout_snapshot(scene), "actual Equip click")
	for card in scene.hero_cards:
		_check(card["icons"].get_child_count() == 3, "all heroes retain three fixed skill-slot boxes")
	scene.footer_label.text = "A deliberately long equipment message that should not push the map or hero boxes around. ".repeat(4)
	scene.instruction_label.text = "A long preparation instruction that should stay inside its own fixed region. ".repeat(4)
	for unit in scene.simulation.units:
		unit["damage"] = 123456789
		unit["healing"] = 123456789
		unit["prevented"] = 123456789
	scene._refresh_cards()
	await _settle_layout()
	_check_layout(expected, _layout_snapshot(scene), "long messages and large contribution numbers")
	scene.begin_battle()
	scene.toggle_pause()
	await _settle_layout()
	_check_layout(expected, _layout_snapshot(scene), "paused combat and locked equipment")
	scene.loadouts = original
	scene.tier_picker.select(0)
	scene.tier_picker.item_selected.emit(0)
	scene._select_hero(0)
	scene.reset_trial()
	await _settle_layout()
	_check_layout(expected, _layout_snapshot(scene), "return to preparation")
	var window := get_tree().root
	var old_size := window.size
	var old_scale := window.content_scale_size
	window.content_scale_size = Vector2i(1600, 900)
	window.size = Vector2i(1600, 900)
	await _settle_layout()
	var resized := _layout_snapshot(scene)
	_check(resized["board"] != expected["board"], "the layout still responds to an actual window resize")
	scene.loadouts = cases[0]
	scene.reset_trial()
	await _settle_layout()
	_check_layout(resized, _layout_snapshot(scene), "empty loadout in a resized window")
	scene.loadouts = cases[3]
	scene.reset_trial()
	await _settle_layout()
	_check_layout(resized, _layout_snapshot(scene), "full tier III loadout in a resized window")
	window.content_scale_size = old_scale
	window.size = old_size
	scene.loadouts = original
	scene.reset_trial()
	await _settle_layout()
	_check_layout(expected, _layout_snapshot(scene), "original window restored")

func _test_equipment_ui(scene: Control) -> void:
	var original: Array = scene.loadouts.duplicate(true)
	scene._select_hero(1)
	scene.shelf_buttons["ember_volley"].pressed.emit()
	_check(ArenaEquipment.has_ability(scene.simulation.units[1], "ember_volley") and scene.hero_cards[1]["icons"].get_child(1).get_meta("ability_id") == "ember_volley", "shelf button equips a skill and updates the real hero card")
	scene.reset_trial()
	_check(ArenaEquipment.has_ability(scene.simulation.units[1], "ember_volley"), "Reposition preserves custom equipment")
	scene.hero_cards[1]["icons"].get_child(1).pressed.emit()
	_check(not ArenaEquipment.has_ability(scene.simulation.units[1], "ember_volley"), "clicking the equipped icon removes the actual ability")
	scene._select_hero(0)
	_check(scene.shelf_buttons["arcane_surge"].disabled, "shelf explains and disables a magic-only skill for a physical hero")
	scene.loadouts = original
	scene.reset_trial()

func _test_skill_tiers_and_unequip(scene: Control) -> void:
	_check(ArenaEquipment.catalog_ids().size() == 21, "catalog offers seven families at three tiers")
	_check(SkillVisualStyle.PHYSICAL.r > SkillVisualStyle.PHYSICAL.b and SkillVisualStyle.PHYSICAL.r > SkillVisualStyle.PHYSICAL.g, "physical skills use red")
	_check(SkillVisualStyle.MAGIC.b > SkillVisualStyle.MAGIC.r and SkillVisualStyle.MAGIC.b > SkillVisualStyle.MAGIC.g, "magic skills use blue")
	_check(SkillVisualStyle.HEALING.g > SkillVisualStyle.HEALING.r and SkillVisualStyle.HEALING.g > SkillVisualStyle.HEALING.b, "healing skills use green")
	for family in ArenaEquipment.ABILITY_IDS:
		var first := ArenaEquipment.find_ability(family)
		var second := ArenaEquipment.find_ability(ArenaEquipment.variant_id(family, 2))
		var third := ArenaEquipment.find_ability(ArenaEquipment.variant_id(family, 3))
		_check(second.validation_errors().is_empty() and third.validation_errors().is_empty(), "higher tier definitions validate: " + family)
		_check(first.family_key() == second.family_key() and second.family_key() == third.family_key(), "tiers share a family: " + family)
		_check(second.power > first.power and third.power > second.power, "tiers increase actual effect strength: " + family)
		_check(second.get_icon_texture() != null and third.get_icon_texture() != null and second.icon_path != first.icon_path and third.icon_path != second.icon_path, "tiers use their distinct existing illustrations: " + family)
		_check(first.type_color == second.type_color and second.type_color == third.type_color, "type color stays consistent across tiers: " + family)
	var original: Array = scene.loadouts.duplicate(true)
	scene._select_hero(0)
	_check(not scene.shelf_buttons["challenge"].disabled and scene.shelf_buttons["challenge"].text.contains("Unequip"), "equipped shelf entry becomes an active Unequip button")
	scene.shelf_buttons["challenge"].pressed.emit()
	_check(not ArenaEquipment.has_ability(scene.simulation.units[0], "challenge") and scene.shelf_buttons["challenge"].text.contains("Equip"), "clicking equipped shelf skill unequips it and restores Equip action")
	scene.shelf_buttons["challenge"].pressed.emit()
	_check(ArenaEquipment.has_ability(scene.simulation.units[0], "challenge"), "same shelf entry can equip the skill again")
	scene.tier_picker.select(1)
	scene.tier_picker.item_selected.emit(1)
	_check(scene.shelf_icons["power_strike"].skill_tier == 2 and scene.shelf_buttons["power_strike"].disabled, "tier filter changes the actual shelf variant and blocks stacking another tier")
	for button in scene.hero_cards[0]["icons"].get_children():
		if button.get_meta("ability_id", "") == "power_strike":
			button.pressed.emit()
			break
	scene.shelf_buttons["power_strike"].pressed.emit()
	_check(ArenaEquipment.has_ability(scene.simulation.units[0], "power_strike_tier2") and scene.shelf_buttons["power_strike"].text.contains("Unequip"), "higher-tier shelf entry equips and exposes its own Unequip action")
	_check(not scene.simulation.equip_ability(0, "power_strike_tier3")["ok"], "two tiers of the same family cannot occupy separate slots")
	var model := _duel()
	ArenaEquipment.replace_loadout(model.units[0], ["power_strike_tier3"])
	for i in range(3):
		model._act(model.units[0], model.units[1])
	_check(model.units[1]["hp"] == 896, "tier III power changes actual combat damage")
	scene.loadouts = original
	scene.tier_picker.select(0)
	scene.tier_picker.item_selected.emit(0)
	scene.reset_trial()

func _test_drag_placement(scene: Control) -> void:
	var board: ArenaBoard = scene.board
	board._layout_board()
	get_viewport().notify_mouse_entered()
	var initial: Array = scene.simulation.formation()
	var from := _hero_pointer(board, 0)
	var destination := board.cell_center(Vector2(4, 1))
	_mouse_button(board, from, true)
	_mouse_motion(board, destination, destination - from)
	_check(board._dragging and board.selected == 0, "mouse press and motion pick up the actual hero")
	_check(scene.simulation.formation() == initial, "drag preview does not commit formation before release")
	_check(board._valid_drop(destination), "legal empty destination is highlighted as valid")
	_mouse_button(board, destination, false)
	_check(scene.simulation.units[0]["cell"] == Vector2i(4, 1), "mouse release places the hero on the destination cell")
	_check(scene.formation[0] == Vector2i(4, 1), "drag placement updates the formation retained by Reposition")
	_check(board._drag_uid == -1 and not board._dragging, "release clears the drag preview")
	var archer_origin: Vector2i = scene.simulation.units[1]["cell"]
	_drag_mouse(board, _hero_pointer(board, 0), board.cell_center(Vector2(archer_origin)))
	_check(scene.simulation.units[0]["cell"] == archer_origin and scene.simulation.units[1]["cell"] == Vector2i(4, 1), "dropping onto another hero swaps both authoritative cells")
	_check(scene.formation == scene.simulation.formation(), "a drag swap updates both saved local formation entries")
	scene.reset_trial()
	var before: Array = scene.simulation.formation()
	_drag_mouse(board, _hero_pointer(board, 0), board.cell_center(Vector2(10, 3)))
	_check(scene.simulation.formation() == before, "dropping in enemy territory cancels without moving or swapping")
	_drag_mouse(board, _hero_pointer(board, 0), Vector2(-15, 0))
	_check(scene.simulation.formation() == before and board._drag_uid == -1, "releasing outside the board cancels and clears the preview")
	from = _hero_pointer(board, 0)
	_mouse_button(board, from, true)
	_mouse_motion(board, destination, destination - from)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	get_viewport().push_input(escape, true)
	_mouse_button(board, destination, false)
	_check(scene.simulation.formation() == before and not board._dragging, "Escape cancels placement without a late release committing it")
	_mouse_button(board, from, true)
	_mouse_motion(board, destination, destination - from)
	scene.get_window().focus_exited.emit()
	_mouse_button(board, destination, false)
	_check(scene.simulation.formation() == before and board._drag_uid == -1, "losing window focus cancels a held drag")
	_mouse_button(board, from, true)
	_mouse_motion(board, from + Vector2(2, 0), Vector2(2, 0))
	_mouse_button(board, from + Vector2(2, 0), false)
	_check(scene.simulation.formation() == before and board.selected == 0, "small pointer jitter remains a click selection")
	var mage_hat := board.cell_center(Vector2(scene.simulation.units[2]["cell"])) - Vector2(0, 32)
	_mouse_button(board, mage_hat, true)
	_mouse_button(board, mage_hat, false)
	_check(board.selected == 2 and scene.simulation.formation() == before, "clicking a hero above its cell selects the drawn figure")
	var empty := board.cell_center(Vector2(0, 0))
	_mouse_button(board, empty, true)
	_mouse_button(board, empty, false)
	_check(scene.simulation.units[2]["cell"] == Vector2i(0, 0), "select then click an empty cell still works")
	board.selected = 0
	mage_hat = board.cell_center(Vector2(0, 0)) - Vector2(0, 32)
	_mouse_button(board, mage_hat, true)
	_mouse_button(board, mage_hat, false)
	_check(board.selected == 2, "a hero's head remains selectable above the top row")
	# Restore baseline so later combat/UI checks retain their authored scenario.
	scene.formation = initial
	scene.reset_trial()

func _hero_pointer(board: ArenaBoard, uid: int) -> Vector2:
	return board.cell_center(board.visual_positions[uid]) - Vector2(0, 10)

func _drag_mouse(board: ArenaBoard, from: Vector2, to: Vector2) -> void:
	_mouse_button(board, from, true)
	_mouse_motion(board, to, to - from)
	_mouse_button(board, to, false)

func _mouse_button(board: ArenaBoard, local_position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = board.get_global_transform_with_canvas() * local_position
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	get_viewport().push_input(event, true)

func _mouse_motion(board: ArenaBoard, local_position: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = board.get_global_transform_with_canvas() * local_position
	event.global_position = event.position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event, true)

func _first_enemy_target(reversed: bool) -> int:
	var model := ArenaSimulation.new()
	var front := Vector2i(4, 3)
	var back := Vector2i(1, 3)
	model.units.append(model._unit("Warrior", "warrior", true, back if reversed else front, 500, 1, 0, 0, 0, 4))
	model.units.append(model._unit("Mage", "mage", true, front if reversed else back, 500, 1, 0, 1, 0, 4))
	model.units.append(model._unit("Enemy", "raider", false, Vector2i(9, 3), 1000, 12, 0, 0, 0, 5))
	for i in range(model.units.size()):
		model.units[i]["uid"] = i
	ArenaEquipment.remove(model.units[0], "challenge")
	model.start()
	for i in range(200):
		model.step()
		for event in model.take_events():
			if event["kind"] == "damage" and event["source"] == 2:
				return event["target"]
	return -1

func _complete_trial(encounter: int, ember: bool) -> Dictionary:
	var model := ArenaSimulation.new()
	model.setup([], encounter, ember)
	model.start()
	var valid_positions := true
	var valid_attacks := true
	while model.running:
		model.step()
		var occupied := {}
		for unit in model.units:
			if unit["alive"]:
				valid_positions = valid_positions and model.inside_board(unit["cell"]) and not occupied.has(unit["cell"])
				occupied[unit["cell"]] = true
		for event in model.take_events():
			if event["kind"] == "damage" and event["text"] != "Burn":
				var reach := 5.5 if event["text"] == "Pierce" else float(model.get_unit(event["source"])["range"])
				valid_attacks = valid_attacks and Vector2(event["from"]).distance_to(Vector2(event["to"])) <= reach
	_check(valid_positions, "full encounter keeps every living unit on board in a unique cell")
	_check(valid_attacks, "full encounter only produces attacks within their declared range")
	return {"result": model.result, "elapsed": model.elapsed,
		"hp": model.living(true).map(func(u): return u["hp"]),
		"healing": model.units[3]["healing"], "archer_damage": model.units[1]["damage"]}
