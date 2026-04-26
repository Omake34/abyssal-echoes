# PURPOSE: MapView — Handles the visual representation of the procedural map.
# It spawns MapNode scenes and draws connection lines.
class_name MapView
extends Control

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var map_container: Control = $ScrollContainer/MapContainer
@onready var lines_container: Control = $ScrollContainer/MapContainer/Lines

const MAP_NODE_SCENE = preload("res://scenes/map/MapNode.tscn")
const X_SPACING: int = 200
const Y_SPACING: int = 150

func _ready() -> void:
	# 1. Ensure we have map data
	if RunState.current_map.is_empty():
		var generator = MapGenerator.new()
		RunState.current_map = generator.generate_map()
	
	# 2. Render the map
	_render_map()

func _render_map() -> void:
	# Clear existing (if any)
	for child in map_container.get_children():
		if child != lines_container: child.queue_free()
	
	var spawned_nodes = {} # Key: "layer_index", Value: node_instance
	
	# Loop through layers and nodes
	for layer_idx in range(RunState.current_map.size()):
		var layer_data = RunState.current_map[layer_idx]
		for node_idx in range(layer_data.size()):
			var data = layer_data[node_idx]
			
			# Instantiate and setup node
			var node = MAP_NODE_SCENE.instantiate()
			map_container.add_child(node)
			node.setup(data)
			
			# Position node (Inverted Y so 0 is bottom or top)
			# Let's do top-to-bottom for now
			var pos = Vector2(
				(node_idx - (layer_data.size()-1)/2.0) * X_SPACING + (size.x / 2.0),
				layer_idx * Y_SPACING + 100
			)
			node.position = pos - (node.size / 2.0)
			
			# Determine status
			_update_node_status(node, layer_idx)
			
			spawned_nodes["%d_%d" % [layer_idx, node_idx]] = node

	# Draw lines (after nodes are positioned)
	_draw_connections(spawned_nodes)

func _update_node_status(node: Control, layer_idx: int) -> void:
	# Simplified logic for now:
	# Layer 0 is always available if not completed.
	# Next layer is available if any previous connected node is completed.
	if RunState.completed_node_ids.has(node.node_data["id"]):
		node.set_status(node.NodeStatus.COMPLETED)
	elif layer_idx == 0:
		node.set_status(node.NodeStatus.AVAILABLE)
	else:
		# TODO: Real adjacency check
		node.set_status(node.NodeStatus.LOCKED)

func _draw_connections(nodes: Dictionary) -> void:
	for layer_idx in range(RunState.current_map.size() - 1):
		var layer = RunState.current_map[layer_idx]
		for node_idx in range(layer.size()):
			var data = layer[node_idx]
			var start_node = nodes["%d_%d" % [layer_idx, node_idx]]
			
			for target_idx in data["next_nodes"]:
				var end_node = nodes["%d_%d" % [layer_idx + 1, target_idx]]
				_create_line(start_node.position + start_node.size/2, end_node.position + end_node.size/2)

func _create_line(from: Vector2, to: Vector2) -> void:
	var line = Line2D.new()
	lines_container.add_child(line)
	line.add_point(from)
	line.add_point(to)
	line.width = 2.0
	line.default_color = Color(0.4, 0.4, 0.4, 0.5)
	line.z_index = -1 # Draw behind nodes
