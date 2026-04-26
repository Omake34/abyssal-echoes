extends PanelContainer

## Emitted when the player clicks this node
signal selected(node_data: Dictionary)

enum NodeType { BATTLE, ELITE, SHOP, REST, TREASURE, BOSS }
enum NodeStatus { LOCKED, AVAILABLE, COMPLETED }

@onready var label: Label = $VBoxContainer/Label
@onready var type_icon: ColorRect = $VBoxContainer/Icon

var node_data: Dictionary
var status: NodeStatus = NodeStatus.LOCKED

func setup(data: Dictionary) -> void:
	node_data = data
	label.text = data["name"]
	_update_visuals()

func set_status(new_status: NodeStatus) -> void:
	status = new_status
	_update_visuals()

func _update_visuals() -> void:
	match status:
		NodeStatus.LOCKED:
			modulate = Color(0.3, 0.3, 0.3)
			mouse_default_cursor_shape = Control.CURSOR_ARROW
		NodeStatus.AVAILABLE:
			modulate = Color.WHITE
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		NodeStatus.COMPLETED:
			modulate = Color(0.5, 1.0, 0.5)
			mouse_default_cursor_shape = Control.CURSOR_ARROW

func _on_gui_input(event: InputEvent) -> void:
	if status == NodeStatus.AVAILABLE and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			selected.emit(node_data)
			# Notify the global EventBus too
			EventBus.map_node_selected.emit(node_data["id"])
