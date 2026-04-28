# PURPOSE: MapGenerator — Generates the procedural data structure for a run's map.
# Uses a SLOT-BASED system: the full layout is planned before any randomness.
#
# EXACT LAYOUT (15 layers, 0-14):
#   0        → START
#   1-3      → BATTLE + ELITE mix (30% elite chance per node)
#   4        → SHOP (node 0) + BATTLE (others)
#   5        → ELITE (node 0) + BATTLE (others)
#   6        → BATTLE + ELITE mix (30% elite chance per node)
#   7        → REST (full layer, single node)
#   8        → ELITE (node 0) + BATTLE (others)
#   9        → SHOP (node 0) + BATTLE (others)
#   10       → BATTLE + ELITE mix
#   11       → REST (full layer, single node)
#   12       → ELITE (node 0) + BATTLE (others)
#   13       → REST (pre-boss breather, single node)
#   14       → BOSS
class_name MapGenerator
extends RefCounted

const TOTAL_LAYERS: int = 15
const NODES_PER_LAYER_MIN: int = 2
const NODES_PER_LAYER_MAX: int = 3

# Layers that are entirely REST (single node, no choice)
const REST_LAYERS: Array = [7, 11, 13]
# Layers where node 0 is guaranteed SHOP, rest are battle
const SHOP_LAYERS: Array = [4, 9]
# Layers where node 0 is guaranteed ELITE, rest are battle
const ELITE_FIXED_LAYERS: Array = [5, 8, 12]
# Layers with a random battle/elite mix
const MIXED_LAYERS: Array = [1, 2, 3, 6, 10]
const ELITE_CHANCE_IN_MIXED: float = 0.30

func generate_map() -> Array:
	var map_data = []
	for i in range(TOTAL_LAYERS):
		map_data.append(_generate_layer(i))
	for i in range(TOTAL_LAYERS - 1):
		_connect_layers(map_data[i], map_data[i + 1])
	_verify_connectivity(map_data)
	return map_data

func _generate_layer(layer_index: int) -> Array:
	var nodes = []
	var count: int

	if layer_index == 0 or layer_index == TOTAL_LAYERS - 1:
		count = 1
	elif layer_index in REST_LAYERS:
		count = 1   # Rest layers have exactly one node
	else:
		count = randi_range(NODES_PER_LAYER_MIN, NODES_PER_LAYER_MAX)

	for i in range(count):
		var type = _pick_type(layer_index, i)
		nodes.append({
			"id":         "node_%d_%d" % [layer_index, i],
			"layer":      layer_index,
			"index":      i,
			"type":       type,
			"name":       type.to_upper(),
			"next_nodes": []
		})
	return nodes

func _pick_type(layer: int, node_index: int) -> String:
	# Fixed single-type layers
	if layer == 0:                 return "start"
	if layer == TOTAL_LAYERS - 1: return "boss"
	if layer in REST_LAYERS:      return "rest"

	# Shop layers: node 0 = shop, others = battle
	if layer in SHOP_LAYERS:
		return "shop" if node_index == 0 else "battle"

	# Elite-fixed layers: node 0 = elite, others = battle
	if layer in ELITE_FIXED_LAYERS:
		return "elite" if node_index == 0 else "battle"

	# Mixed layers: random elite chance per node, plus some event chance
	if layer in MIXED_LAYERS:
		var r = randf()
		if r < ELITE_CHANCE_IN_MIXED:
			return "elite"
		elif r < ELITE_CHANCE_IN_MIXED + 0.2:
			return "event"
		return "battle"

	return "battle"

# ── CONNECTIVITY ──────────────────────────────────────────────────────────────

func _connect_layers(cur: Array, nxt: Array) -> void:
	var cs = cur.size()
	var ns = nxt.size()
	var nxt_reached = []
	nxt_reached.resize(ns)
	nxt_reached.fill(false)

	# Pass 1: each cur node connects to its proportional next-node
	for i in range(cs):
		var t = _prop(i, cs, ns)
		cur[i]["next_nodes"].append(t)
		nxt_reached[t] = true

	# Pass 2: ensure every next-node has at least one parent
	for j in range(ns):
		if not nxt_reached[j]:
			var p = _prop(j, ns, cs)
			if j not in cur[p]["next_nodes"]:
				cur[p]["next_nodes"].append(j)

	# Pass 3: optional extra connections for branching (40% per node)
	for i in range(cs):
		if randf() < 0.4:
			var primary = cur[i]["next_nodes"][0]
			for delta in [-1, 1]:
				var candidate = primary + delta
				if candidate >= 0 and candidate < ns:
					if candidate not in cur[i]["next_nodes"] and randf() < 0.5:
						cur[i]["next_nodes"].append(candidate)
						break

func _prop(i: int, from_size: int, to_size: int) -> int:
	if from_size <= 1:
		return 0
	var ratio = float(i) / float(from_size - 1)
	return clampi(int(round(ratio * (to_size - 1))), 0, to_size - 1)

func _verify_connectivity(map_data: Array) -> void:
	for li in range(1, map_data.size()):
		for ni in range(map_data[li].size()):
			var has_parent = false
			for parent in map_data[li - 1]:
				if ni in parent["next_nodes"]:
					has_parent = true
					break
			if not has_parent:
				var best = _prop(ni, map_data[li].size(), map_data[li - 1].size())
				map_data[li - 1][best]["next_nodes"].append(ni)
