class_name MapNode
extends PanelContainer

@onready var icon_rect: ColorRect = $VBoxContainer/IconRect
@onready var label: Label = $VBoxContainer/Label

var node_data: Dictionary
var node_status: String = "locked"

func setup(data: Dictionary) -> void:
	node_data = data
	label.text = data.get("name", "???")
	icon_rect.color = _get_type_color(data.get("type", "battle"))
	set_status("locked")

func set_status(status: String) -> void:
	node_status = status
	match status:
		"locked":
			modulate = Color(0.3, 0.3, 0.3)
			mouse_default_cursor_shape = Control.CURSOR_ARROW
		"available":
			modulate = Color.WHITE
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		"completed":
			modulate = Color(0.5, 1.0, 0.5)
			mouse_default_cursor_shape = Control.CURSOR_ARROW

func _gui_input(event: InputEvent) -> void:
	if node_status != "available":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		EventBus.map_node_selected.emit(node_data["id"])

func _get_type_color(type: String) -> Color:
	match type:
		"battle": return Color(0.7, 0.2, 0.2)
		"elite":  return Color(0.5, 0.1, 0.6)
		"boss":   return Color(0.9, 0.4, 0.0)
		"shop":   return Color(0.2, 0.6, 0.2)
		"rest":   return Color(0.1, 0.6, 0.6)
		"event":  return Color(0.8, 0.8, 0.2)
		"start":  return Color(0.3, 0.3, 0.8)
	return Color.WHITE
