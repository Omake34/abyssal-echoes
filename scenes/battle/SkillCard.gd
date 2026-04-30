# PURPOSE: SkillCard - Flashcard-style skill display.
class_name SkillCard
extends Button

@onready var bg_panel: Panel = $BGPanel
@onready var name_label: Label = $FrontInfo/Margin/FrontVBox/NameLabel
@onready var tier_label: Label = $FrontInfo/Margin/FrontVBox/TierLabel
@onready var desc_label: Label = $BackPanel/Margin/BackVBox/DescLabel
@onready var back_name_label: Label = $BackPanel/Margin/BackVBox/BackNameLabel
@onready var back_tier_label: Label = $BackPanel/Margin/BackVBox/BackTierLabel
@onready var type_strip: ColorRect = $TypeStrip
@onready var model_view = $ModelView2D
@onready var front_info: Control = $FrontInfo
@onready var back_panel: Panel = $BackPanel

var skill_data: SkillData = null
var _hover_tween: Tween = null

func _ready() -> void:
	back_panel.visible = false
	back_panel.modulate.a = 0.0

func setup(data: SkillData) -> void:
	skill_data = data
	name_label.text = data.display_name
	back_name_label.text = data.display_name
	tier_label.text = _get_tier_roman(data.tier)
	back_tier_label.text = _get_tier_roman(data.tier)
	desc_label.text = data.description
	
	if data.vfx_id != "":
		model_view.spin_enabled = false
		model_view.load_model(data.vfx_id)
		model_view.set_color_tint(data.type_color)
	
	var type_color = data.type_color
	type_strip.color = type_color
	
	if data.tier >= 3:
		_apply_master_glow(type_color)

func _get_tier_roman(tier: int) -> String:
	match tier:
		1: return "Tier I"
		2: return "Tier II"
		3: return "Tier III (Master)"
		4: return "EX"
	return "Tier " + str(tier)

func _apply_master_glow(color: Color) -> void:
	var style = bg_panel.get_theme_stylebox("panel").duplicate()
	if style is StyleBoxFlat:
		style.border_color = color
		style.shadow_color = color
		style.shadow_size = 10
		bg_panel.add_theme_stylebox_override("panel", style)

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
	_hover_tween.tween_property(front_info, "modulate:a", 0.0 if show_back else 1.0, 0.1)
	_hover_tween.tween_property(model_view, "modulate:a", 0.18 if show_back else 1.0, 0.1)
	_hover_tween.tween_property(back_panel, "modulate:a", 1.0 if show_back else 0.0, 0.12)
	_hover_tween.tween_property(self, "modulate", Color(1.08, 1.08, 1.08) if show_back else Color.WHITE, 0.12)
	
	if not show_back:
		_hover_tween.finished.connect(func(): back_panel.visible = false)
