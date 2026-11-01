extends Control

@onready var battle_manager: BattleManager = $BattleManager
@onready var battle_layout: HBoxContainer = $HBoxContainer
@onready var hero_side: VBoxContainer = $HBoxContainer/HeroSide
@onready var hero_grid: GridContainer = $HBoxContainer/HeroSide/HeroGrid
@onready var enemy_side: VBoxContainer = $HBoxContainer/EnemySide
@onready var enemy_grid: GridContainer = $HBoxContainer/EnemySide/EnemyGrid
@onready var log_label: RichTextLabel = $LogPanel/LogLabel
@onready var party_buff_label: RichTextLabel = $PartyBuffPanel/PartyBuffLabel

@onready var prep_ui: VBoxContainer = $HBoxContainer/PreparationUI
@onready var start_button: Button = $HBoxContainer/PreparationUI/StartBattleButton
@onready var inventory_panel: Panel = $InventoryPanel
@onready var inventory_grid: Container = $InventoryPanel/VBoxContainer/ScrollContainer/InventoryGrid
@onready var log_panel: Panel = $LogPanel
@onready var skip_button: Button = $SkipButton

const COMBATANT_UI = preload("res://scenes/battle/CombatantUI.tscn")
const BATTLE_SLOT  = preload("res://scenes/battle/BattleSlot.gd")
const INVENTORY_SLOT = preload("res://scenes/battle/InventorySlot.gd")

const BATTLE_GRID_COLUMNS := 4
const BATTLE_GRID_ROWS := 3
const BATTLE_GRID_GAP := 6
const MIN_SLOT_SIZE := Vector2(104, 124)

func _ready() -> void:
	resized.connect(_resize_battle_grids)

	# 1. Setup fallback data for testing (only if party is empty)
	_setup_test_run()

	# 2. Connect to signals
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.battle_ended.connect(_on_battle_ended)
	EventBus.skill_cast.connect(_on_skill_cast)
	start_button.pressed.connect(_on_start_battle_pressed)
	skip_button.pressed.connect(_on_skip_pressed)

	# 3. Determine enemies based on current node
	var enemies = _get_enemies_for_current_node()

	# 4. Initialize battle data (paused)
	battle_manager.init_battle(RunState.party, enemies)

	# 5. Spawn preparation visuals (grids and combatants)
	_spawn_visuals()
	_populate_inventory()
	_refresh_party_buffs()

	# 6. Add helper buttons to Prep UI
	var formation_button = Button.new()
	formation_button.text = "AUTO FORMATION"
	formation_button.custom_minimum_size = Vector2(0, 40)
	prep_ui.add_child(formation_button)
	prep_ui.move_child(formation_button, start_button.get_index())
	formation_button.pressed.connect(_on_auto_formation_pressed)

	var auto_button = Button.new()
	auto_button.text = "AUTO-EQUIP SKILLS"
	auto_button.custom_minimum_size = Vector2(0, 40)
	prep_ui.add_child(auto_button)
	prep_ui.move_child(auto_button, start_button.get_index())
	auto_button.pressed.connect(_on_auto_equip_pressed)

	# 7. Check if we are returning from a Reward Scene
	if not RunState.pending_reward_node_id.is_empty() and RunState.pending_reward_node_id == RunState.current_node_id:
		start_button.text = "RETURN TO REWARDS"
		start_button.remove_theme_color_override("font_color")
		start_button.add_theme_color_override("font_color", Color(1, 1, 0)) # Yellow
		# Disconnect old and connect new
		start_button.pressed.disconnect(_on_start_battle_pressed)
		start_button.pressed.connect(func(): EventBus.scene_change_requested.emit("res://scenes/battle/RewardScene.tscn"))

	call_deferred("_resize_battle_grids")

func _on_auto_equip_pressed() -> void:
	RunState.auto_equip_skills()

	for i in range(battle_manager.heroes.size()):
		var hero = battle_manager.heroes[i]
		# Find the updated hero data from RunState (the live BM copy needs syncing)
		var rs_hero = RunState.party[hero["party_index"]]
		hero["skills"] = rs_hero["skills"].duplicate()

	_refresh_hero_grid()

	_populate_inventory()

func _on_auto_formation_pressed() -> void:
	_apply_auto_formation()
	_refresh_hero_grid()
	RunState.save_run()

func _on_start_battle_pressed() -> void:
	prep_ui.visible = false
	inventory_panel.visible = false
	log_panel.visible = true
	skip_button.visible = true
	battle_manager.begin_combat()

func _on_skip_pressed() -> void:
	skip_button.disabled = true
	battle_manager.skip_battle()

