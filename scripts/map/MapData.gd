# PURPOSE: MapData — Defines the structure of a single node on the run map.
# The run map is a graph of map data objects. The player picks a path through them.
# MapGenerator.gd creates the full map at the start of each run.

class_name MapData
extends RefCounted

# ── NODE TYPES ────────────────────────────────────────────────────────────────
enum NodeType {
	BATTLE,       # Standard enemy encounter
	ELITE,        # Harder enemies, better loot
	SHOP,         # Buy/sell skills and items
	EVENT,        # Narrative choice card
	REST,         # Heal + 1 free skill upgrade
	BOSS,         # Chapter boss
}

# ── PROPERTIES ────────────────────────────────────────────────────────────────

## Unique node ID within this run's map
var id: int = 0

## What kind of encounter this node holds
var type: NodeType = NodeType.BATTLE

## Which nodes this node connects to (list of node IDs the player can go to next)
var next_node_ids: Array[int] = []

## Which node leads into this one (used for drawing the map)
var prev_node_id: int = -1

## Column position on the map (for layout)
var column: int = 0

## Row position within the column (for layout, multiple paths can branch)
var row: int = 0

## Whether the player has completed this node
var completed: bool = false

## Whether this node is currently reachable by the player
var is_reachable: bool = false

## For BATTLE/ELITE/BOSS nodes: which enemies appear here
var enemy_ids: Array[String] = []

## For EVENT nodes: which event card ID to show
var event_id: String = ""

## Display label (shown as tooltip on map)
var display_label: String = ""

# ── HELPERS ───────────────────────────────────────────────────────────────────

## Returns the icon character for this node type (used as placeholder icon)
func get_type_icon() -> String:
	match type:
		NodeType.BATTLE: return "⚔"
		NodeType.ELITE:  return "💀"
		NodeType.SHOP:   return "🛒"
		NodeType.EVENT:  return "❓"
		NodeType.REST:   return "🏕"
		NodeType.BOSS:   return "👁"
	return "?"

## Returns the color for this node type
func get_type_color() -> Color:
	match type:
		NodeType.BATTLE: return Color(0.7, 0.2, 0.2)
		NodeType.ELITE:  return Color(0.5, 0.1, 0.6)
		NodeType.SHOP:   return Color(0.2, 0.6, 0.2)
		NodeType.EVENT:  return Color(0.2, 0.4, 0.8)
		NodeType.REST:   return Color(0.1, 0.6, 0.6)
		NodeType.BOSS:   return Color(0.9, 0.4, 0.0)
	return Color.WHITE

## Serialize to dictionary for saving
func to_dict() -> Dictionary:
	return {
		"id":           id,
		"type":         type,
		"next_node_ids": next_node_ids,
		"prev_node_id": prev_node_id,
		"column":       column,
		"row":          row,
		"completed":    completed,
		"is_reachable": is_reachable,
		"enemy_ids":    enemy_ids,
		"event_id":     event_id,
	}

## Load from dictionary (for run save/load)
static func from_dict(d: Dictionary) -> MapData:
	var node = MapData.new()
	node.id           = d.get("id", 0)
	node.type         = d.get("type", NodeType.BATTLE)
	node.next_node_ids = d.get("next_node_ids", [])
	node.prev_node_id  = d.get("prev_node_id", -1)
	node.column       = d.get("column", 0)
	node.row          = d.get("row", 0)
	node.completed    = d.get("completed", false)
	node.is_reachable  = d.get("is_reachable", false)
	node.enemy_ids    = d.get("enemy_ids", [])
	node.event_id     = d.get("event_id", "")
	return node
