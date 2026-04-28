# PURPOSE: SceneManager — Handles all scene transitions and high-level game state flow.
# It listens to EventBus for requests to change scenes or when map nodes are selected.
extends Node

# ── CONFIGURATION ─────────────────────────────────────────────────────────────

const MAP_SCENE    = "res://scenes/map/MapView.tscn"
const BATTLE_SCENE = "res://scenes/battle/BattleScene.tscn"
const SHOP_SCENE   = "res://scenes/map/ShopScene.tscn"
const REWARD_SCENE = "res://scenes/battle/RewardScene.tscn"
const EVENT_SCENE  = "res://scenes/map/EventScene.tscn"
const RUN_END_SCENE = "res://scenes/EndRunScene.tscn"

# ── LIFECYCLE ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Connect to global events
	EventBus.scene_change_requested.connect(_on_scene_change_requested)
	EventBus.map_node_selected.connect(_on_map_node_selected)
	EventBus.battle_ended.connect(_on_battle_ended)
	EventBus.run_ended.connect(_on_run_ended)

# ── SIGNAL HANDLERS ───────────────────────────────────────────────────────────

func _on_run_ended(victory: bool, stats: Dictionary) -> void:
	# Give the user a moment to process if they lost in battle
	await get_tree().create_timer(1.0).timeout
	
	var scene = load(RUN_END_SCENE).instantiate()
	get_tree().root.add_child(scene)
	scene.setup(victory, stats)
	
	# Clean up old scene
	var old_scene = get_tree().current_scene
	get_tree().current_scene = scene
	old_scene.queue_free()

func _on_scene_change_requested(scene_path: String) -> void:
	_transition_to(scene_path)

func _on_map_node_selected(node_id: String) -> void:
	# 1. Update RunState
	RunState.current_node_id = node_id
	
	# 2. Find the node data to determine where to go
	var node_data = _find_node_data(node_id)
	if node_data.is_empty():
		push_error("[SceneManager] Could not find data for node: " + node_id)
		return
		
	# 3. Route to the appropriate scene based on node type
	match node_data["type"]:
		"battle", "elite", "boss":
			print("[SceneManager] Starting %s encounter..." % node_data["type"])
			_transition_to(BATTLE_SCENE)
		"shop":
			print("[SceneManager] Entering shop...")
			_transition_to(SHOP_SCENE)
		"event":
			print("[SceneManager] Entering event...")
			_transition_to(EVENT_SCENE)
		"rest":
			print("[SceneManager] Resting... Party healed 30%%.")
			RunState.heal_party(0.3)
			RunState.completed_node_ids.append(node_id)
			_transition_to(MAP_SCENE)
		"treasure":
			print("[SceneManager] Found treasure!")
			_transition_to(REWARD_SCENE)
		"start":
			RunState.completed_node_ids.append(node_id)
			_transition_to(MAP_SCENE)

func _on_battle_ended(result: String) -> void:
	if result == "win":
		# Check if this was a boss node
		var node_data = RunState.get_current_node_data()
		if node_data.get("type") == "boss":
			print("[SceneManager] Boss defeated! Victory reached.")
			RunState.end_run(true)
			return
			
		# Wait a moment for the player to see the result, then go to rewards
		await get_tree().create_timer(2.0).timeout
		_transition_to(REWARD_SCENE)
	else:
		print("[SceneManager] Player lost the battle.")
		RunState.end_run(false)
		# No need to transition to MAP_SCENE here, RunState.end_run(false) 
		# will trigger _on_run_ended which goes to the end screen.


# ── PRIVATE METHODS ───────────────────────────────────────────────────────────

func _transition_to(path: String) -> void:
	print("[SceneManager] Transitioning to: " + path)
	get_tree().change_scene_to_file(path)

func _find_node_data(node_id: String) -> Dictionary:
	for layer in RunState.current_map:
		for node in layer:
			if node["id"] == node_id:
				return node
	return {}
