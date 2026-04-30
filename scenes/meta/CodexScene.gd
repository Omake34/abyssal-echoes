extends Control

enum Tab { SKILLS, HEROES, ENEMIES }

const MODEL_VIEW_SCENE = preload("res://scenes/ui/ModelView2D.tscn")

@onready var grid: GridContainer = %GridContainer
@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name: Label = %ItemName
@onready var item_type: Label = %ItemType
@onready var item_desc: Label = %ItemDescription

@onready var skills_tab: Button = %SkillsTab
@onready var heroes_tab: Button = %HeroesTab
@onready var enemies_tab: Button = %EnemiesTab
@onready var back_button: Button = $MainLayout/Header/BackButton

var current_tab: Tab = Tab.SKILLS
var all_skills: Array = []
var all_heroes: Array = []
var all_enemies: Array = []
var item_model_view = null

func _ready() -> void:
	_setup_model_preview()
	
	skills_tab.pressed.connect(_on_tab_pressed.bind(Tab.SKILLS))
	heroes_tab.pressed.connect(_on_tab_pressed.bind(Tab.HEROES))
	enemies_tab.pressed.connect(_on_tab_pressed.bind(Tab.ENEMIES))
	back_button.pressed.connect(_on_back_pressed)
	
	_load_all_resources()
	_refresh_display()

func _setup_model_preview() -> void:
	item_model_view = MODEL_VIEW_SCENE.instantiate()
	item_model_view.custom_minimum_size = Vector2(256, 320)
	item_model_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	item_model_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_model_view.visible = false
	
	var visual_parent = item_icon.get_parent()
	visual_parent.add_child(item_model_view)
	visual_parent.move_child(item_model_view, item_icon.get_index())

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
	
	_refresh_display()

func _refresh_display() -> void:
	for child in grid.get_children():
		child.queue_free()
	
	var items = []
	var discovered_ids = []
	
	match current_tab:
		Tab.SKILLS:
			items = all_skills
			discovered_ids = RunState.meta["discovered_skills"]
		Tab.HEROES:
			items = all_heroes
			discovered_ids = RunState.meta["discovered_heroes"]
		Tab.ENEMIES:
			items = all_enemies
			discovered_ids = RunState.meta["discovered_enemies"]
	
	for item in items:
		var is_discovered = discovered_ids.has(item.id)
		_create_item_node(item, is_discovered)

func _create_item_node(item: Resource, is_discovered: bool) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(100, 80)
	
	if is_discovered:
		btn.text = _get_button_label(item)
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
	item_model_view.visible = false
	
	if item is SkillData and item.vfx_id != "":
		item_model_view.visible = true
		item_model_view.load_model(item.vfx_id)
		item_model_view.set_color_tint(item.type_color)
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
