# PURPOSE: Review all skill illustrations in Godot and export a labelled contact sheet.
class_name SkillArtReview
extends Control

const CARD_SCENE = preload("res://scenes/battle/SkillCard.tscn")

func _ready() -> void:
	var capture_path = ""
	var contact_sheet = false
	var tier_review = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-sheet="):
			capture_path = argument.trim_prefix("--capture-sheet=")
			contact_sheet = true
		elif argument.begins_with("--capture-cards="):
			capture_path = argument.trim_prefix("--capture-cards=")
		elif argument.begins_with("--capture-tiers="):
			capture_path = argument.trim_prefix("--capture-tiers=")
			tier_review = true
	if contact_sheet:
		get_tree().root.content_scale_size = Vector2i(1440, 1280)
		get_tree().root.size = Vector2i(1440, 1280)
	if tier_review:
		get_tree().root.content_scale_size = Vector2i(960, 1040)
		get_tree().root.size = Vector2i(960, 1040)
		_build_tier_review()
	else:
		_build_gallery(contact_sheet)
	if not capture_path.is_empty():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image = get_viewport().get_texture().get_image()
		var error = image.save_png(capture_path)
		if error != OK:
			push_error("[SkillArtReview] Could not save contact sheet: " + str(error))
		get_tree().quit(0 if error == OK else 1)

func _build_tier_review() -> void:
	var background := ColorRect.new()
	background.color = Color("080c13")
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)
	var heading := Label.new()
	heading.text = "SKILL TYPES & TIERS"
	heading.add_theme_font_size_override("font_size", 26)
	layout.add_child(heading)
	var legend := Label.new()
	legend.text = "PHYSICAL / RED     ·     MAGIC / BLUE     ·     HEALING / GREEN"
	layout.add_child(legend)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 16)
	layout.add_child(grid)
	for tier in range(1, 4):
		for family in ["power_strike", "fireball", "heal"]:
			var id: String = family if tier == 1 else "%s_tier%d" % [family, tier]
			var card = CARD_SCENE.instantiate()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(card)
			card.setup(load("res://resources/skills/skill_%s.tres" % id))

func _build_gallery(contact_sheet: bool) -> void:
	var background = ColorRect.new()
	background.color = Color(0.018, 0.025, 0.04)
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin = MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var title = Label.new()
	title.text = "ABYSSAL ECHOES  /  SKILL ARTWORK"
	title.add_theme_font_size_override("font_size", 26)
	layout.add_child(title)
	var subtitle = Label.new()
	subtitle.text = "35 individual illustrations · All tiers and boss abilities" if contact_sheet else "35 individual illustrations · Hover a card for details · Scroll to see every skill"
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.73, 0.85))
	layout.add_child(subtitle)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 7 if contact_sheet else 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	var skills = GameData.skills.values()
	skills.sort_custom(func(a, b): return a.resource_path < b.resource_path)
	for skill in skills:
		if contact_sheet:
			_add_thumbnail(grid, skill)
		else:
			var card = CARD_SCENE.instantiate()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(card)
			card.setup(skill)
	if not contact_sheet:
		var back = Button.new()
		back.text = "BACK TO MAIN MENU"
		back.custom_minimum_size.y = 40
		back.pressed.connect(func(): EventBus.scene_change_requested.emit("res://scenes/MainMenu.tscn"))
		layout.add_child(back)

func _add_thumbnail(grid: GridContainer, skill: SkillData) -> void:
	var tile = VBoxContainer.new()
	tile.custom_minimum_size = Vector2(184, 196)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(tile)
	var icon = SkillIcon.new()
	icon.custom_minimum_size = Vector2(160, 160)
	tile.add_child(icon)
	icon.setup(skill)
	var title = Label.new()
	title.text = skill.display_name.replace(" (Tier III)", "")
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.add_child(title)
	var tier = Label.new()
	tier.text = "TIER %d · %s" % [skill.tier, skill.skill_type.to_upper()]
	tier.add_theme_font_size_override("font_size", 11)
	tier.add_theme_color_override("font_color", skill.type_color.lightened(0.4))
	tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.add_child(tier)
