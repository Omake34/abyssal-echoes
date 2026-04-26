extends Control

@onready var battle_manager: BattleManager = $BattleManager
@onready var hero_grid: GridContainer = $HBoxContainer/HeroSide/HeroGrid
@onready var enemy_grid: GridContainer = $HBoxContainer/EnemySide/EnemyGrid
@onready var log_label: RichTextLabel = $LogPanel/LogLabel

const COMBATANT_UI = preload("res://scenes/battle/CombatantUI.tscn")

func _ready() -> void:
	# 1. Setup our "Test" data
	_setup_test_run()
	
	# 2. Connect to signals
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.battle_ended.connect(_on_battle_ended)
	
	# 3. Start the battle!
	var enemies = [
		load("res://resources/enemies/slime.tres"),
		load("res://resources/enemies/slime.tres")
	]
	
	battle_manager.start_battle(RunState.party, enemies)
	
	# 4. Spawn visuals
	_spawn_visuals()

func _setup_test_run() -> void:
	if RunState.party.is_empty():
		RunState.add_hero_to_party(load("res://resources/heroes/warrior.tres"))
		RunState.add_hero_to_party(load("res://resources/heroes/archer.tres"))

func _spawn_visuals() -> void:
	for hero in battle_manager.heroes:
		var ui = COMBATANT_UI.instantiate()
		hero_grid.add_child(ui)
		ui.setup(hero)
		
	for enemy in battle_manager.enemies:
		var ui = COMBATANT_UI.instantiate()
		enemy_grid.add_child(ui)
		ui.setup(enemy)

func _on_damage_dealt(target: Dictionary, amount: int, is_crit: bool) -> void:
	var color = "red" if is_crit else "white"
	var crit_text = " [b]CRIT![/b]" if is_crit else ""
	log_label.append_text("[color=%s]%s took %d damage%s[/color]\n" % [color, target["display_name"], amount, crit_text])

func _on_battle_ended(result: String) -> void:
	log_label.append_text("\n[color=yellow][b]BATTLE OVER: %s[/b][/color]" % result.to_upper())
