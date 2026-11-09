class_name RunBattleScene
extends "res://scenes/battle/ArenaTrial.gd"
# PURPOSE: One arena battle screen for saved runs, preparation, and team inspection.

var encounter_enemies: Array = []
var inventory_list: VBoxContainer
var back_button: Button
var committed := false
var viewing_reward := false
var viewing_completed := false

func _ready() -> void:
	simulation = RunArenaSimulation.new()
	encounter_enemies = RunEncounterAdapter.enemies_for_node(RunState.get_current_node_data())
	_build_interface()
	encounter_picker.hide()
	build_picker.hide()
	reset_button.text = "Auto formation"
	for label in find_children("*", "Label", true, false):
		if label.text == "Arena Trial":
			label.text = "Battle · v0.2"
	for button in find_children("*", "Button", true, false):
		if button.text == "Main menu":
			back_button = button
			back_button.tooltip_text = "Save preparation and return to the main menu."
			back_button.pressed.connect(func(): RunState.save_run())
	board.formation_changed.connect(_save_formation)
	reset_trial()

func reset_trial() -> void:
	if simulation.running or committed:
		return
	if not simulation.units.is_empty():
		formation.clear()
		for i in range(RunState.party.size()):
			var data: HeroData = RunState.party[i]["data"]
			formation.append(Vector2i(5 if data.preferred_row == "front" else 2, i + 1))
	_rebuild_preparation()
	_save_formation()

func _rebuild_preparation() -> void:
	simulation.setup_run(RunState.party, encounter_enemies, formation)
	formation = simulation.formation()
	board.setup(simulation)
	board.selected = clampi(board.selected, 0, maxi(0, RunState.party.size() - 1))
	viewing_reward = not RunState.pending_reward_node_id.is_empty() and RunState.pending_reward_node_id == RunState.current_node_id
	viewing_completed = RunState.completed_node_ids.has(RunState.current_node_id)
	pause_button.disabled = true
	start_button.text = "RETURN TO REWARDS" if viewing_reward else "Begin battle"
	if viewing_completed and not viewing_reward:
		start_button.text = "Return to map"
	start_button.disabled = not viewing_reward and (simulation.living(true).is_empty() or not RunState.run_active)
	status_label.text = "TEAM" if viewing_reward else "PREPARATION"
	instruction_label.text = "Drag heroes to move or swap. Select a hero, then equip skills from your inventory."
	footer_label.text = "Owned skills only · Equipment and formation are saved."
	_refresh_icons()
	_refresh_cards()
	_refresh_shelf()

func _save_formation() -> void:
	if simulation.running or committed:
		return
	formation = simulation.formation()
	for i in range(mini(formation.size(), RunState.party.size())):
		RunState.party[i]["arena_cell"] = formation[i]
	RunState.save_run()

func _build_skill_shelf(parent: Control) -> void:
	var panel := Panel.new()
	panel.custom_minimum_size.x = 226
	panel.clip_contents = true
	parent.add_child(panel)
	var column := VBoxContainer.new()
	_panel_margin(panel, 10, 10).add_child(column)
	shelf_title = _label(column, "Inventory", 15, Color("e1d3b8"))
	_clip_line(shelf_title)
	var auto := _button(column, "Auto-equip", _auto_equip)
	auto.set_meta("auto_equip", true)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	column.add_child(scroll)
	inventory_list = VBoxContainer.new()
	inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inventory_list)

func _can_edit() -> bool:
	return not simulation.running and not committed and simulation.result.is_empty()

func _compatible(skill: SkillData, hero: Dictionary) -> bool:
	return skill.compatible_classes.is_empty() or hero["data"].hero_class in skill.compatible_classes

func _refresh_shelf() -> void:
	if inventory_list == null:
		return
	for child in inventory_list.get_children():
		inventory_list.remove_child(child)
		child.queue_free()
	shelf_title.text = "Inventory · %d/%d" % [RunState.inventory.size(), RunState.MAX_INVENTORY_SLOTS]
	if board.selected >= RunState.party.size():
		return
	var hero: Dictionary = RunState.party[board.selected]
	for i in range(RunState.inventory.size()):
		var skill: SkillData = RunState.inventory[i]
		var button := _button(inventory_list, "", _equip_inventory.bind(i))
		button.custom_minimum_size.y = 52
		button.clip_text = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 12)
		button.text = "%s %s\nEquip" % [skill.display_name, SkillVisualStyle.roman(skill.tier)]
		button.tooltip_text = skill.description
		button.disabled = not _can_edit() or not _compatible(skill, hero) or hero["skills"].size() >= hero["data"].skill_slots
		SkillVisualStyle.style_button(button, skill.skill_type, skill.tier)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.get_theme_stylebox(state).content_margin_left = 44
		var icon := SkillIcon.new()
		button.add_child(icon)
		icon.position = Vector2(5, 7)
		icon.size = Vector2(34, 34)
		icon.setup(skill)
	if RunState.inventory.is_empty():
		_label(inventory_list, "No spare skills", 13, Color("8996a9"))

func _equip_inventory(index: int) -> void:
	if not _can_edit() or index < 0 or index >= RunState.inventory.size() or board.selected >= RunState.party.size():
		return
	var hero: Dictionary = RunState.party[board.selected]
	var skill: SkillData = RunState.inventory[index]
	if not _compatible(skill, hero) or hero["skills"].size() >= hero["data"].skill_slots:
		return
	hero["skills"].append(skill)
	RunState.inventory.remove_at(index)
	EventBus.item_removed.emit(skill)
	RunState.save_run()
	_rebuild_preparation()

