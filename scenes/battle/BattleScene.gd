extends Control

@onready var battle_manager: BattleManager = $BattleManager
@onready var hero_grid: GridContainer = $HBoxContainer/HeroSide/HeroGrid
@onready var enemy_grid: GridContainer = $HBoxContainer/EnemySide/EnemyGrid
@onready var log_label: RichTextLabel = $LogPanel/LogLabel

@onready var prep_ui: VBoxContainer = $HBoxContainer/PreparationUI
@onready var start_button: Button = $HBoxContainer/PreparationUI/StartBattleButton
@onready var inventory_panel: Panel = $InventoryPanel
@onready var inventory_grid: Container = $InventoryPanel/VBoxContainer/ScrollContainer/InventoryGrid
@onready var log_panel: Panel = $LogPanel
@onready var skip_button: Button = $SkipButton

const COMBATANT_UI = preload("res://scenes/battle/CombatantUI.tscn")
const BATTLE_SLOT  = preload("res://scenes/battle/BattleSlot.gd")
const INVENTORY_SLOT = preload("res://scenes/battle/InventorySlot.gd")

func _ready() -> void:
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
	
	# 6. Add Auto-Equip Button to Prep UI
	var auto_button = Button.new()
	auto_button.text = "AUTO-EQUIP SKILLS"
	auto_button.custom_minimum_size = Vector2(0, 40)
	prep_ui.add_child(auto_button)
	# Move it above the start button for better flow
	prep_ui.move_child(auto_button, start_button.get_index())
	auto_button.pressed.connect(_on_auto_equip_pressed)

func _on_auto_equip_pressed() -> void:
	RunState.auto_equip_skills()
	# Refresh visuals
	for slot in hero_grid.get_children():
		for child in slot.get_children():
			child.queue_free()
	
	# Re-spawn heroes (sequential loop is fine now since slot_index is saved)
	for i in range(battle_manager.heroes.size()):
		var hero = battle_manager.heroes[i]
		# Find the updated hero data from RunState (the live BM copy needs syncing)
		var rs_hero = RunState.party[hero["party_index"]]
		hero["skills"] = rs_hero["skills"].duplicate()
		
		var ui = COMBATANT_UI.instantiate()
		var s_idx = hero.get("slot_index", i)
		var target_slot = hero_grid.get_child(s_idx)
		target_slot.add_child(ui)
		ui.setup(hero)
		
	_populate_inventory()

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
	# 1. Create 6 slots (3 columns x 2 rows) for Heroes
	for i in range(6):
		var slot = BATTLE_SLOT.new()
		slot.slot_index = i
		slot.is_hero_side = true
		hero_grid.add_child(slot)
		
	# 2. Create 6 slots for Enemies
	for i in range(6):
		var slot = BATTLE_SLOT.new()
		slot.slot_index = i
		slot.is_hero_side = false
		enemy_grid.add_child(slot)
	
	# 3. Add heroes to their specific slots
	for i in range(battle_manager.heroes.size()):
		var hero = battle_manager.heroes[i]
		var ui = COMBATANT_UI.instantiate()
		# Use saved slot_index, or fallback to i if missing (old saves)
		var s_idx = hero.get("slot_index", i)
		var target_slot = hero_grid.get_child(s_idx)
		target_slot.add_child(ui)
		ui.setup(hero)
		
	# 4. Add enemies to their slots (sequentially)
	for i in range(battle_manager.enemies.size()):
		var enemy = battle_manager.enemies[i]
		var ui = COMBATANT_UI.instantiate()
		var target_slot = enemy_grid.get_child(i)
		target_slot.add_child(ui)
		ui.setup(enemy)

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
			skill.vfx_id
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
	# Clear existing children if any
	for child in inventory_grid.get_children():
		child.queue_free()
		
	# Populate based on RunState
	for skill in RunState.inventory:
		var panel = INVENTORY_SLOT.new()
		panel.setup(skill)
		inventory_grid.add_child(panel)
