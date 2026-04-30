# PURPOSE: TalentTree — UI for spending permanent currency on hero buffs.
extends Control

@onready var coin_label: Label = $Header/CoinLabel
@onready var talent_grid: GridContainer = $ScrollContainer/TalentGrid
@onready var back_button: Button = $Header/BackButton

# Define the talents available for purchase
var talents = [
	{
		"id": "hp_boost",
		"name": "Void Vitality",
		"desc": "+10 Max HP per level",
		"cost_base": 50,
		"cost_mult": 1.5,
		"max_level": 10
	},
	{
		"id": "atk_boost",
		"name": "Abyssal Strength",
		"desc": "+2 ATK per level",
		"cost_base": 75,
		"cost_mult": 1.6,
		"max_level": 10
	},
	{
		"id": "speed_boost",
		"name": "Echoing Haste",
		"desc": "+1 Speed per level",
		"cost_base": 150,
		"cost_mult": 2.0,
		"max_level": 5
	},
	{
		"id": "starting_gold",
		"name": "Bounty Hunter",
		"desc": "+20 Starting Gold per level",
		"cost_base": 100,
		"cost_mult": 1.4,
		"max_level": 10
	}
]

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_update_ui()

func _update_ui() -> void:
	coin_label.text = "Darkworld Coins: " + str(RunState.meta["darkworld_coins"])
	
	# Clear and rebuild the talent nodes
	for child in talent_grid.get_children():
		child.queue_free()
		
	for talent in talents:
		_create_talent_node(talent)

func _create_talent_node(talent: Dictionary) -> void:
	var current_level = RunState.meta["talent_points_spent"].get(talent["id"], 0)
	var cost = int(talent["cost_base"] * pow(talent["cost_mult"], current_level))
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 120)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = talent["name"] + " (Lv. " + str(current_level) + "/" + str(talent["max_level"]) + ")"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	var desc_label = Label.new()
	desc_label.text = talent["desc"]
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	
	var buy_button = Button.new()
	if current_level >= talent["max_level"]:
		buy_button.text = "MAXED"
		buy_button.disabled = true
	else:
		buy_button.text = "UPGRADE (%d Coins)" % cost
		buy_button.disabled = RunState.meta["darkworld_coins"] < cost
		
	buy_button.pressed.connect(func(): _on_buy_talent(talent, cost))
	vbox.add_child(buy_button)
	
	talent_grid.add_child(panel)

func _on_buy_talent(talent: Dictionary, cost: int) -> void:
	if RunState.meta["darkworld_coins"] >= cost:
		RunState.meta["darkworld_coins"] -= cost
		var current_level = RunState.meta["talent_points_spent"].get(talent["id"], 0)
		RunState.meta["talent_points_spent"][talent["id"]] = current_level + 1
		RunState.save_meta()
		_update_ui()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
