extends Control

@onready var hero_options_container: HBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/HeroOptions
@onready var instruction_label: Label = $MarginContainer/VBoxContainer/Instruction
@onready var start_button: Button = $MarginContainer/VBoxContainer/StartButton
@onready var back_button: Button = $BackButton

var selected_heroes: Array[HeroData] = []
var max_party_size: int = 4

var hero_pool: Array[String] = []

func _ready() -> void:
	hero_options_container.alignment = BoxContainer.ALIGNMENT_CENTER
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_scan_hero_resources()
	_setup_hero_options()
	_update_ui()


func _scan_hero_resources() -> void:
	hero_pool.clear()
	# Use GameData instead of scanning the directory manually
	for hero in GameData.heroes.values():
		hero_pool.append(hero.resource_path)
	# Sort by ID for consistent display
	hero_pool.sort()

func _setup_hero_options() -> void:
	# Clear existing if any
	for child in hero_options_container.get_children():
		child.queue_free()
		
	for path in hero_pool:
		var hero = load(path)
		if not hero: continue
		var card = _create_hero_card(hero)
		hero_options_container.add_child(card)

func _create_hero_card(hero: HeroData) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(210, 360)
	
	var is_unlocked = hero.unlocked_by_default or RunState.meta["unlocked_heroes"].has(hero.id)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 1) if is_unlocked else Color(0.08, 0.08, 0.1, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.25, 0.25, 0.35, 1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	card.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	
	# Icon/Color placeholder
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(0, 120)
	icon.color = hero.placeholder_color if is_unlocked else Color(0.2, 0.2, 0.2, 1)
	vbox.add_child(icon)
	
	# Name
	var name_label = Label.new()
	name_label.text = hero.display_name if is_unlocked else "???"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_label)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = hero.description if is_unlocked else "Unlock Condition:\n" + hero.unlock_condition
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.clip_text = true
	vbox.add_child(desc_label)
	
	if is_unlocked:
		# Select Button
		var btn = Button.new()
		btn.text = "SELECT"
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(0, 40)
		vbox.add_child(btn)
		btn.toggled.connect(func(is_pressed): _on_hero_toggled(hero, is_pressed, card, btn))
	else:
		# Unlock Button
		var btn = Button.new()
		var cost = 100 # Standard cost for now
		btn.text = "UNLOCK (100 Coins)"
		btn.custom_minimum_size = Vector2(0, 40)
		var can_afford = RunState.meta["darkworld_coins"] >= cost
		btn.disabled = not can_afford
		vbox.add_child(btn)
		
		btn.pressed.connect(func(): _on_unlock_pressed(hero, cost))
	
	return card

func _on_unlock_pressed(hero: HeroData, cost: int) -> void:
	if RunState.meta["darkworld_coins"] >= cost:
		RunState.meta["darkworld_coins"] -= cost
		RunState.unlock_hero(hero.id)
		# Refresh the UI
		_setup_hero_options()
		_update_ui()

func _on_hero_toggled(hero: HeroData, is_pressed: bool, card: PanelContainer, btn: Button) -> void:
	if is_pressed:
		if selected_heroes.size() >= max_party_size:
			btn.set_pressed_no_signal(false)
			return
		selected_heroes.append(hero)
		card.get_theme_stylebox("panel").border_color = Color(1, 0.84, 0) # Gold
		btn.text = "SELECTED"
	else:
		selected_heroes.erase(hero)
		card.get_theme_stylebox("panel").border_color = Color(0.25, 0.25, 0.35, 1)
		btn.text = "SELECT"
	
	_update_ui()

func _update_ui() -> void:
	instruction_label.text = "Choose %d heroes to begin the journey (%d/%d)" % [max_party_size, selected_heroes.size(), max_party_size]
	start_button.disabled = selected_heroes.size() != max_party_size
	
	if has_node("%CoinsLabel"):
		get_node("%CoinsLabel").text = "Darkworld Coins: " + str(int(RunState.meta["darkworld_coins"]))
	
func _on_start_pressed() -> void:
	RunState.start_new_run()
	for i in range(selected_heroes.size()):
		var hero = selected_heroes[i]
		RunState.add_hero_to_party(hero)
		# Assign initial sequential slots
		RunState.party[i]["slot_index"] = i
	
	EventBus.scene_change_requested.emit("res://scenes/map/MapView.tscn")

func _on_back_pressed() -> void:
	RunState.run_active = false
	RunState.delete_save()
	EventBus.scene_change_requested.emit("res://scenes/MainMenu.tscn")
