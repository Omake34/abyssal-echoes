# PURPOSE: RewardScene — Displays loot after a battle and allows the player to choose a skill.
class_name RewardScene
extends Control

@onready var gold_label: Label = $Panel/VBoxContainer/GoldLabel
@onready var skill_container: HBoxContainer = $Panel/VBoxContainer/SkillOptions
@onready var back_button: Button = $Panel/VBoxContainer/ButtonContainer/BackButton
@onready var continue_button: Button = $Panel/VBoxContainer/ButtonContainer/ContinueButton
@onready var bg_texture: TextureRect = $BackgroundArt
@onready var choose_label: Label = $Panel/VBoxContainer/ChooseLabel
@onready var reward_title: Label = $Panel/VBoxContainer/Title

const SKILL_CARD_SCENE = preload("res://scenes/battle/SkillCard.tscn")

var selected_skill: Resource = null
var _target_gold: int = 0
var _display_gold: int = 0
var _leaving: bool = false
var _skip_button: Button

func _ready() -> void:
	# 1. Setup Visuals
	var bg_tex = _load_png_texture("res://assets/ui/victory_bg.png")
	if bg_tex:
		bg_texture.texture = bg_tex
	
	# PURPOSE: Recover older treasure saves and reuse this node's stored reward choices.
	RunState.prepare_reward(RunState.current_node_id, RunState.pending_reward_gold)
	_target_gold = RunState.pending_reward_gold
	if RunState.get_current_node_data().get("type") == "treasure":
		reward_title.text = "TREASURE"
		back_button.visible = false
	gold_label.text = "Gold Earned: 0"
	continue_button.disabled = true
	continue_button.pressed.connect(_on_continue_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_skip_button = Button.new()
	_skip_button.text = "SKIP SKILL"
	_skip_button.tooltip_text = "Keep your gold and continue without taking a skill."
	_skip_button.custom_minimum_size = Vector2(140, 50)
	continue_button.get_parent().add_child(_skip_button)
	_skip_button.pressed.connect(func(): _finish_reward(null))
	
	# Animate background fade in
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	tween.finished.connect(_start_gold_animation)
	
	# 2. Generate Skill Options
	_generate_skill_options()

func _load_png_texture(path: String) -> Texture2D:
	var bytes = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var image = Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)

func _start_gold_animation() -> void:
	var tween = create_tween()
	tween.tween_method(func(val): 
		_display_gold = val
		gold_label.text = "Gold Earned: " + str(_display_gold)
	, 0, _target_gold, 1.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func _generate_skill_options() -> void:
	# Clear old
	for child in skill_container.get_children():
		child.queue_free()
		
	# Saved paths preserve the offer across team checks and game restarts.
	for path in RunState.pending_reward_options:
		if not ResourceLoader.exists(path):
			push_warning("[RewardScene] Missing reward resource: " + path)
			continue
		var skill = load(path)
		if skill == null:
			continue
		var card = SKILL_CARD_SCENE.instantiate()
		skill_container.add_child(card)
		card.setup(skill)
		
		card.pressed.connect(func(): _on_skill_selected(skill, card))
	if skill_container.get_child_count() == 0:
		choose_label.text = "No skills available. You can continue with Skip Skill."

func _on_skill_selected(skill: Resource, card: SkillCard) -> void:
	if _leaving:
		return
	selected_skill = skill
	continue_button.disabled = false
	
	# Highlight selected
	for child in skill_container.get_children():
		if child is SkillCard:
			child.bg_panel.modulate = Color.WHITE
	card.bg_panel.modulate = Color(0.5, 1.0, 0.5) # Soft Green glow

func _on_continue_pressed() -> void:
	if selected_skill != null:
		_finish_reward(selected_skill)

# PURPOSE: Commit one claim before the fade, or explain why the reward is still waiting.
func _finish_reward(skill: Resource) -> void:
	if _leaving:
		return
	if not RunState.claim_reward(skill):
		choose_label.text = "Inventory full. Check Team to make room, or Skip Skill." if back_button.visible else "Inventory full. Skip Skill to continue."
		return
	_leaving = true
	continue_button.disabled = true
	back_button.disabled = true
	_skip_button.disabled = true
	
	# Transition out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func(): 
		EventBus.scene_change_requested.emit("res://scenes/map/MapView.tscn")
	)

func _on_back_pressed() -> void:
	if _leaving:
		return
	# Go back to battle scene to check inventory
	EventBus.scene_change_requested.emit("res://scenes/battle/BattleScene.tscn")
