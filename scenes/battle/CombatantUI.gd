extends Control

@onready var hp_bar: ProgressBar = $VBoxContainer/HPBar
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var color_rect: ColorRect = $VBoxContainer/ColorRect
@onready var skills_container: HBoxContainer = $VBoxContainer/SkillsContainer

var combatant_data: Dictionary

func _ready() -> void:
	# Ignore mouse input so drag-and-drop events bubble up to the BattleSlot
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Also disable for VBoxContainer's children
	for child in $VBoxContainer.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(data: Dictionary) -> void:
	combatant_data = data
	name_label.text = data["display_name"]
	color_rect.color = data["data"].placeholder_color
	
	hp_bar.max_value = data["max_hp"]
	hp_bar.value = data["current_hp"]
	
	# Populate skills UI
	for child in skills_container.get_children():
		child.queue_free()
		
	if data.has("skills"):
		for skill in data["skills"]:
			var skill_rect = ColorRect.new()
			skill_rect.custom_minimum_size = Vector2(14, 14)
			skill_rect.color = skill.type_color
			skill_rect.mouse_filter = Control.MOUSE_FILTER_STOP
			skill_rect.tooltip_text = "Left-click to unequip: " + skill.display_name
			
			skill_rect.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					_unequip_skill(skill)
			)
			skills_container.add_child(skill_rect)
	
	# Listen for global damage signals to update our bar
	# Ensure we don't connect multiple times if setup() is called again
	if not EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.connect(_on_damage_dealt)

func _unequip_skill(skill: Resource) -> void:
	# Prevent unequipping during active combat
	var scene = get_tree().current_scene
	if scene.has_node("BattleManager"):
		var bm = scene.get_node("BattleManager")
		if bm.get("_running"):
			return
			
	# Remove from hero's active skills and persistent RunState
	if combatant_data["skills"].has(skill):
		combatant_data["skills"].erase(skill)
		if combatant_data.has("party_index"):
			RunState.party[combatant_data["party_index"]]["skills"].erase(skill)
		
		# Return to inventory
		RunState.add_item(skill)
		
		# Refresh UI
		setup(combatant_data)
		if scene.has_method("_populate_inventory"):
			scene._populate_inventory()

func _on_damage_dealt(target: Dictionary, _amount: int, _is_crit: bool) -> void:
	# Only update if the damage was dealt to THIS unit
	if target == combatant_data:
		var tween = create_tween()
		tween.tween_property(hp_bar, "value", target["current_hp"], 0.2)
		
		# Shake effect
		var original_pos = position
		tween.parallel().tween_property(self, "position", original_pos + Vector2(5, 0), 0.05)
		tween.tween_property(self, "position", original_pos - Vector2(5, 0), 0.05)
		tween.tween_property(self, "position", original_pos, 0.05)

func mark_dead() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