func _setup_test_run() -> void:
	# Only runs if we launched BattleScene directly without a party
	if RunState.party.is_empty():
		RunState.add_hero_to_party(load("res://resources/heroes/warrior.tres"))
		RunState.add_hero_to_party(load("res://resources/heroes/archer.tres"))
		RunState.add_hero_to_party(load("res://resources/heroes/mage.tres"))
		RunState.add_hero_to_party(load("res://resources/heroes/cleric.tres"))
		RunState.current_node_id = "node_0_0"
		# Initialize map if empty
		if RunState.current_map.is_empty():
			var gen = MapGenerator.new()
			RunState.current_map = gen.generate_map()

func _get_enemies_for_current_node() -> Array:
	var node_data = RunState.get_current_node_data()
	var type = node_data.get("type", "battle")
	var enemy_list = []

	match type:
		"boss":
			var boss_pool = [
				"res://resources/enemies/boss_abyssal_behemoth.tres",
				"res://resources/enemies/boss_spectral_weaver.tres",
				"res://resources/enemies/boss_void_reaper.tres"
			]
			enemy_list.append(load(boss_pool.pick_random()))
		"elite":
			enemy_list.append(load("res://resources/enemies/skeleton.tres"))
			enemy_list.append(load("res://resources/enemies/goblin.tres"))
		"battle":
			var count = randi_range(2, 3)
			var pool = [
				"res://resources/enemies/slime.tres",
				"res://resources/enemies/goblin.tres",
				"res://resources/enemies/skeleton.tres"
			]
			for i in range(count):
				enemy_list.append(load(pool.pick_random()))
		_:
			enemy_list.append(load("res://resources/enemies/slime.tres"))

	return enemy_list

func _spawn_visuals() -> void:
	hero_grid.columns = BATTLE_GRID_COLUMNS
	enemy_grid.columns = BATTLE_GRID_COLUMNS
	hero_grid.add_theme_constant_override("h_separation", BATTLE_GRID_GAP)
	hero_grid.add_theme_constant_override("v_separation", BATTLE_GRID_GAP)
	enemy_grid.add_theme_constant_override("h_separation", BATTLE_GRID_GAP)
	enemy_grid.add_theme_constant_override("v_separation", BATTLE_GRID_GAP)

	# 1. Create expanded slots for Heroes
	for i in range(_battle_slot_count()):
		var slot = BATTLE_SLOT.new()
		slot.slot_index = i
		slot.is_hero_side = true
		hero_grid.add_child(slot)

	# 2. Create expanded slots for Enemies
	for i in range(_battle_slot_count()):
		var slot = BATTLE_SLOT.new()
		slot.slot_index = i
		slot.is_hero_side = false
		enemy_grid.add_child(slot)

	_resize_battle_grids()

	# 3. Add heroes to their specific slots
	for i in range(battle_manager.heroes.size()):
		var hero = battle_manager.heroes[i]
		var ui = COMBATANT_UI.instantiate()
		# Use saved slot_index, or fallback to i if missing (old saves)
		var s_idx = _get_valid_slot_index(hero, i, hero_grid)
		var target_slot = hero_grid.get_child(s_idx)
		target_slot.add_child(ui)
		ui.setup(hero)

	# 4. Add enemies to their slots (sequentially)
	for i in range(battle_manager.enemies.size()):
		var enemy = battle_manager.enemies[i]
		if i >= enemy_grid.get_child_count():
			break
		var ui = COMBATANT_UI.instantiate()
		var target_slot = enemy_grid.get_child(i)
		target_slot.add_child(ui)
		ui.setup(enemy)

func _battle_slot_count() -> int:
	return BATTLE_GRID_COLUMNS * BATTLE_GRID_ROWS

func _get_valid_slot_index(combatant: Dictionary, fallback_index: int, grid: GridContainer) -> int:
	var slot_count = grid.get_child_count()
	if slot_count == 0:
		return 0
	var requested = int(combatant.get("slot_index", fallback_index))
	if requested < 0 or requested >= slot_count:
		requested = clampi(fallback_index, 0, slot_count - 1)
		combatant["slot_index"] = requested
		if combatant.has("party_index") and combatant["party_index"] < RunState.party.size():
			RunState.party[combatant["party_index"]]["slot_index"] = requested
	return requested

func _refresh_hero_grid() -> void:
	_refresh_party_buffs()

	for slot in hero_grid.get_children():
		for child in slot.get_children():
			slot.remove_child(child)
			child.queue_free()

	for i in range(battle_manager.heroes.size()):
		var hero = battle_manager.heroes[i]
		var ui = COMBATANT_UI.instantiate()
		var s_idx = _get_valid_slot_index(hero, i, hero_grid)
		var target_slot = hero_grid.get_child(s_idx)
		target_slot.add_child(ui)
		ui.setup(hero)

