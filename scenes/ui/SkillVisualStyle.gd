class_name SkillVisualStyle
extends RefCounted
## Type owns color; tier owns frame weight and rank marks.

const PHYSICAL := Color("f16d73")
const MAGIC := Color("6faeff")
const HEALING := Color("66dba2")

static func color_for(category: String) -> Color:
	match category:
		"physical": return PHYSICAL
		"magic": return MAGIC
		"healing", "support": return HEALING
	return Color("d6dce5")

static func category_name(category: String) -> String:
	return "Healing" if category == "support" else category.capitalize()

static func roman(tier: int) -> String:
	return ["I", "II", "III", "EX"][clampi(tier, 1, 4) - 1]

static func tier_label(tier: int) -> String:
	match tier:
		1: return "TIER I · BASIC"
		2: return "TIER II · ADVANCED"
		3: return "TIER III · MASTER"
	return "EX"

static func panel_style(category: String, tier: int, hover: bool = false) -> StyleBoxFlat:
	var color := color_for(category)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0e1520").lerp(color, 0.14 if hover else 0.05 + 0.025 * tier)
	style.border_color = color.lightened(0.15) if hover else Color(color, 0.65 + 0.1 * mini(tier, 3))
	style.set_border_width_all(clampi(tier, 1, 3))
	style.set_corner_radius_all(6)
	style.shadow_color = Color(color, 0.18 if tier >= 3 else 0.08)
	style.shadow_size = 7 if tier >= 3 else 3 if tier == 2 else 0
	return style

static func style_button(button: Button, category: String, tier: int) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := panel_style(category, tier, state in ["hover", "focus"])
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", color_for(category).lightened(0.12))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("84909e"))
