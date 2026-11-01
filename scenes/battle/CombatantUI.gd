extends Control

@onready var hp_bar: ProgressBar = $VBoxContainer/HPBar
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var color_rect: ColorRect = $VBoxContainer/ColorRect
@onready var skills_container: HBoxContainer = $VBoxContainer/SkillsContainer

var combatant_data: Dictionary

const MIN_PORTRAIT_SIZE := 64
const MAX_PORTRAIT_SIZE := 128
const MIN_SKILL_ICON_SIZE := 20
const MAX_SKILL_ICON_SIZE := 32

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

	_apply_responsive_sizes()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_sizes()

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
			var skill_icon = SkillIcon.new()
			var icon_size = _skill_icon_size()
			skill_icon.custom_minimum_size = Vector2(icon_size, icon_size)
			skill_icon.mouse_filter = Control.MOUSE_FILTER_STOP
			skill_icon.tooltip_text = "Left-click to unequip: " + skill.display_name

			skills_container.add_child(skill_icon)
			skill_icon.setup(skill)
			skill_icon.tooltip_text = "Left-click to unequip: " + skill.display_name

			skill_icon.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					_unequip_skill(skill)
			)

	# Update Synergies
	if has_node("%SynergyLabel"):
		var label = get_node("%SynergyLabel")
		if data.has("active_synergies") and not data["active_synergies"].is_empty():
			var names = []
			for syn in data["active_synergies"]:
				names.append(syn["display_name"])
			label.text = ", ".join(names)
		else:
			label.text = ""

	# Listen for global signals
	if not EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.connect(_on_damage_dealt)
	if not EventBus.healing_applied.is_connected(_on_healing_applied):
		EventBus.healing_applied.connect(_on_healing_applied)
	if not EventBus.tick_processed.is_connected(_update_status_ui):
		EventBus.tick_processed.connect(_update_status_ui)

	_apply_responsive_sizes()

func _apply_responsive_sizes() -> void:
	if not is_node_ready():
		return

	var panel_size = Vector2(maxf(size.x, custom_minimum_size.x), maxf(size.y, custom_minimum_size.y))
	var portrait_size = clampi(int(minf(panel_size.x * 0.72, panel_size.y * 0.48)), MIN_PORTRAIT_SIZE, MAX_PORTRAIT_SIZE)
	color_rect.custom_minimum_size = Vector2(portrait_size, portrait_size)
	name_label.add_theme_font_size_override("font_size", clampi(int(panel_size.x / 10.0), 11, 15))
	hp_bar.custom_minimum_size = Vector2(0, clampi(int(panel_size.y / 13.0), 10, 16))

	var icon_size = _skill_icon_size()
	for child in skills_container.get_children():
		if child is Control:
			child.custom_minimum_size = Vector2(icon_size, icon_size)

func _skill_icon_size() -> int:
	var panel_size = Vector2(maxf(size.x, custom_minimum_size.x), maxf(size.y, custom_minimum_size.y))
	return clampi(int(minf(panel_size.x / 5.0, panel_size.y / 6.0)), MIN_SKILL_ICON_SIZE, MAX_SKILL_ICON_SIZE)

func _update_status_ui() -> void:
	if not is_instance_valid(self): return

	if has_node("%StatusLabel"):
		var label = get_node("%StatusLabel")
		if combatant_data.has("status_effects") and not combatant_data["status_effects"].is_empty():
			var texts = []
			for effect in combatant_data["status_effects"]:
				texts.append("%s(%d)" % [effect["type"].to_upper(), effect["duration_ticks"]])
			label.text = " ".join(texts)
		else:
			label.text = ""

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

func _on_damage_dealt(target: Dictionary, amount: int, is_crit: bool) -> void:
	if target == combatant_data:
		# Wait for projectile to arrive (approx 0.4s)
		await get_tree().create_timer(0.4).timeout

		# If unit was killed and removed before timer finished, abort
		if not is_instance_valid(self): return

		_spawn_floating_text(str(amount), Color.RED if not is_crit else Color.ORANGE_RED, is_crit)
		var tween = create_tween()
		tween.tween_property(hp_bar, "value", target["current_hp"], 0.2)

		# Shake & Flash
		var original_pos = position
		color_rect.modulate = Color(10, 10, 10)
		tween.parallel().tween_property(color_rect, "modulate", Color.WHITE, 0.2)
		tween.parallel().tween_property(self, "position", original_pos + Vector2(randf_range(-5, 5), randf_range(-5, 5)), 0.05)
		tween.tween_property(self, "position", original_pos, 0.05)

func _on_healing_applied(target: Dictionary, amount: int) -> void:
	if target == combatant_data:
		_spawn_floating_text("+" + str(amount), Color.GREEN)
		var tween = create_tween()
		tween.tween_property(hp_bar, "value", target["current_hp"], 0.2)
		color_rect.modulate = Color.GREEN
		tween.parallel().tween_property(color_rect, "modulate", Color.WHITE, 0.4)

func _spawn_floating_text(value: String, color: Color, is_crit: bool = false) -> void:
	var label = Label.new()
	label.set_script(load("res://scripts/ui/FloatingText.gd"))
	label.position = Vector2(0, -40)
	add_child(label)
	label.setup(value, color, is_crit)

func mark_dead() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
