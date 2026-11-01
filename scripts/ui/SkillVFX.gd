# PURPOSE: Carry the skill's own illustration from its caster to the target.
class_name SkillVFX
extends Node2D

@export var travel_speed: float = 600.0
@export var icon_size: float = 40.0

func launch_projectile(from_pos: Vector2, to_pos: Vector2, color: Color, skill_texture: Texture2D = null) -> void:
	var visual: Node2D
	if skill_texture != null:
		var sprite = Sprite2D.new()
		sprite.texture = skill_texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.scale = Vector2.ONE * icon_size / maxf(skill_texture.get_width(), 1.0)
		visual = sprite
	else:
		# A visible energy spark keeps combat readable if a future skill has no art yet.
		var spark = Polygon2D.new()
		spark.polygon = PackedVector2Array([Vector2(0, -8), Vector2(8, 0), Vector2(0, 8), Vector2(-8, 0)])
		spark.color = color
		visual = spark
	visual.position = from_pos
	add_child(visual)
	var duration = maxf(from_pos.distance_to(to_pos) / maxf(travel_speed, 1.0), 0.12)
	var tween = create_tween()
	tween.tween_property(visual, "position", to_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "modulate:a", 0.0, 0.12)
	tween.tween_callback(queue_free)
