extends PanelContainer

@onready var icon: ColorRect = $Icon
@export var slot_id: int = 0

# 1. When the user starts dragging
func _get_drag_data(_at_position: Vector2) -> Variant:
	if not icon.visible:
		return null
		
	# Create a preview (what follows the mouse)
	var preview = ColorRect.new()
	preview.color = icon.color
	preview.custom_minimum_size = icon.size
	set_drag_preview(preview)
	
	# Hide our actual icon while dragging
	icon.visible = false
	
	# Return the data we are carrying
	return {"color": icon.color, "original_slot": self}

# 2. When the user hovers over a potential drop spot
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# We can drop if the data is a dictionary containing a color
	return data is Dictionary and data.has("color")

# 3. When the user releases the mouse
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	# If there was an item here, send it back to the original spot (Swap)
	if icon.visible:
		data["original_slot"].set_icon_color(icon.color)
	else:
		data["original_slot"].clear_icon()
		
	# Set our new color
	set_icon_color(data["color"])

func set_icon_color(new_color: Color) -> void:
	icon.color = new_color
	icon.visible = true

func clear_icon() -> void:
	icon.visible = false

# If the drag is cancelled (dropped in empty space)
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if not is_drag_successful():
			icon.visible = true
