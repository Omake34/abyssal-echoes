extends Control
## A reviewable combat slice, deliberately separate from saved-run encounters.

const BOARD_SCRIPT = preload("res://scenes/battle/ArenaBoard.gd")
const HERO_COLORS := [Color("cf9d68"), Color("79cba4"), Color("ab9ae8"), Color("eedaa0")]

var simulation := ArenaSimulation.new()
var board: ArenaBoard
var formation: Array = ArenaSimulation.DEFAULT_FORMATION.duplicate()
var loadouts: Array = []
var shelf_title: Label
var shelf_buttons := {}
var shelf_icons := {}
var tier_picker: OptionButton
var current_skill_tier := 1
var encounter_picker: OptionButton
var build_picker: OptionButton
var start_button: Button
var reset_button: Button
var pause_button: Button
var speed_button: Button
var status_label: Label
var instruction_label: Label
var footer_label: Label
var hero_cards: Array[Dictionary] = []
var paused := false
var playback_speed := 1.0
var accumulator := 0.0
var result_shown := false

func _ready() -> void:
	_build_interface()
	reset_trial()
	_capture_if_requested.call_deferred()

func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("080c13")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	var header_region := _fixed_region(layout, 58)
	header_region.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 1)
	header.add_child(titles)
	_label(titles, "ABYSSAL ECHOES  /  THE HOLLOW GATE", 12, Color("9d8c72"))
	_label(titles, "Arena Trial", 28, Color("f0dfbf"))
	var back := _button(header, "Main menu", func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	back.tooltip_text = "Return to the main menu. Your saved run is untouched by the trial."
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 10)
	var toolbar_region := _fixed_region(layout, 38)
	toolbar_region.add_child(toolbar)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	encounter_picker = OptionButton.new()
	encounter_picker.add_item("Encounter: The breach")
	encounter_picker.add_item("Encounter: Crossfire")
	encounter_picker.custom_minimum_size = Vector2(220, 38)
	toolbar.add_child(encounter_picker)
	encounter_picker.item_selected.connect(func(_index): reset_trial())
	build_picker = OptionButton.new()
	build_picker.add_item("Archer preset: Pierce")
	build_picker.add_item("Archer preset: Ember")
	build_picker.add_item("Archer: Custom")
	build_picker.custom_minimum_size = Vector2(220, 38)
	build_picker.tooltip_text = "Compare two attack patterns in the same encounter and formation."
	toolbar.add_child(build_picker)
	build_picker.item_selected.connect(_on_preset_selected)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	speed_button = _button(toolbar, "1×", _cycle_speed)
	speed_button.custom_minimum_size.x = 52
	pause_button = _button(toolbar, "Pause", toggle_pause)
	pause_button.custom_minimum_size.x = 82
	reset_button = _button(toolbar, "Reposition", reset_trial)
	reset_button.custom_minimum_size.x = 100
	start_button = _button(toolbar, "Begin battle", begin_battle)
	start_button.custom_minimum_size.x = 114
	start_button.add_theme_color_override("font_color", Color("89e5cf"))
	var guidance := HBoxContainer.new()
	var guidance_region := _fixed_region(layout, 24)
	guidance_region.add_child(guidance)
	guidance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	instruction_label = _label(guidance, "", 14, Color("aab6c7"))
	instruction_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clip_line(instruction_label)
	status_label = _label(guidance, "PREPARATION", 14, Color("d9b87a"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.custom_minimum_size.x = 180
	_clip_line(status_label)
	board = BOARD_SCRIPT.new()
	board.custom_minimum_size.y = 260
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var arena_row := HBoxContainer.new()
	arena_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena_row.add_theme_constant_override("separation", 12)
	layout.add_child(arena_row)
	arena_row.add_child(board)
	_build_skill_shelf(arena_row)
	board.selection_changed.connect(_select_hero)
	board.formation_changed.connect(func(): formation = simulation.formation())
	var party_row := HBoxContainer.new()
	party_row.add_theme_constant_override("separation", 10)
	var party_region := _fixed_region(layout, 176)
	party_region.add_child(party_row)
	party_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in range(4):
		_build_hero_card(party_row, i)
	var footer_region := _fixed_region(layout, 20)
	footer_label = _label(footer_region, "", 12, Color("8996a9"))
	footer_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clip_line(footer_label)

func _fixed_region(parent: Node, height: float) -> Control:
	# A plain Control isolates the surrounding layout from its contents' minimum size.
	var region := Control.new()
	region.custom_minimum_size.y = height
	region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	region.clip_contents = true
	parent.add_child(region)
	return region

func _panel_margin(panel: Control, horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, horizontal)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, vertical)
	return margin

func _clip_line(label: Label) -> void:
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.max_lines_visible = 1

func _build_hero_card(parent: Control, index: int) -> void:
	var panel := Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111925")
	style.set_border_width_all(1)
	style.border_color = Color("303947")
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_panel_margin(panel, 12, 8).add_child(column)
	var title := _button(column, "", func(): _select_hero(index))
	title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.flat = true
	title.custom_minimum_size.y = 24
	title.clip_text = true
	title.add_theme_color_override("font_color", HERO_COLORS[index])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 3)
	icons.custom_minimum_size = Vector2(138, 54)
	row.add_child(icons)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)
	var health := _label(details, "", 12, Color("d1d9e6"))
	_clip_line(health)
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 6
	bar.show_percentage = false
	details.add_child(bar)
	var fill := StyleBoxFlat.new()
	fill.bg_color = HERO_COLORS[index]
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	var charge_region := _fixed_region(column, 40)
	var charge := _label(charge_region, "", 12, Color("b7b2d5"))
	charge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	charge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	charge.max_lines_visible = 2
	charge.clip_text = true
	charge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var contribution := _label(column, "", 12, Color("8996a9"))
	_clip_line(contribution)
	hero_cards.append({"panel": panel, "title": title, "icons": icons, "health": health,
		"bar": bar, "charge": charge, "contribution": contribution})

