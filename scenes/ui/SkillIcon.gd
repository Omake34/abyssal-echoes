# PURPOSE: Display a skill's illustration consistently in cards, inventory, and equipment.
class_name SkillIcon
extends TextureRect

var skill_tier := 1
var category := "physical"

func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)

func setup(skill: Resource) -> void:
	texture = skill.get_icon_texture()
	skill_tier = skill.tier
	category = skill.skill_type
	var description: String = skill.description if skill is SkillData else skill.description_for()
	tooltip_text = "%s · %s · %s\n%s" % [skill.display_name, SkillVisualStyle.category_name(category), SkillVisualStyle.tier_label(skill_tier), description]
	queue_redraw()

func _draw() -> void:
	if texture == null or size.x < 12 or size.y < 12:
		return
	var color := SkillVisualStyle.color_for(category)
	var rank := clampi(skill_tier, 1, 3)
	var width := float(rank + 1)
	draw_rect(Rect2(Vector2.ZERO, size).grow(-width * 0.5), color, false, width)
	if rank >= 2:
		draw_rect(Rect2(Vector2.ZERO, size).grow(-5), Color(color, 0.75), false, 1)
	if rank >= 3:
		for point in [Vector2(7, 7), Vector2(size.x - 7, 7), Vector2(7, size.y - 7), size - Vector2(7, 7)]:
			draw_colored_polygon(PackedVector2Array([point + Vector2(0, -4), point + Vector2(4, 0), point + Vector2(0, 4), point + Vector2(-4, 0)]), color.lightened(0.25))
	var font_size := 11 if size.x < 60 else 15
	var badge_width := 10.0 + ThemeDB.fallback_font.get_string_size(SkillVisualStyle.roman(skill_tier), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var badge := Rect2(Vector2(size.x - badge_width - 3, 3), Vector2(badge_width, font_size + 7))
	draw_rect(badge, Color("07101b"))
	draw_rect(badge, color, false, 1)
	draw_string(ThemeDB.fallback_font, badge.position + Vector2(5, font_size + 1), SkillVisualStyle.roman(skill_tier), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color.lightened(0.2))
	var gap := 6.0 if size.x < 60 else 9.0
	for i in range(rank):
		var at := Vector2(size.x * 0.5 + (float(i) - float(rank - 1) * 0.5) * gap, size.y - 5)
		draw_circle(at, 2.0 if size.x < 60 else 3.0, Color("07101b"))
		draw_circle(at, 1.4 if size.x < 60 else 2.0, color)