func _unequip_slot(hero_index: int, slot: int) -> void:
	if not _can_edit() or hero_index >= RunState.party.size():
		return
	var hero: Dictionary = RunState.party[hero_index]
	if slot >= hero["skills"].size():
		return
	if RunState.inventory.size() >= RunState.MAX_INVENTORY_SLOTS:
		footer_label.text = "Inventory full. Make room before unequipping."
		return
	var skill: SkillData = hero["skills"][slot]
	hero["skills"].remove_at(slot)
	# Transfer ownership directly so unequipping cannot invoke acquisition crafting.
	RunState.inventory.append(skill)
	RunState.save_run()
	_rebuild_preparation()

func _auto_equip() -> void:
	if _can_edit():
		RunState.auto_equip_skills()
		_rebuild_preparation()

func _refresh_icons() -> void:
	for i in range(hero_cards.size()):
		var card: Dictionary = hero_cards[i]
		card["panel"].visible = i < RunState.party.size()
		if i >= RunState.party.size():
			continue
		var hero: Dictionary = RunState.party[i]
		var icons: HBoxContainer = card["icons"]
		for child in icons.get_children():
			icons.remove_child(child)
			child.queue_free()
		for slot in range(hero["data"].skill_slots):
			if slot >= hero["skills"].size():
				_add_empty_slot(icons)
				continue
			var skill: SkillData = hero["skills"][slot]
			var button := _button(icons, "", _unequip_slot.bind(i, slot))
			button.custom_minimum_size = Vector2(44, 54)
			button.disabled = not _can_edit()
			button.tooltip_text = skill.display_name + "\n" + skill.description + "\nClick to unequip."
			var icon := SkillIcon.new()
			button.add_child(icon)
			icon.position = Vector2(3, 1)
			icon.size = Vector2(38, 36)
			icon.setup(skill)
			var label := _label(button, "UNEQUIP" if _can_edit() else "EQUIPPED", 9, Color("e1d3b8"))
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			label.offset_top = -15
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _refresh_cards() -> void:
	super._refresh_cards()
	for i in range(mini(hero_cards.size(), RunState.party.size())):
		var unit := simulation.get_unit(i)
		var progress: Array[String] = []
		for skill in unit["skills"]:
			progress.append("%s %.1fs" % [skill.display_name, unit["skill_timers"].get(skill.id, 0.0)])
		hero_cards[i]["charge"].text = " · ".join(progress)
		hero_cards[i]["charge"].tooltip_text = "\n".join(progress)
		hero_cards[i]["panel"].tooltip_text = unit["data"].trait_name + "\n" + unit["data"].trait_description

func begin_battle() -> void:
	if viewing_reward:
		EventBus.scene_change_requested.emit("res://scenes/battle/RewardScene.tscn")
		return
	if viewing_completed:
		EventBus.scene_change_requested.emit("res://scenes/map/MapView.tscn")
		return
	if not _can_edit() or not RunState.run_active or simulation.living(true).is_empty():
		return
	_save_formation()
	board.cancel_drag()
	simulation.start()
	EventBus.battle_started.emit()
	start_button.disabled = true
	reset_button.disabled = true
	back_button.disabled = true
	pause_button.disabled = false
	_refresh_icons()
	_refresh_shelf()

func _select_hero(uid: int) -> void:
	if uid >= 0 and uid < RunState.party.size():
		super._select_hero(uid)

func _process(delta: float) -> void:
	if not is_instance_valid(board):
		return
	if simulation.running and not paused:
		accumulator += minf(delta, 0.25) * playback_speed
		while accumulator >= ArenaSimulation.STEP and simulation.running:
			accumulator -= ArenaSimulation.STEP
			simulation.step()
		board.consume_events(simulation.take_events())
	status_label.text = "%s · %.1fs" % ["PAUSED" if paused else "BATTLE" if simulation.running else "PREPARATION", simulation.elapsed]
	if not simulation.result.is_empty():
		status_label.text = simulation.result.to_upper()
		_commit_result()
	_refresh_cards()

func _commit_result() -> void:
	if committed or viewing_reward or viewing_completed or simulation.result.is_empty():
		return
	committed = true
	pause_button.disabled = true
	var victory := simulation.result == "Victory"
	for unit in simulation.units:
		if unit["hero"]:
			RunState.party[unit["party_index"]]["current_hp"] = unit["hp"]
		else:
			RunState.record_enemy_discovery(unit["data"].id)
			if not unit["alive"]:
				RunState.run_stats["enemies_killed"] += 1
				RunState.add_gold(simulation.rng.randi_range(unit["data"].gold_drop_min, unit["data"].gold_drop_max))
				var drop: String = unit["data"].boss_guaranteed_drop_id
				if unit["data"].is_boss and not drop.is_empty():
					var skill = GameData.get_skill(drop)
					if skill != null:
						RunState.add_item(skill)
	RunState.run_stats["battles_won"] += 1 if victory else 0
	RunState.run_stats["turns_survived"] += int(simulation.elapsed / RunArenaSimulation.TICK_SECONDS)
	_refresh_icons()
	_refresh_shelf()
	EventBus.battle_ended.emit("win" if victory else "lose")
