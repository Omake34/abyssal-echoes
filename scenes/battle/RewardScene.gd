# PURPOSE: RewardScene — Displays loot after a battle and allows the player to choose a skill.
class_name RewardScene
extends Control

@onready var gold_label: Label = $Panel/VBoxContainer/GoldLabel
@onready var skill_container: HBoxContainer = $Panel/VBoxContainer/SkillOptions
@onready var continue_button: Button = $Panel/VBoxContainer/ContinueButton

var selected_skill: Resource = null

func _ready() -> void:
	# 1. Setup Visuals
	gold_label.text = "Gold Earned: " + str(RunState.run_stats["gold_earned"] - _get_previous_gold())
	continue_button.disabled = true
	continue_button.pressed.connect(_on_continue_pressed)
	
	# 2. Generate Skill Options
	_generate_skill_options()

func _get_previous_gold() -> int:
	# Simple way to show just what was earned this fight
	# In a real game, you'd pass this data in
	return 0 

func _generate_skill_options() -> void:
	# Pick 3 random skills
	var skill_paths = [
		"res://resources/skills/skill_slash.tres",
		"res://resources/skills/skill_fireball.tres",
		"res://resources/skills/skill_power_strike.tres",
		"res://resources/skills/skill_rally.tres",
		"res://resources/skills/skill_magic_bolt.tres"
	]
	
	skill_paths.shuffle()
	
	for i in range(3):
		var skill = load(skill_paths[i])
		var btn = Button.new()
		btn.text = skill.display_name + "\n" + skill.description
		btn.custom_minimum_size = Vector2(200, 150)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		skill_container.add_child(btn)
		
		btn.pressed.connect(func(): _on_skill_selected(skill, btn))

func _on_skill_selected(skill: Resource, btn: Button) -> void:
	selected_skill = skill
	continue_button.disabled = false
	
	# Highlight selected
	for child in skill_container.get_children():
		child.modulate = Color.WHITE
	btn.modulate = Color.GREEN

func _on_continue_pressed() -> void:
	if selected_skill:
		RunState.add_item(selected_skill)
	
	# Mark current node as completed
	if RunState.current_node_id != "":
		RunState.completed_node_ids.append(RunState.current_node_id)
	
	# Return to map
	EventBus.scene_change_requested.emit("res://scenes/map/MapView.tscn")
