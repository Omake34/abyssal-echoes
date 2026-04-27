class_name BattleSlot
extends PanelContainer

var slot_index: int = 0
var is_hero_side: bool = true

func _ready() -> void:
	custom_minimum_size = Vector2(100, 120)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.4, 1)
	add_theme_stylebox_override("panel", style)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if get_child_count() == 0 or not is_hero_side:
		return null
	var combatant_ui = get_child(0)
	
	# Create a visual preview
	var preview = combatant_ui.duplicate()
	preview.modulate.a = 0.8
	var c = Control.new()
	c.add_child(preview)
	# Center preview on mouse
	preview.position = -preview.custom_minimum_size / 2
	set_drag_preview(c)
	
	# Dim the original while dragging
	combatant_ui.modulate.a = 0.3
	return {"source_slot": self, "combatant_ui": combatant_ui}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not is_hero_side or not data is Dictionary:
		return false
		
	# Allow dropping heroes (swapping slots)
	if data.has("source_slot"):
		return true
		
	# Allow dropping skills from inventory (only if this slot has a hero)
	if data.has("type") and data["type"] == "skill":
		return get_child_count() > 0
		
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data.has("source_slot"):
		# Hero Swap Logic
		var source_slot = data["source_slot"]
		var combatant_ui = data["combatant_ui"]
		combatant_ui.modulate.a = 1.0
		
		if get_child_count() > 0:
			var my_combatant = get_child(0)
			remove_child(my_combatant)
			source_slot.add_child(my_combatant)
		
		source_slot.remove_child(combatant_ui)
		add_child(combatant_ui)
		
	elif data.has("type") and data["type"] == "skill":
		# Skill Equip Logic
		var combatant_ui = get_child(0)
		var hero = combatant_ui.combatant_data
		var skill = data["skill_data"]
		
		# Only equip if they have less than 3 skills
		if hero["skills"].size() < RunState.MAX_SKILLS_PER_HERO:
			hero["skills"].append(skill)
			RunState.party[hero["party_index"]]["skills"].append(skill)
			RunState.remove_item(skill)
			
			# Re-setup the UI so it shows the new skill
			combatant_ui.setup(hero)
			
			# Ask the BattleScene to refresh the inventory panel
			# We can use a group call or find the parent
			var scene = get_tree().current_scene
			if scene.has_method("_populate_inventory"):
				scene._populate_inventory()
			
			# Restore the dragged item's alpha in case we're fast (it gets queue_freed anyway)
			var source = data.get("source_inventory_slot")
			if is_instance_valid(source):
				source.modulate.a = 1.0

func _notification(what: int) -> void:
	# If drag ended without dropping on a valid target, restore alpha
	if what == NOTIFICATION_DRAG_END:
		if get_child_count() > 0:
			get_child(0).modulate.a = 1.0
