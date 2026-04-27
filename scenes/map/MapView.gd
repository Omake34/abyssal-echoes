# PURPOSE: MapView — Handles the visual representation of the procedural map.
# It creates MapNode UI elements purely in code (no external scene dependency).
class_name MapView
extends Control

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var map_container: Control = $ScrollContainer/MapContainer
@onready var lines_container: Control = $ScrollContainer/MapContainer/Lines

const X_SPACING: int = 200
const Y_SPACING: int = 150

func _ready() -> void:
	# 0. Start a new run if needed (first time loading the map)
	if not RunState.run_active:
		RunState.start_new_run()
		RunState.add_hero_to_party(load("res://resources/heroes/warrior.tres"))
		RunState.add_hero_to_party(load("res://resources/heroes/archer.tres"))
	
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
			
			var node = _create_map_node(data)
			map_container.add_child(node)
			
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

# ── NODE BUILDER ──────────────────────────────────────────────────────────────
# PURPOSE: Builds a single clickable map node purely in GDScript.

func _create_map_node(data: Dictionary) -> PanelContainer:
	# Root panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(64, 64)
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.8, 0.8, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	panel.add_theme_stylebox_override("panel", style)
	
	# VBox layout
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	# Color icon (represents node type)
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.color = _get_type_color(data.get("type", "battle"))
	vbox.add_child(icon)
	
	# Label
	var label = Label.new()
	label.text = data.get("name", "???")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(label)
	
	# Store data on the node itself using metadata
	panel.set_meta("node_data", data)
	panel.set_meta("node_status", "locked")
	
	# Connect click handler
	panel.gui_input.connect(_on_node_gui_input.bind(panel))
	
	return panel

# ── NODE STATUS ───────────────────────────────────────────────────────────────

func _update_node_status(node: PanelContainer, layer_idx: int, frontier_layer: int, reachable_indices: Array) -> void:
	var data = node.get_meta("node_data")
	var node_id = data["id"]

	# 1. Already visited → green
	if RunState.completed_node_ids.has(node_id):
		_set_node_status(node, "completed")
		return

	# 2. Must be exactly the frontier layer
	if layer_idx != frontier_layer:
		_set_node_status(node, "locked")
		return

	# 3. Layer 0 (START) — always available
	if frontier_layer == 0:
		_set_node_status(node, "available")
		return

	# 4. Only available if this node's index is in the reachable set
	#    (i.e. it is directly connected to the last completed node)
	if data["index"] in reachable_indices:
		_set_node_status(node, "available")
	else:
		_set_node_status(node, "locked")

func _set_node_status(node: PanelContainer, status: String) -> void:
	node.set_meta("node_status", status)
	match status:
		"locked":
			node.modulate = Color(0.3, 0.3, 0.3)
			node.mouse_default_cursor_shape = Control.CURSOR_ARROW
		"available":
			node.modulate = Color.WHITE
			node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		"completed":
			node.modulate = Color(0.5, 1.0, 0.5)
			node.mouse_default_cursor_shape = Control.CURSOR_ARROW

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

# ── INPUT HANDLING ────────────────────────────────────────────────────────────

func _on_node_gui_input(event: InputEvent, node: PanelContainer) -> void:
	if node.get_meta("node_status") != "available":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var data = node.get_meta("node_data")
		EventBus.map_node_selected.emit(data["id"])

# ── LINE DRAWING ──────────────────────────────────────────────────────────────
# Line states (matching Slay the Spire rules):
#   VISITED  : parent is completed  → dim (alpha 0.15), shows where you've been
#   ACTIVE   : parent is available (frontier) → bright white, shows next choices
#   FUTURE   : parent is locked → semi-visible, so you can plan ahead

func _draw_connections(nodes: Dictionary, frontier_layer: int) -> void:
	for layer_idx in range(RunState.current_map.size() - 1):
		var layer = RunState.current_map[layer_idx]
		for node_idx in range(layer.size()):
			var data = layer[node_idx]
			var key = "%d_%d" % [layer_idx, node_idx]
			if not nodes.has(key):
				continue
			var start_node = nodes[key]
			var parent_status = start_node.get_meta("node_status")

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

# ── HELPERS ───────────────────────────────────────────────────────────────────

func _get_type_color(type: String) -> Color:
	match type:
		"battle": return Color(0.7, 0.2, 0.2)
		"elite":  return Color(0.5, 0.1, 0.6)
		"boss":   return Color(0.9, 0.4, 0.0)
		"shop":   return Color(0.2, 0.6, 0.2)
		"rest":   return Color(0.1, 0.6, 0.6)
		"start":  return Color(0.3, 0.3, 0.8)
	return Color.WHITE
