# PURPOSE: Show a draggable illustrated skill card in the inventory.
class_name InventorySlot
extends PanelContainer

var skill_data: SkillData

func setup(data: SkillData) -> void:
	skill_data = data
	custom_minimum_size = Vector2(72, 104)
	tooltip_text = "%s\n%s\n\n(Right-click to sell for 5 Gold)" % [skill_data.display_name, skill_data.description]
	
	for child in get_children():
		child.queue_free()
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0, 0, 0, 0)
	add_theme_stylebox_override("panel", style)
	
	_add_card_contents(self, skill_data)

func _add_card_contents(parent: Control, skill: SkillData) -> void:
	var root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var skill_icon = SkillIcon.new()
	root.add_child(skill_icon)
	skill_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_icon.offset_bottom = -26.0
	skill_icon.setup(skill)
	
	var type_strip = ColorRect.new()
	type_strip.color = skill.type_color
	type_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(type_strip)
	type_strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	type_strip.offset_bottom = 3.0
	
	var title_scrim = ColorRect.new()
	title_scrim.color = Color(0, 0, 0, 0.48)
	title_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_scrim)
	title_scrim.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	title_scrim.offset_top = -30.0
	
	var label = Label.new()
	label.text = skill.display_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 11)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -30.0

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not skill_data:
		return null
	
	var preview = PanelContainer.new()
	preview.custom_minimum_size = custom_minimum_size
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0, 0, 0, 0)
	preview.add_theme_stylebox_override("panel", style)
	_add_card_contents(preview, skill_data)
	
	var c = Control.new()
	c.add_child(preview)
	preview.position = -preview.custom_minimum_size / 2
	set_drag_preview(c)
	
	modulate.a = 0.3
	return {"type": "skill", "skill_data": skill_data, "source_inventory_slot": self}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not skill_data:
			return
		
		var scene = get_tree().current_scene
		if scene.has_node("BattleManager"):
			var bm = scene.get_node("BattleManager")
			if bm.get("_running"):
				return
		
		RunState.salvage_item(skill_data)
		
		if scene.has_method("_populate_inventory"):
			scene._populate_inventory()
		if scene.has_method("_update_gold_display"):
			scene._update_gold_display()
