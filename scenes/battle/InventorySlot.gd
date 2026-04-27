class_name InventorySlot
extends PanelContainer

var skill_data: SkillData

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not skill_data:
		return null
		
	# Create a visual preview
	var preview = PanelContainer.new()
	preview.custom_minimum_size = custom_minimum_size
	
	var style = StyleBoxFlat.new()
	style.bg_color = skill_data.type_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color.WHITE
	preview.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = skill_data.display_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.add_child(label)
	
	var c = Control.new()
	c.add_child(preview)
	preview.position = -preview.custom_minimum_size / 2
	set_drag_preview(c)
	
	# Dim the original while dragging
	modulate.a = 0.3
	return {"type": "skill", "skill_data": skill_data, "source_inventory_slot": self}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not skill_data: return
		
		# Prevent selling during active battle
		var scene = get_tree().current_scene
		if scene.has_node("BattleManager"):
			var bm = scene.get_node("BattleManager")
			if bm.get("_running"):
				return
		
		RunState.salvage_item(skill_data)
		
		# Refresh UI
		if scene.has_method("_populate_inventory"):
			scene._populate_inventory()
		if scene.has_method("_update_gold_display"):
			scene._update_gold_display()
