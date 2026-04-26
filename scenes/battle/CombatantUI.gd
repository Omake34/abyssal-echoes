extends Control

@onready var hp_bar: ProgressBar = $VBoxContainer/HPBar
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var color_rect: ColorRect = $VBoxContainer/ColorRect

var combatant_data: Dictionary

func setup(data: Dictionary) -> void:
	combatant_data = data
	name_label.text = data["display_name"]
	color_rect.color = data["data"].placeholder_color
	
	hp_bar.max_value = data["max_hp"]
	hp_bar.value = data["current_hp"]
	
	# Listen for global damage signals to update our bar
	EventBus.damage_dealt.connect(_on_damage_dealt)

func _on_damage_dealt(target: Dictionary, _amount: int, _is_crit: bool) -> void:
	# Only update if the damage was dealt to THIS unit
	if target == combatant_data:
		var tween = create_tween()
		tween.tween_property(hp_bar, "value", target["current_hp"], 0.2)
		
		# Shake effect
		var original_pos = position
		tween.parallel().tween_property(self, "position", original_pos + Vector2(5, 0), 0.05)
		tween.tween_property(self, "position", original_pos - Vector2(5, 0), 0.05)
		tween.tween_property(self, "position", original_pos, 0.05)

func mark_dead() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
