extends Control

@export var hero_resource: HeroData
@onready var info_label: Label = %InfoLabel

func _ready() -> void:
	if hero_resource:
		display_hero_info(hero_resource)
	else:
		info_label.text = "No resource loaded! Assign one in the inspector."

func display_hero_info(data: HeroData) -> void:
	var text = "Hero: %s (%s)\n" % [data.display_name, data.hero_class.capitalize()]
	text += "--- STATS ---\n"
	text += "HP: %d | ATK: %d\n" % [data.base_hp, data.base_atk]
	text += "DEF: %d | SPD: %d\n" % [data.base_def, data.base_speed]
	text += "--- TRAIT ---\n"
	text += "[%s]\n%s" % [data.trait_name, data.trait_description]
	
	info_label.text = text
	print("Loaded Hero: ", data.display_name)
