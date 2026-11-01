# PURPOSE: Display a skill's illustration consistently in cards, inventory, and equipment.
class_name SkillIcon
extends TextureRect

func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func setup(skill: SkillData) -> void:
	texture = skill.get_icon_texture()
	tooltip_text = "%s\n%s" % [skill.display_name, skill.description]
