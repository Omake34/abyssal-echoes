# PURPOSE: MapView — Handles the visual representation of the procedural map.
# It creates MapNode UI elements purely in code (no external scene dependency).
class_name MapView
extends Control

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var map_container: Control = $ScrollContainer/MapContainer
@onready var lines_container: Control = $ScrollContainer/MapContainer/Lines

const X_SPACING: int = 200
const Y_SPACING: int = 150

const MAP_NODE_SCENE = preload("res://scenes/map/MapNode.tscn")

func _ready() -> void:
	# 0. Start a new run if needed (first time loading the map)
	# 1. Ensure we have map data
	if RunState.current_map.is_empty():
		var generator = MapGenerator.new()
		RunState.current_map = generator.generate_map()
		RunState.save_run() # Save immediately after generation
	
	# 2. Render the map
	_render_map()

func _render_map() -> void:
	# Clear existing (if any)
	for child in map_container.get_children():
		if child != lines_container: child.queue_free()
	for child in lines_container.get_children():
		child.queue_free()
	
	# 1. Compute the frontier layer and which nodes are reachable from the last choice
	var frontier_layer = _get_frontier_layer()
	var reachable_indices = _get_reachable_indices(frontier_layer)
	
	var spawned_nodes = {}
	
	# 2. Loop through layers and nodes
	for layer_idx in range(RunState.current_map.size()):
		var layer_data = RunState.current_map[layer_idx]
		for node_idx in range(layer_data.size()):
			var data = layer_data[node_idx]
			
			var node = MAP_NODE_SCENE.instantiate() as MapNode
			map_container.add_child(node)
			node.setup(data)
			
			var pos = Vector2(
				(node_idx - (layer_data.size()-1)/2.0) * X_SPACING + (size.x / 2.0),
				layer_idx * Y_SPACING + 100
			)
			node.position = pos - (node.size / 2.0)
			
			# Pass reachable_indices so status knows which nodes in the frontier are valid
			_update_node_status(node, layer_idx, frontier_layer, reachable_indices)
			
			spawned_nodes["%d_%d" % [layer_idx, node_idx]] = node

	# 3. Draw lines with state awareness
	_draw_connections(spawned_nodes, frontier_layer)
	
	# 4. Auto-scroll to the frontier layer
	_scroll_to_frontier(frontier_layer)

func _scroll_to_frontier(frontier_layer: int) -> void:
	# Wait for UI layout to finish
	await get_tree().process_frame
	
	# Calculate target Y position for the frontier layer
	# The node's center Y is (layer_idx * Y_SPACING + 100)
	var target_y = (frontier_layer * Y_SPACING) + 100
	
	# Center it on screen (subtract half the viewport height)
	target_y -= scroll_container.size.y / 2.0
	
	# Apply scroll position, clamped to valid range
	scroll_container.scroll_vertical = clampi(int(target_y), 0, int(scroll_container.get_v_scroll_bar().max_value))

## Finds the first layer where the player has NOT completed any node.
## That is the layer where the player must choose next.
func _get_frontier_layer() -> int:
	for layer_idx in range(RunState.current_map.size()):
		var layer_data = RunState.current_map[layer_idx]
		var any_completed = false
		for node_data in layer_data:
			if RunState.completed_node_ids.has(node_data["id"]):
				any_completed = true
				break
		if not any_completed:
			return layer_idx
	return RunState.current_map.size()  # All layers completed

func _update_node_status(node: MapNode, layer_idx: int, frontier_layer: int, reachable_indices: Array) -> void:
	var data = node.node_data
	var node_id = data["id"]

	# 1. Already visited → green
	if RunState.completed_node_ids.has(node_id):
		node.set_status("completed")
		return

	# 2. Must be exactly the frontier layer
	if layer_idx != frontier_layer:
		node.set_status("locked")
		return

	# 3. Layer 0 (START) — always available
	if frontier_layer == 0:
		node.set_status("available")
		return

	# 4. Only available if this node's index is in the reachable set
	#    (i.e. it is directly connected to the last completed node)
	if data["index"] in reachable_indices:
		node.set_status("available")
	else:
		node.set_status("locked")

## Returns the list of node-indices in the frontier layer that the player can reach.
## These are the next_nodes of whichever node was completed in the previous layer.
func _get_reachable_indices(frontier_layer: int) -> Array:
	if frontier_layer == 0:
		return []  # Layer 0 is always all-available (handled separately)

	var prev_layer = RunState.current_map[frontier_layer - 1]
	for prev_data in prev_layer:
		if RunState.completed_node_ids.has(prev_data["id"]):
			return prev_data["next_nodes"]
	return []  # No completed node found in previous layer (shouldn't happen)

# ── LINE DRAWING ──────────────────────────────────────────────────────────────
# Line states (matching Slay the Spire rules):
#   VISITED  : parent is completed  → dim (alpha 0.15), shows where you've been
#   ACTIVE   : parent is available (frontier) → bright white, shows next choices
#   FUTURE   : parent is locked → semi-visible, so you can plan ahead

func _draw_connections(nodes: Dictionary, _frontier_layer: int) -> void:
	for layer_idx in range(RunState.current_map.size() - 1):
		var layer = RunState.current_map[layer_idx]
		for node_idx in range(layer.size()):
			var data = layer[node_idx]
			var key = "%d_%d" % [layer_idx, node_idx]
			if not nodes.has(key):
				continue
			var start_node = nodes[key]
			var parent_status = start_node.node_status

			for target_idx in data["next_nodes"]:
				var end_key = "%d_%d" % [layer_idx + 1, target_idx]
				if not nodes.has(end_key):
					continue
				var end_node = nodes[end_key]
				var from = start_node.position + start_node.size / 2.0
				var to   = end_node.position   + end_node.size   / 2.0

				if parent_status == "completed":
					# VISITED: dim grey
					_create_line(from, to, Color(0.6, 0.6, 0.6, 0.2), 2.0)
				elif parent_status == "available":
					# ACTIVE (frontier): bright, slightly coloured to show path forward
					_create_line(from, to, Color(0.8, 0.8, 1.0, 0.9), 3.0)
				else:
					# FUTURE (locked): visible but dim so player can plan their route
					_create_line(from, to, Color(0.4, 0.4, 0.5, 0.4), 2.0)

func _create_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var line = Line2D.new()
	lines_container.add_child(line)
	line.add_point(from)
	line.add_point(to)
	line.width = width
	line.default_color = color