func reset_trial() -> void:
	paused = false
	accumulator = 0.0
	result_shown = false
	simulation.setup(formation, encounter_picker.selected, build_picker.selected == 1, loadouts)
	formation = simulation.formation()
	loadouts = simulation.hero_loadouts()
	board.setup(simulation)
	start_button.disabled = false
	pause_button.disabled = true
	pause_button.text = "Pause"
	encounter_picker.disabled = false
	build_picker.disabled = false
	status_label.text = "PREPARATION"
	instruction_label.text = "Drag heroes onto teal cells to move them, or onto another hero to swap. You can also select a hero and click an empty cell."
	footer_label.text = "Select a hero to equip skills. Use Unequip in the shelf or beneath an equipped icon to remove it. Your saved run is untouched."
	_refresh_icons()
	_refresh_cards()
	_refresh_shelf()

func _refresh_icons() -> void:
	for i in range(hero_cards.size()):
		var unit := simulation.get_unit(i)
		var icons: HBoxContainer = hero_cards[i]["icons"]
		for child in icons.get_children():
			icons.remove_child(child)
			child.queue_free()
		var descriptions: Array[String] = []
		for ability in unit["abilities"]:
			var icon := Button.new()
			icon.custom_minimum_size = Vector2(44, 54)
			var locked := simulation.running or not simulation.result.is_empty()
			icon.disabled = locked
			icon.flat = true
			icon.tooltip_text = "%s · %s · %s\n%s\n%s" % [ability.display_name, SkillVisualStyle.category_name(ability.skill_type), SkillVisualStyle.tier_label(ability.tier), ability.description_for(unit), "Equipment locked during battle." if locked else "Click to unequip."]
			icon.pressed.connect(_remove_skill.bind(i, ability.id))
			icons.add_child(icon)
			var picture := SkillIcon.new()
			icon.add_child(picture)
			picture.position = Vector2(3, 1)
			picture.size = Vector2(38, 36)
			picture.setup(ability)
			var action := _label(icon, "EQUIPPED" if locked else "UNEQUIP", 9, Color("aebdca") if locked else Color("f0dfcf"))
			action.mouse_filter = Control.MOUSE_FILTER_IGNORE
			action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			action.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			action.offset_top = -15
			icon.set_meta("ability_id", ability.id)
			descriptions.append(ability.display_name + ": " + ability.description_for(unit))
		for empty_index in range(ArenaEquipment.MAX_SLOTS - unit["abilities"].size()):
			_add_empty_slot(icons)
		hero_cards[i]["panel"].tooltip_text = "\n\n".join(descriptions)

