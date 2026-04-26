# PURPOSE: MapGenerator — Generates the procedural data structure for a run's map.
# It creates a series of 'Layers', where each layer contains multiple nodes.
class_name MapGenerator
extends RefCounted

# ── CONFIGURATION ─────────────────────────────────────────────────────────────

const TOTAL_LAYERS: int = 15
const NODES_PER_LAYER_MIN: int = 2
const NODES_PER_LAYER_MAX: int = 4

# ── GENERATION LOGIC ──────────────────────────────────────────────────────────

## Returns a nested Array: [ [Layer 0 Nodes], [Layer 1 Nodes], ... ]
func generate_map() -> Array:
	var map_data = []
	
	# 1. Create the nodes for each layer
	for i in range(TOTAL_LAYERS):
		var layer = _generate_layer(i)
		map_data.append(layer)
	
	# 2. Connect nodes to the next layer
	for i in range(TOTAL_LAYERS - 1):
		_connect_layers(map_data[i], map_data[i+1])
		
	return map_data

func _generate_layer(layer_index: int) -> Array:
	var nodes = []
	var count = randi_range(NODES_PER_LAYER_MIN, NODES_PER_LAYER_MAX)
	
	# Special cases: First layer and Boss layer
	if layer_index == 0: count = 1 # Start with 1 node
	if layer_index == TOTAL_LAYERS - 1: count = 1 # End with 1 Boss
	
	for i in range(count):
		var type = _pick_node_type(layer_index)
		nodes.append({
			"id": "node_%d_%d" % [layer_index, i],
			"layer": layer_index,
			"index": i,
			"type": type,
			"name": type.to_upper(),
			"next_nodes": [] # Array of indices in the next layer
		})
	return nodes

func _pick_node_type(layer_index: int) -> String:
	if layer_index == 0: return "start"
	if layer_index == TOTAL_LAYERS - 1: return "boss"
	
	var r = randf()
	if r < 0.15: return "shop"
	if r < 0.25: return "elite"
	if r < 0.35: return "rest"
	return "battle"

func _connect_layers(current_layer: Array, next_layer: Array) -> void:
	# Basic connection logic: every node in current must connect to at least one in next
	# And every node in next must be reachable from current
	for i in range(current_layer.size()):
		var node = current_layer[i]
		
		# Connect to the node at the same relative position, or nearby
		var target_idx = clampi(i, 0, next_layer.size() - 1)
		node["next_nodes"].append(target_idx)
		
		# 30% chance to add a second connection
		if next_layer.size() > 1 and randf() < 0.3:
			var second_target = (target_idx + 1) % next_layer.size()
			if second_target not in node["next_nodes"]:
				node["next_nodes"].append(second_target)
