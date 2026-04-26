extends Control

@onready var hero_box: ColorRect = %HeroBox

func _on_animate_button_pressed() -> void:
	# Create a new tween
	var tween = create_tween()
	
	# Set the tween to run multiple animations in parallel
	tween.set_parallel(true)
	
	# 1. Slide to a random position
	var target_pos = Vector2(randf_range(100, 500), randf_range(100, 300))
	tween.tween_property(hero_box, "position", target_pos, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 2. Rotate 360 degrees
	tween.tween_property(hero_box, "rotation_degrees", 360.0, 0.6)
	
	# 3. Fade alpha to 0.2
	tween.tween_property(hero_box, "modulate:a", 0.2, 0.6)
	
	# When those are done, run a follow-up animation (sequential)
	tween.set_parallel(false)
	tween.tween_property(hero_box, "modulate:a", 1.0, 0.3)
	tween.tween_property(hero_box, "rotation_degrees", 0.0, 0.1)