func _refresh_party_buffs() -> void:
	var active_by_id := {}

	for hero in battle_manager.heroes:
		var synergies = SynergyManager.get_active_synergies(hero.get("skills", []))
		hero["active_synergies"] = synergies

		for synergy in synergies:
			var synergy_id = synergy["id"]
			if not active_by_id.has(synergy_id):
				active_by_id[synergy_id] = {
					"display_name": synergy["display_name"],
					"description": synergy["description"],
					"count": 0,
					"heroes": []
				}

			var entry = active_by_id[synergy_id]
			entry["count"] += 1
			entry["heroes"].append(hero["display_name"])

	if active_by_id.is_empty():
		party_buff_label.text = "[center][color=#8f8f9d]Party Buffs: None[/color][/center]"
		party_buff_label.tooltip_text = "Equip matching skill types to activate party buffs."
		return

	var entries := []
	var tooltip_lines := []
	for synergy_id in active_by_id.keys():
		var entry = active_by_id[synergy_id]
		var count_text = " x%d" % entry["count"] if entry["count"] > 1 else ""
		entries.append("[color=#ffd84d]%s%s[/color] [color=#bfc0ca](%s)[/color]" % [
			entry["display_name"],
			count_text,
			_synergy_bonus_text(entry["description"])
		])
		tooltip_lines.append("%s%s: %s\nHeroes: %s" % [
			entry["display_name"],
			count_text,
			entry["description"],
			", ".join(entry["heroes"])
		])

	party_buff_label.text = "[center][b]Party Buffs:[/b] %s[/center]" % "   |   ".join(entries)
	party_buff_label.tooltip_text = "\n\n".join(tooltip_lines)

func _synergy_bonus_text(description: String) -> String:
	var separator_index = description.find(":")
	if separator_index == -1:
		return description
	return description.substr(separator_index + 1).strip_edges()

func _apply_auto_formation() -> void:
	var front_heroes: Array = []
	var back_heroes: Array = []

	for hero in battle_manager.heroes:
		if _hero_prefers_front(hero):
			front_heroes.append(hero)
		else:
			back_heroes.append(hero)

	front_heroes.sort_custom(Callable(self, "_sort_frontline_heroes"))
	back_heroes.sort_custom(Callable(self, "_sort_backline_heroes"))

	var used_slots := {}
	_assign_heroes_to_slots(front_heroes, _formation_column_slot_order([BATTLE_GRID_COLUMNS - 1, BATTLE_GRID_COLUMNS - 2]), used_slots)
	_assign_heroes_to_slots(back_heroes, _formation_column_slot_order([0, 1, 2, BATTLE_GRID_COLUMNS - 1]), used_slots)

func _hero_prefers_front(hero: Dictionary) -> bool:
	var data = hero.get("data", null)
	if data == null:
		return false
	if data.preferred_row == "front":
		return true

	var hero_class = data.hero_class
	return hero_class == "warrior" or hero_class == "captain"

func _sort_frontline_heroes(a: Dictionary, b: Dictionary) -> bool:
	return _durability_score(a) > _durability_score(b)

func _sort_backline_heroes(a: Dictionary, b: Dictionary) -> bool:
	return _durability_score(a) < _durability_score(b)

func _durability_score(hero: Dictionary) -> int:
	var data = hero.get("data", null)
	if data == null:
		return 0
	var hp = hero.get("max_hp", hero.get("max_hp_override", data.base_hp))
	var physical_def = hero.get("def", data.base_def)
	var magic_def = hero.get("magic_def", data.base_magic_def)
	return int(hp) + int(physical_def) * 8 + int(magic_def) * 4

func _formation_column_slot_order(columns: Array) -> Array:
	var centered_rows = _centered_row_order()
	var order := []
	for col in columns:
		if col < 0 or col >= BATTLE_GRID_COLUMNS:
			continue
		for row in centered_rows:
			order.append(row * BATTLE_GRID_COLUMNS + col)
	return order

func _centered_row_order() -> Array:
	var rows := []
	var center = int(floor(float(BATTLE_GRID_ROWS) / 2.0))
	rows.append(center)

	for offset in range(1, BATTLE_GRID_ROWS):
		var upper = center - offset
		var lower = center + offset
		if upper >= 0:
			rows.append(upper)
		if lower < BATTLE_GRID_ROWS:
			rows.append(lower)

	return rows

