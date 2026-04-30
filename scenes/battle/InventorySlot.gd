class_name InventorySlot
extends PanelContainer

const MODEL_VIEW_SCENE = preload("res://scenes/ui/ModelView2D.tscn")

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
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(root)
	
	var model_view = MODEL_VIEW_SCENE.instantiate()
	model_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	model_view.fill_ratio = 1.0
	model_view.spin_enabled = false
	model_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(model_view)
	
	if skill.vfx_id != "":
		model_view.load_model(skill.vfx_id)
		model_view.set_color_tint(skill.type_color)
	
	var type_strip = ColorRect.new()
	type_strip.color = skill.type_color
	type_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	type_strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	type_strip.size.y = 3.0
	root.add_child(type_strip)
	
	var title_scrim = ColorRect.new()
	title_scrim.color = Color(0, 0, 0, 0.48)
	title_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_scrim.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	title_scrim.position.y = -30.0
	title_scrim.size.y = 30.0
	root.add_child(title_scrim)
	
	var label = Label.new()
	label.text = skill.display_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 11)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.position.y = -30.0
	label.size.y = 30.0
	root.add_child(label)

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
