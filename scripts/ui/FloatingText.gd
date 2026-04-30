# PURPOSE: FloatingText — A small label that pops up, floats, and fades away.
# Used for damage numbers, healing, and status announcements.

extends Label

func setup(value: String, color: Color = Color.WHITE, is_crit: bool = false) -> void:
	text = value
	add_theme_color_override("font_color", color)
	
	if is_crit:
		text = "CRIT! " + text
		add_theme_font_size_override("font_size", 32)
	else:
		add_theme_font_size_override("font_size", 24)
		
	# Animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Float up
	tween.tween_property(self, "position:y", position.y - 80, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.8).set_delay(0.2)
	
	# Finish
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
