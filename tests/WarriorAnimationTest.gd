class_name WarriorAnimationTest
extends Node
# PURPOSE: Verify event-driven visuals cannot change combat, and obey pause/speed/reset.

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	var model := ArenaSimulation.new()
	model.setup()
	var board := ArenaBoard.new()
	board.size = Vector2(900, 400)
	add_child(board)
	board.set_process(false)
	board.setup(model)
	var warrior := model.get_unit(0)
	var enemy := model.get_unit(4)
	var before := JSON.stringify(model.units)
	board._process(0.1)
	check(board.visual_animations[0]["state"] == "idle", "preparation uses idle")
	check(JSON.stringify(model.units) == before, "visual ticks never mutate combat units")
	model.start()
	model.take_events()
	board.visual_positions[0] = Vector2(warrior["cell"]) - Vector2(1, 0)
	board._process(0.02)
	check(board.visual_animations[0]["state"] == "move", "interpolated movement uses walking poses")
	check(board.visual_facings[0] == "east", "movement chooses facing")
	var hp_before: int = enemy["hp"]
	model.deal_damage(warrior, enemy, 20, false, "Attack")
	check(enemy["hp"] < hp_before, "damage resolves before animation receives its event")
	var hp_after: int = enemy["hp"]
	board.consume_events(model.take_events())
	check(board.visual_animations[0]["state"] == "attack", "damage event starts contact pose")
	check(board.visual_animations[0]["age"] == 0.0, "attack starts at contact frame zero")
	board.visuals_paused = true
	var position_before: Vector2 = board.visual_positions[0]
	board._process(0.2)
	check(board.visual_animations[0]["age"] == 0.0, "pause freezes animation")
	check(board.visual_positions[0] == position_before, "pause freezes interpolation")
	check(board.effects[0]["age"] == 0.0, "pause freezes event feedback")
	board.visuals_paused = false
	board.playback_rate = 3.0
	board._process(0.02)
	check(is_equal_approx(board.visual_animations[0]["age"], 0.06), "3x speed advances visuals at 3x")
	model.deal_damage(enemy, warrior, 20, false, "Attack")
	board.consume_events(model.take_events())
	check(board.visual_animations[0]["state"] == "attack", "hit cannot hide an active attack")
	board.visual_positions[0] = Vector2(warrior["cell"])
	board._process(0.2)
	check(board.visual_animations[0]["state"] == "idle", "completed attack returns to idle")
	model.deal_damage(enemy, warrior, 20, false, "Attack")
	board.consume_events(model.take_events())
	check(board.visual_animations[0]["state"] == "hit", "direct incoming damage plays recoil")
	board._process(0.02)
	model.deal_damage(enemy, warrior, 1, false, "Attack")
	board.consume_events(model.take_events())
	check(is_equal_approx(board.visual_animations[0]["age"], 0.06), "back-to-back hits do not restart an early recoil")
	board._process(0.1)
	model.deal_damage(warrior, enemy, 1, false, "Burn")
	board.consume_events(model.take_events())
	check(board.visual_animations[0]["state"] == "idle", "periodic damage does not create a sword attack")
	model.deal_damage(enemy, warrior, 9999, false, "Attack")
	board.consume_events(model.take_events())
	check(board.visual_animations[0]["state"] == "death", "death overrides other states")
	for i in range(6):
		board._process(0.2)
	check(is_equal_approx(board.visual_animations[0]["age"], 0.72), "death holds its final frame")
	check(enemy["hp"] == hp_after - 1, "visual playback never applies additional damage")
	model.setup()
	board.setup(model)
	check(board.visual_animations[0]["state"] == "idle" and board.visual_animations[0]["age"] == 0.0, "reset clears death and animation age")
	check(board.effects.is_empty(), "reset clears old effects")
	# Riftbound sentinel animates the Hex Weaver role through the same event rules.
	var hexer: Dictionary = {}
	for unit in model.units:
		if not unit["hero"] and unit["role"] == "hexer":
			hexer = unit
			break
	check(not hexer.is_empty(), "fixture encounter has a Hex Weaver")
	check(ArenaBoard.sprite_set(hexer) == "riftbound", "Hex Weaver uses the Riftbound atlas")
	for unit in model.units:
		var expected: String = unit["role"] if unit["hero"] else {"raider": "raider", "hexer": "riftbound", "hound": ""}[unit["role"]]
		check(ArenaBoard.sprite_set(unit) == expected, "%s uses sprite set '%s'" % [unit["name"], expected])
	for role in ["assassin", "captain"]:
		check(ArenaBoard.sprite_set({"hero": true, "role": role}) == role, "run-only hero class has a sprite: " + role)
	check(ArenaBoard.sprite_set({"hero": false, "role": "warrior"}) == "", "enemies never borrow hero sprites")
	check(board.visual_facings[hexer["uid"]] == "west", "enemies face the heroes at setup")
	model.start()
	model.take_events()
	warrior = model.get_unit(0)
	var hero_hp: int = warrior["hp"]
	model.deal_damage(hexer, warrior, 10, true, "Hex")
	check(warrior["hp"] < hero_hp, "Hex Weaver damage resolves in the simulation first")
	board.consume_events(model.take_events())
	check(board.visual_animations[hexer["uid"]]["state"] == "attack", "Hex Weaver casts on its damage event")
	board._process(0.5)
	model.deal_damage(warrior, hexer, 10, false, "Attack")
	board.consume_events(model.take_events())
	check(board.visual_animations[hexer["uid"]]["state"] == "hit", "Hex Weaver recoils from direct damage")
	model.deal_damage(warrior, hexer, 99999, false, "Attack")
	board.consume_events(model.take_events())
	for i in range(6):
		board._process(0.2)
	check(board.visual_animations[hexer["uid"]]["state"] == "death", "Hex Weaver death holds")
	for set_name in ArenaBoard.SPRITE_SETS:
		for facing in ArenaBoard.SPRITE_FACINGS:
			var texture := ArenaBoard.atlas(set_name, facing)
			check(texture.get_size() == Vector2(1536, 1280), "atlas dimensions: %s/%s" % [set_name, facing])
			var image := texture.get_image()
			for state in ArenaBoard.ANIMATION_ROWS:
				var row: int = ArenaBoard.ANIMATION_ROWS[state]
				var hashes := {}
				for frame in range(6):
					var frame_image := image.get_region(Rect2i(frame * 256, row * 256, 256, 256))
					var bounds := frame_image.get_used_rect()
					check(bounds.has_area() and bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < 256 and bounds.end.y < 256, "unclipped frame: %s/%s/%s/%d" % [set_name, facing, state, frame])
					hashes[hash(frame_image.get_data())] = true
				check(hashes.size() > 1, "animation has distinct poses: %s/%s/%s" % [set_name, facing, state])
	print("WARRIOR ANIMATION: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
