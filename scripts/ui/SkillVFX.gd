# PURPOSE: SkillVFX — Visual representation of a skill being cast.
# Can be a projectile moving from A to B, or an effect appearing on the target.

extends Node2D

func launch_projectile(from_pos: Vector2, to_pos: Vector2, color: Color, vfx_id: String = "", speed: float = 600.0) -> void:
	var model_view = load("res://scenes/ui/ModelView2D.tscn").instantiate()
	model_view.custom_minimum_size = Vector2(40, 40)
	model_view.position = from_pos - Vector2(20, 20)
	add_child(model_view)
	
	if vfx_id != "":
		model_view.load_model(vfx_id)
		model_view.set_color_tint(color)
	
	var dist = from_pos.distance_to(to_pos)
	var duration = dist / speed
	
	var tween = create_tween()
	tween.tween_property(model_view, "position", to_pos - Vector2(20, 20), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Add some rotation to the projectile
	tween.parallel().tween_property(model_view, "rotation", 6.28, duration)
	
	tween.tween_callback(model_view.queue_free)
	tween.tween_callback(queue_free)