func _assign_heroes_to_slots(heroes: Array, slot_order: Array, used_slots: Dictionary) -> void:
	var slot_cursor := 0
	for hero in heroes:
		while slot_cursor < slot_order.size() and used_slots.has(slot_order[slot_cursor]):
			slot_cursor += 1
		if slot_cursor >= slot_order.size():
			break

		var slot_index = slot_order[slot_cursor]
		used_slots[slot_index] = true
		_set_hero_slot(hero, slot_index)
		slot_cursor += 1

func _set_hero_slot(hero: Dictionary, slot_index: int) -> void:
	hero["slot_index"] = slot_index
	if hero.has("party_index") and hero["party_index"] < RunState.party.size():
		RunState.party[hero["party_index"]]["slot_index"] = slot_index

func _resize_battle_grids() -> void:
	if not is_node_ready():
		return

	var slot_size = _calculate_slot_size()
	for grid in [hero_grid, enemy_grid]:
		grid.columns = BATTLE_GRID_COLUMNS
		grid.add_theme_constant_override("h_separation", BATTLE_GRID_GAP)
		grid.add_theme_constant_override("v_separation", BATTLE_GRID_GAP)
		for slot in grid.get_children():
			if slot.has_method("set_slot_size"):
				slot.set_slot_size(slot_size)
			else:
				slot.custom_minimum_size = slot_size

func _calculate_slot_size() -> Vector2:
	var side_width = minf(hero_side.size.x, enemy_side.size.x)
	if side_width <= 1.0:
		side_width = maxf((size.x - prep_ui.custom_minimum_size.x - battle_layout.get_theme_constant("separation") * 2.0) / 2.0, 0.0)

	var label_height = maxf(hero_side.get_node("Label").size.y, enemy_side.get_node("Label").size.y)
	var side_height = minf(hero_side.size.y, enemy_side.size.y) - label_height - BATTLE_GRID_GAP
	if side_height <= 1.0:
		side_height = maxf(size.y - inventory_panel.size.y - label_height - 64.0, 0.0)

	var slot_width = floorf((side_width - BATTLE_GRID_GAP * float(BATTLE_GRID_COLUMNS - 1)) / float(BATTLE_GRID_COLUMNS))
	var slot_height = floorf((side_height - BATTLE_GRID_GAP * float(BATTLE_GRID_ROWS - 1)) / float(BATTLE_GRID_ROWS))
	return Vector2(maxf(slot_width, MIN_SLOT_SIZE.x), maxf(slot_height, MIN_SLOT_SIZE.y))

func _on_damage_dealt(target: Dictionary, amount: int, is_crit: bool) -> void:
	var color = "red" if is_crit else "white"
	var crit_text = " [b]CRIT![/b]" if is_crit else ""
	log_label.append_text("[color=%s]%s took %d damage%s[/color]\n" % [color, target["display_name"], amount, crit_text])

func _on_battle_ended(result: String) -> void:
	log_label.append_text("\n[color=yellow][b]BATTLE OVER: %s[/b][/color]" % result.to_upper())

func _on_skill_cast(caster: Dictionary, skill: SkillData, targets: Array) -> void:
	# Find caster visual node
	var caster_ui = _find_combatant_ui(caster)
	if not caster_ui: return

	for target in targets:
		var target_ui = _find_combatant_ui(target)
		if not target_ui: continue

		# Spawn VFX
		var vfx = Node2D.new()
		vfx.set_script(load("res://scripts/ui/SkillVFX.gd"))
		add_child(vfx)
		vfx.launch_projectile(
			caster_ui.global_position + caster_ui.size/2,
			target_ui.global_position + target_ui.size/2,
			skill.type_color,
			skill.get_icon_texture()
		)

func _find_combatant_ui(data: Dictionary) -> Control:
	var grids = [hero_grid, enemy_grid]
	for grid in grids:
		for slot in grid.get_children():
			if slot.get_child_count() > 0:
				var ui = slot.get_child(0)
				if ui.combatant_data == data:
					return ui
	return null

func _populate_inventory() -> void:
	_refresh_party_buffs()
	_refresh_visible_hero_cards()

	# Clear existing children if any
	for child in inventory_grid.get_children():
		child.queue_free()

	# Populate based on RunState
	for skill in RunState.inventory:
		var panel = INVENTORY_SLOT.new()
		panel.setup(skill)
		inventory_grid.add_child(panel)

func _refresh_visible_hero_cards() -> void:
	for slot in hero_grid.get_children():
		if slot.get_child_count() == 0:
			continue
		var ui = slot.get_child(0)
		if ui.has_method("setup"):
			ui.setup(ui.combatant_data)
