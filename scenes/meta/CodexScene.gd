# PURPOSE: Browse discovered game data and inspect the shared skill illustrations.
extends Control

enum Tab { SKILLS, HEROES, ENEMIES }

@onready var grid: GridContainer = %GridContainer
@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name: Label = %ItemName
@onready var item_type: Label = %ItemType
@onready var item_desc: Label = %ItemDescription

@onready var skills_tab: Button = %SkillsTab
@onready var heroes_tab: Button = %HeroesTab
@onready var enemies_tab: Button = %EnemiesTab
@onready var back_button: Button = $MainLayout/Header/BackButton
@onready var skill_filters: HBoxContainer = %SkillFilters
@onready var filter_all: Button = %FilterAll
@onready var filter_t1: Button = %FilterT1
@onready var filter_t2: Button = %FilterT2
@onready var filter_t3: Button = %FilterT3

var current_tab: Tab = Tab.SKILLS
var current_tier_filter: int = 0 # 0 = All, 1 = T1, 2 = T2, 3 = T3
var all_skills: Array = []
var all_heroes: Array = []
var all_enemies: Array = []

func _ready() -> void:
	skills_tab.pressed.connect(_on_tab_pressed.bind(Tab.SKILLS))
	heroes_tab.pressed.connect(_on_tab_pressed.bind(Tab.HEROES))
	enemies_tab.pressed.connect(_on_tab_pressed.bind(Tab.ENEMIES))
	back_button.pressed.connect(_on_back_pressed)
	
	filter_all.pressed.connect(_on_filter_pressed.bind(0))
	filter_t1.pressed.connect(_on_filter_pressed.bind(1))
	filter_t2.pressed.connect(_on_filter_pressed.bind(2))
	filter_t3.pressed.connect(_on_filter_pressed.bind(3))
	
	_load_all_resources()
	_refresh_display()

func _load_all_resources() -> void:
	all_skills = _load_dir("res://resources/skills")
	all_heroes = _load_dir("res://resources/heroes")
	all_enemies = _load_dir("res://resources/enemies")

func _load_dir(path: String) -> Array:
	var list = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var res = load(path + "/" + file_name)
				if res:
					list.append(res)
			file_name = dir.get_next()
	return list

func _on_tab_pressed(tab: Tab) -> void:
	current_tab = tab
	
	skills_tab.button_pressed = (tab == Tab.SKILLS)
	heroes_tab.button_pressed = (tab == Tab.HEROES)
	enemies_tab.button_pressed = (tab == Tab.ENEMIES)
	skill_filters.visible = (tab == Tab.SKILLS)
	
	_refresh_display()

func _on_filter_pressed(tier: int) -> void:
	current_tier_filter = tier
	
	filter_all.button_pressed = (tier == 0)
	filter_t1.button_pressed = (tier == 1)
	filter_t2.button_pressed = (tier == 2)
	filter_t3.button_pressed = (tier == 3)
	
	_refresh_display()

func _refresh_display() -> void:
	for child in grid.get_children():
		child.queue_free()
	
	var items = []
	var discovered_ids = []
	
	match current_tab:
		Tab.SKILLS:
			if current_tier_filter > 0:
				items = all_skills.filter(func(s): return s.tier == current_tier_filter)
			else:
				items = all_skills
			discovered_ids = RunState.meta["discovered_skills"]
		Tab.HEROES:
			items = all_heroes
			discovered_ids = RunState.meta["discovered_heroes"]
		Tab.ENEMIES:
			items = all_enemies
			discovered_ids = RunState.meta["discovered_enemies"]
	
	for item in items:
		var is_discovered = discovered_ids.has(item.id) or (current_tab == Tab.SKILLS)
		_create_item_node(item, is_discovered)

func _create_item_node(item: Resource, is_discovered: bool) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(110, 85)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	if is_discovered:
		btn.text = _get_button_label(item)
		if item is SkillData:
			btn.icon = item.get_icon_texture()
			btn.expand_icon = true
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			btn.add_theme_constant_override("icon_max_width", 48)
		btn.tooltip_text = item.display_name
		btn.pressed.connect(_show_item_details.bind(item))
	else:
		btn.text = "?"
		btn.disabled = true
		btn.modulate = Color(0.3, 0.3, 0.3)
	
	grid.add_child(btn)


func _get_button_label(item: Resource) -> String:
	if item is SkillData:
		return "%s\nT%d" % [item.display_name, item.tier]
	return item.display_name

func _show_item_details(item: Resource) -> void:
	item_name.text = item.display_name
	_show_detail_visual(item)
	
	if item is SkillData:
		item_type.text = "Skill - " + item.skill_type.capitalize() + " - Tier " + str(item.tier)
		item_desc.text = item.description
	elif item is HeroData:
		item_type.text = "Hero - " + item.hero_class.capitalize()
		item_desc.text = "Base HP: %d\nBase ATK: %d\nBase Speed: %d" % [item.base_hp, item.base_atk, item.base_speed]
	elif item is EnemyData:
		item_type.text = "Enemy - " + item.enemy_type.capitalize()
		item_desc.text = "Base HP: %d\nBase ATK: %d\n%s" % [item.base_hp, item.base_atk, item.description]

func _show_detail_visual(item: Resource) -> void:
	item_icon.visible = false
	item_icon.texture = null
	
	if item is SkillData:
		item_icon.texture = item.get_icon_texture()
		item_icon.visible = item_icon.texture != null
		return
	
	var texture_path = ""
	if item is SkillData:
		texture_path = item.icon_path
	elif item is HeroData:
		texture_path = item.sprite_path
	elif item is EnemyData:
		texture_path = item.sprite_path
	
	if texture_path != "" and ResourceLoader.exists(texture_path):
		item_icon.texture = load(texture_path)
		item_icon.visible = true

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
