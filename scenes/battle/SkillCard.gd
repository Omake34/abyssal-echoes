# PURPOSE: SkillCard - Flashcard-style skill display.
class_name SkillCard
extends Button

@onready var bg_panel: Panel = $BGPanel
@onready var desc_label: Label = $BackPanel/Margin/BackVBox/DescLabel
@onready var back_name_label: Label = $BackPanel/Margin/BackVBox/BackNameLabel
@onready var back_tier_label: Label = $BackPanel/Margin/BackVBox/BackTierLabel
@onready var type_strip: ColorRect = $TypeStrip
@onready var skill_icon: SkillIcon = $SkillIcon
@onready var front_info: VBoxContainer = $FrontInfo
@onready var name_label: Label = $FrontInfo/NameLabel
@onready var tier_label: Label = $FrontInfo/TierLabel
@onready var back_panel: Panel = $BackPanel

var skill_data: SkillData = null
var _hover_tween: Tween = null

func _ready() -> void:
	back_panel.visible = false
	back_panel.modulate.a = 0.0

func setup(data: SkillData) -> void:
	skill_data = data
	back_name_label.text = data.display_name
	back_tier_label.text = _get_tier_roman(data.tier)
	desc_label.text = data.description
	name_label.text = data.display_name
	tier_label.text = _get_tier_roman(data.tier)
	skill_icon.setup(data)
	
	var type_color = data.type_color
	type_strip.color = type_color
	type_strip.offset_bottom = 3.0 + float(data.tier) * 2.0
	bg_panel.add_theme_stylebox_override("panel", SkillVisualStyle.panel_style(data.skill_type, data.tier))
	back_panel.add_theme_stylebox_override("panel", SkillVisualStyle.panel_style(data.skill_type, data.tier))
	for label in [tier_label, back_tier_label]:
		label.label_settings = label.label_settings.duplicate()
		label.label_settings.font_color = type_color
		label.label_settings.font_size = 12 if data.tier == 1 else 13 if data.tier == 2 else 14

func _get_tier_roman(tier: int) -> String:
	return SkillVisualStyle.tier_label(tier)

func _on_mouse_entered() -> void:
	_set_back_visible(true)

func _on_mouse_exited() -> void:
	_set_back_visible(false)

func _set_back_visible(show_back: bool) -> void:
	if _hover_tween:
		_hover_tween.kill()
	
	back_panel.visible = true
	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.tween_property(self, "scale", Vector2(1.05, 1.05) if show_back else Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	_hover_tween.tween_property(skill_icon, "modulate:a", 0.18 if show_back else 1.0, 0.1)
	_hover_tween.tween_property(front_info, "modulate:a", 0.0 if show_back else 1.0, 0.1)
	_hover_tween.tween_property(back_panel, "modulate:a", 1.0 if show_back else 0.0, 0.12)
	_hover_tween.tween_property(self, "modulate", Color(1.08, 1.08, 1.08) if show_back else Color.WHITE, 0.12)
	
	if not show_back:
		_hover_tween.finished.connect(func(): back_panel.visible = false)