func _add_empty_slot(parent: HBoxContainer) -> void:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(44, 54)
	slot.flat = true
	slot.disabled = true
	slot.tooltip_text = "Empty skill slot"
	slot.set_meta("ability_id", "")
	parent.add_child(slot)
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.position = Vector2(3, 1)
	frame.size = Vector2(38, 36)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b121b")
	style.border_color = Color("2c3b4a")
	style.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", style)
	slot.add_child(frame)
	var plus := _label(frame, "+", 20, Color("344658"))
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var caption := _label(slot, "EMPTY", 9, Color("637184"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -15

func _build_skill_shelf(parent: Control) -> void:
	var panel := Panel.new()
	panel.custom_minimum_size.x = 226
	panel.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111925")
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_panel_margin(panel, 12, 10).add_child(column)
	shelf_title = _label(column, "", 15, Color("e1d3b8"))
	_clip_line(shelf_title)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 10)
	column.add_child(legend)
	for category in ["physical", "magic", "healing"]:
		_label(legend, SkillVisualStyle.category_name(category), 10, SkillVisualStyle.color_for(category))
	tier_picker = OptionButton.new()
	for tier in range(1, 4):
		tier_picker.add_item(SkillVisualStyle.tier_label(tier))
	column.add_child(tier_picker)
	tier_picker.item_selected.connect(func(index):
		current_skill_tier = index + 1
		_refresh_shelf())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	for id in ArenaEquipment.ABILITY_IDS:
		var button := _button(list, "", _toggle_shelf_skill.bind(id))
		button.custom_minimum_size.y = 44
		button.add_theme_font_size_override("font_size", 12)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		var picture := SkillIcon.new()
		button.add_child(picture)
		picture.position = Vector2(5, 5)
		picture.size = Vector2(34, 34)
		shelf_icons[id] = picture
		shelf_buttons[id] = button

func _refresh_shelf() -> void:
	var unit := simulation.get_unit(board.selected)
	if unit.is_empty():
		return
	shelf_title.text = "%s  ·  %d/%d" % [unit["name"], unit["abilities"].size(), ArenaEquipment.MAX_SLOTS]
	for id in shelf_buttons:
		var ability := ArenaEquipment.find_ability(ArenaEquipment.variant_id(id, current_skill_tier))
		var check := ArenaEquipment.can_equip(unit, ability)
		var button: Button = shelf_buttons[id]
		var locked: bool = simulation.running or not simulation.result.is_empty()
		var equipped := ArenaEquipment.has_ability(unit, ability.id)
		button.disabled = locked or (not equipped and not check["ok"])
		button.text = "%s  %s\n%s · %s" % [ability.display_name, SkillVisualStyle.roman(ability.tier), SkillVisualStyle.category_name(ability.skill_type), "Unequip" if equipped else "Equip"]
		button.tooltip_text = ability.description_for(unit) + "\n" + ("Reposition to change equipment." if locked else "Click to unequip from " + str(unit["name"]) if equipped else str(check["reason"]) if not check["ok"] else "Click to equip on " + str(unit["name"]))
		SkillVisualStyle.style_button(button, ability.skill_type, ability.tier)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.get_theme_stylebox(state).content_margin_left = 44
		shelf_icons[id].setup(ability)
		button.set_meta("ability_id", ability.id)

func _toggle_shelf_skill(family: String) -> void:
	var id := ArenaEquipment.variant_id(family, current_skill_tier)
	if ArenaEquipment.has_ability(simulation.get_unit(board.selected), id):
		_remove_skill(board.selected, id)
	else:
		equip_selected(id)

func equip_selected(id: String) -> void:
	var check := simulation.equip_ability(board.selected, id)
	if not check["ok"]:
		footer_label.text = check["reason"]
		return
	_equipment_changed()

func _remove_skill(uid: int, id: String) -> void:
	if simulation.remove_ability(uid, id):
		_equipment_changed()

func _equipment_changed() -> void:
	loadouts = simulation.hero_loadouts()
	build_picker.select(0 if loadouts[1] == ["pierce"] else 1 if loadouts[1] == ["ember_volley"] else 2)
	_refresh_icons()
	_refresh_cards()
	_refresh_shelf()

func _on_preset_selected(index: int) -> void:
	if index == 2:
		return
	loadouts = simulation.hero_loadouts()
	loadouts[1] = ["ember_volley"] if index == 1 else ["pierce"]
	reset_trial()

func begin_battle() -> void:
	if simulation.running or not simulation.result.is_empty():
		return
	formation = simulation.formation()
	board.cancel_drag()
	simulation.start()
	board.consume_events(simulation.take_events())
	start_button.disabled = true
	pause_button.disabled = false
	encounter_picker.disabled = true
	build_picker.disabled = true
	_refresh_icons()
	_refresh_shelf()
	instruction_label.text = "Watch movement and ability triggers. Select a hero card to see its range and current target."
	footer_label.text = ""

func toggle_pause() -> void:
	if not simulation.running:
		return
	paused = not paused
	pause_button.text = "Resume" if paused else "Pause"

func _cycle_speed() -> void:
	playback_speed = 1.0 if playback_speed >= 3.0 else playback_speed + 1.0
	speed_button.text = "%d×" % int(playback_speed)

func _select_hero(uid: int) -> void:
	board.selected = uid
	_refresh_cards()
	_refresh_shelf()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			_select_hero(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_instance_valid(board):
		return
	board.visuals_paused = paused
	board.playback_rate = playback_speed
	if simulation.running and not paused:
		accumulator += minf(delta, 0.25) * playback_speed
		while accumulator >= ArenaSimulation.STEP and simulation.running:
			accumulator -= ArenaSimulation.STEP
			simulation.step()
		var batch := simulation.take_events()
		board.consume_events(batch)
		for event in batch:
			if event.get("text", "") in ["Challenge", "Arcane Surge", "Mend", "Ember Volley"]:
				var source := simulation.get_unit(int(event["source"]))
				footer_label.text = "%s  ·  %s" % [source["name"], event["text"]]
	if simulation.running:
		status_label.text = "%s  %05.1fs" % ["PAUSED" if paused else "BATTLE", simulation.elapsed]
	elif not simulation.result.is_empty() and not result_shown:
		result_shown = true
		pause_button.disabled = true
		encounter_picker.disabled = false
		build_picker.disabled = false
		status_label.text = "%s  /  %.1fs" % [simulation.result.to_upper(), simulation.elapsed]
		instruction_label.text = "Reposition restores this formation, equipment, and all units. Try a different frontline or skill combination."
		footer_label.text = "Trial complete. Damage and healing below show effective output; shield reports damage actually absorbed."
		_refresh_icons()
		_refresh_shelf()
	_refresh_cards()

func _refresh_cards() -> void:
	for i in range(hero_cards.size()):
		var unit := simulation.get_unit(i)
		if unit.is_empty():
			continue
		var card: Dictionary = hero_cards[i]
		card["title"].text = "%d   %s%s" % [i + 1, unit["name"], "  ‹" if board.selected == i else ""]
		card["health"].text = "%d / %d HP%s" % [unit["hp"], unit["max_hp"], "  · FALLEN" if not unit["alive"] else ""]
		card["health"].tooltip_text = card["health"].text
		card["bar"].max_value = unit["max_hp"]
		card["bar"].value = unit["hp"]
		var progress: Array[String] = []
		for ability in unit["abilities"]:
			progress.append(ability.progress_text(unit))
		card["charge"].text = "   /   ".join(progress) if not progress.is_empty() else "Basic attacks only"
		card["charge"].tooltip_text = "\n".join(progress)
		card["contribution"].text = "Damage %d   Heal %d   Shield %d" % [unit["damage"], unit["healing"], unit["prevented"]]
		card["contribution"].tooltip_text = card["contribution"].text

func _button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 38
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _label(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _capture_if_requested() -> void:
	# Render with Godot's own viewport for repeatable visual review.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-arena="):
			var output_path := argument.trim_prefix("--capture-arena=")
			if OS.get_cmdline_user_args().has("--empty-loadouts"):
				loadouts = [[], [], [], []]
				reset_trial()
			elif OS.get_cmdline_user_args().has("--full-loadouts"):
				loadouts = [["challenge_tier3", "power_strike_tier3", "mend_tier3"],
					["pierce_tier3", "ember_volley_tier3", "power_strike_tier3"],
					["arcane_surge_tier3", "ember_volley_tier3", "mend_tier3"],
					["mend_tier3", "holy_aura_tier3", "challenge_tier3"]]
				reset_trial()
			if OS.get_cmdline_user_args().has("--battle"):
				begin_battle()
				for i in range(120):
					simulation.step()
				var recent := simulation.take_events().filter(func(event: Dictionary) -> bool:
					return event.get("time", -1.0) >= simulation.elapsed - 0.25)
				board.consume_events(recent)
				for unit in simulation.units:
					board.visual_positions[unit["uid"]] = Vector2(unit["cell"])
				paused = true
				pause_button.text = "Resume"
			for i in range(8):
				await get_tree().process_frame
			if OS.get_cmdline_user_args().has("--drag"):
				board._layout_board()
				var press := InputEventMouseButton.new()
				press.button_index = MOUSE_BUTTON_LEFT
				press.button_mask = MOUSE_BUTTON_MASK_LEFT
				press.pressed = true
				press.position = board.get_global_transform_with_canvas() * (board.cell_center(board.visual_positions[0]) - Vector2(0, 10))
				press.global_position = press.position
				get_viewport().notify_mouse_entered()
				get_viewport().push_input(press, true)
				var motion := InputEventMouseMotion.new()
				motion.button_mask = MOUSE_BUTTON_MASK_LEFT
				motion.position = board.get_global_transform_with_canvas() * board.cell_center(Vector2(simulation.units[2]["cell"]))
				motion.global_position = motion.position
				motion.relative = motion.position - press.position
				get_viewport().push_input(motion, true)
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var error := get_viewport().get_texture().get_image().save_png(output_path)
			print("ARENA CAPTURE: ", output_path, " result=", error)
			get_tree().quit(0 if error == OK else 1)
