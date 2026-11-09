class_name ArenaBoard
extends Control
## Presentation only: interpolation never changes simulation positions.
# PURPOSE: Draw the arena and the Blender sprite pilots without changing combat rules.

signal selection_changed(uid: int)
signal formation_changed

const GOLD := Color("d9b87a")
const TEAL := Color("6ed7cc")
const VIOLET := Color("b294f7")
const HERO_COLORS := {"warrior": Color("cf9d68"), "archer": Color("79cba4"),
	"mage": Color("ab9ae8"), "cleric": Color("eedaa0")}
# Blender-rendered atlases, keyed by sprite set. Both share one camera, so one canvas and pivot.
const SPRITE_SETS := {
	"warrior": {
		"east": preload("res://assets/characters/blender_pilot/animated/warrior_east.png"),
		"west": preload("res://assets/characters/blender_pilot/animated/warrior_west.png"),
		"north": preload("res://assets/characters/blender_pilot/animated/warrior_north.png"),
		"south": preload("res://assets/characters/blender_pilot/animated/warrior_south.png")},
	"riftbound": {
		"east": preload("res://assets/characters/blender_pilot/animated/riftbound_east.png"),
		"west": preload("res://assets/characters/blender_pilot/animated/riftbound_west.png"),
		"north": preload("res://assets/characters/blender_pilot/animated/riftbound_north.png"),
		"south": preload("res://assets/characters/blender_pilot/animated/riftbound_south.png")}}
const ANIMATION_ROWS := {"idle": 0, "move": 1, "attack": 2, "hit": 3, "death": 4}
const ANIMATION_SECONDS := {"idle": 1.2, "move": 0.6, "attack": 0.42, "hit": 0.24, "death": 0.72}
# Fixed render canvas: all directions and sets share the same projected ground anchor.
const SPRITE_CANVAS := Vector2(72, 72)
const SPRITE_FOOT_PIVOT := Vector2(0.5, 0.82505)

var simulation: ArenaSimulation
var selected := 0
var visual_positions := {}
var visual_facings := {}
var visual_animations := {}
var visuals_paused := false
var playback_rate := 1.0
var effects: Array[Dictionary] = []
var board_rect := Rect2()
var cell_size := 40.0
var clock := 0.0
var _drag_uid := -1
var _dragging := false
var _drag_start := Vector2.ZERO
var _drag_position := Vector2.ZERO
var _drag_offset := Vector2.ZERO
const DRAG_THRESHOLD := 6.0

func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)
	get_window().focus_exited.connect(cancel_drag)

func setup(model: ArenaSimulation) -> void:
	cancel_drag()
	simulation = model
	visual_positions.clear()
	visual_facings.clear()
	visual_animations.clear()
	effects.clear()
	for unit in model.units:
		visual_positions[unit["uid"]] = Vector2(unit["cell"])
		visual_facings[unit["uid"]] = "east" if unit["hero"] else "west"
		visual_animations[unit["uid"]] = {"state": "idle" if unit["alive"] else "death", "age": 0.0 if unit["alive"] else 0.72}
	queue_redraw()

func consume_events(batch: Array[Dictionary]) -> void:
	for event in batch:
		if event["kind"] == "result":
			continue
		# Events report results, never requests to apply damage. Contact is frame zero.
		if event["kind"] == "death":
			_trigger_animation(int(event["target"]), "death")
		elif event["kind"] == "damage":
			if event.get("text", "") not in ["Burn", "Bleed"]:
				_trigger_animation(int(event["source"]), "attack")
			if int(event.get("amount", 0)) > 0:
				_trigger_animation(int(event["target"]), "hit")
		var effect := event.duplicate()
		effect["age"] = 0.0
		# Simultaneous hits on one target stack in lanes instead of overprinting.
		var lane := 0
		for other in effects:
			if other.get("to") == effect.get("to") and float(other["age"]) < 0.3:
				lane += 1
		effect["lane"] = lane % 3
		effects.append(effect)

func _process(delta: float) -> void:
	# Match the simulation's pause and speed; animation never advances the simulation.
	delta = 0.0 if visuals_paused else minf(delta, 0.25) * playback_rate
	clock += delta
	if simulation == null:
		return
	for unit in simulation.units:
		var uid: int = unit["uid"]
		_update_animation(unit, delta)
		_update_visual_facing(unit)
		visual_positions[uid] = Vector2(visual_positions.get(uid, unit["cell"])).lerp(Vector2(unit["cell"]), minf(1.0, delta * 16.0))
	for effect in effects:
		effect["age"] += delta
	effects = effects.filter(func(e: Dictionary) -> bool: return e["age"] < 0.85)
	queue_redraw()

func _trigger_animation(uid: int, state: String) -> void:
	if simulation == null:
		return
	var unit := simulation.get_unit(uid)
	if unit.is_empty() or sprite_set(unit).is_empty():
		return
	if not unit["alive"] and state != "death":
		return
	var current: Dictionary = visual_animations.get(uid, {"state": "idle", "age": 0.0})
	if current["state"] == "death":
		return
	# Incoming hits must not hide the Warrior's attack; AoE events share one pose.
	if state == "hit" and current["state"] == "attack":
		return
	# Back-to-back incoming hits would otherwise pin the Warrior on frame zero.
	if state == "hit" and current["state"] == "hit" and float(current["age"]) < ANIMATION_SECONDS["hit"] * 0.5:
		return
	if state == current["state"] and float(current["age"]) == 0.0:
		return
	visual_animations[uid] = {"state": state, "age": 0.0}

## Which rendered atlas a unit uses; empty means the vector fallback figure.
static func sprite_set(unit: Dictionary) -> String:
	if unit["hero"] and unit["role"] == "warrior":
		return "warrior"
	if not unit["hero"] and unit["role"] == "hexer":
		return "riftbound"
	return ""

func _update_animation(unit: Dictionary, delta: float) -> void:
	if sprite_set(unit).is_empty():
		return
	var uid: int = unit["uid"]
	var animation: Dictionary = visual_animations[uid]
	if not unit["alive"] and animation["state"] != "death":
		_trigger_animation(uid, "death")
		animation = visual_animations[uid]
	if delta <= 0.0:
		return
	animation["age"] += delta
	if animation["state"] == "death":
		animation["age"] = minf(animation["age"], ANIMATION_SECONDS["death"])
		return
	if animation["state"] in ["attack", "hit"] and animation["age"] < ANIMATION_SECONDS[animation["state"]]:
		return
	var distance := Vector2(unit["cell"]).distance_squared_to(Vector2(visual_positions[uid]))
	var next_state := "move" if simulation.running and distance > 0.0025 else "idle"
	if animation["state"] != next_state:
		animation["state"] = next_state
		animation["age"] = 0.0
	else:
		animation["age"] = fmod(animation["age"], ANIMATION_SECONDS[next_state])

func _draw_sprite(uid: int, set_name: String, tint: Color = Color.WHITE) -> void:
	var animation: Dictionary = visual_animations.get(uid, {"state": "idle", "age": 0.0})
	var state: String = animation["state"]
	var frame := mini(5, int(float(animation["age"]) / ANIMATION_SECONDS[state] * 6.0))
	var texture: Texture2D = SPRITE_SETS[set_name][visual_facings.get(uid, "east")]
	var origin := Vector2(0, 10) - SPRITE_CANVAS * SPRITE_FOOT_PIVOT
	var region := Rect2(Vector2(frame, ANIMATION_ROWS[state]) * 256.0, Vector2(256, 256))
	draw_texture_rect_region(texture, Rect2(origin, SPRITE_CANVAS), region, tint)

func _update_visual_facing(unit: Dictionary) -> void:
	# Read simulation state only; movement takes priority over the attack target.
	if not unit["alive"]:
		return
	var direction := Vector2(unit["cell"]) - Vector2(visual_positions.get(unit["uid"], unit["cell"]))
	if direction.length_squared() < 0.0025 and int(unit.get("target", -1)) >= 0:
		var target := simulation.get_unit(int(unit["target"]))
		if not target.is_empty() and target["alive"]:
			direction = Vector2(target["cell"]) - Vector2(unit["cell"])
	if direction.length_squared() < 0.0025:
		return
	if absf(direction.x) >= absf(direction.y):
		visual_facings[unit["uid"]] = "east" if direction.x > 0 else "west"
	else:
		visual_facings[unit["uid"]] = "south" if direction.y > 0 else "north"

func _layout_board() -> void:
	cell_size = minf((size.x - 72.0) / ArenaSimulation.BOARD_SIZE.x, (size.y - 56.0) / ArenaSimulation.BOARD_SIZE.y)
	cell_size = maxf(1.0, cell_size)
	var dimensions := Vector2(ArenaSimulation.BOARD_SIZE) * cell_size
	board_rect = Rect2((size - dimensions) * 0.5, dimensions)

func cell_center(cell: Vector2) -> Vector2:
	return board_rect.position + (cell + Vector2(0.5, 0.5)) * cell_size

func _gui_input(event: InputEvent) -> void:
	if not _can_reposition():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_layout_board()
		var unit := _hero_at_pointer(event.position)
		if not unit.is_empty():
			selected = unit["uid"]
			_drag_uid = selected
			_dragging = false
			_drag_start = event.position
			_drag_position = event.position
			_drag_offset = cell_center(visual_positions[selected]) - event.position
			selection_changed.emit(selected)
		elif board_rect.has_point(event.position):
			_place_hero(selected, _pointer_cell(event.position))
		accept_event()

func _input(event: InputEvent) -> void:
	# Receive the release even if the pointer has left this Control.
	if _drag_uid < 0:
		return
	if not _can_reposition():
		cancel_drag()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_drag_position = get_global_transform_with_canvas().affine_inverse() * event.position
		if _drag_position.distance_to(_drag_start) >= DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			mouse_default_cursor_shape = Control.CURSOR_MOVE
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var was_dragging := _dragging
		var pointer: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if was_dragging and _valid_drop(pointer):
			_place_hero(_drag_uid, _pointer_cell(pointer))
		cancel_drag()
		if was_dragging:
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_drag()

func cancel_drag() -> void:
	_drag_uid = -1
	_dragging = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()

func _can_reposition() -> bool:
	return simulation != null and not simulation.running and simulation.result.is_empty()

func _pointer_cell(pointer: Vector2) -> Vector2i:
	_layout_board()
	return Vector2i(((pointer - board_rect.position) / cell_size).floor())

func _valid_drop(pointer: Vector2) -> bool:
	var cell := _pointer_cell(pointer)
	if not _can_reposition() or not board_rect.has_point(pointer) or not simulation.is_preparation_cell(cell):
		return false
	var occupant := simulation.unit_at(cell)
	return occupant.is_empty() or bool(occupant["hero"])

func _place_hero(uid: int, cell: Vector2i) -> void:
	var hero := simulation.get_unit(uid)
	if hero.is_empty() or cell == hero["cell"]:
		return
	if simulation.place_hero(uid, cell):
		visual_positions[uid] = Vector2(cell)
		formation_changed.emit()

func _hero_at_pointer(pointer: Vector2) -> Dictionary:
	# Heads, hats, and weapons extend above their cell; pick the drawn figure too.
	var closest := {}
	var best_distance := INF
	var scale_factor := clampf(cell_size / 46.0, 0.65, 1.2)
	for hero in simulation.living(true):
		var center := cell_center(visual_positions[hero["uid"]])
		var bounds := Rect2(center + Vector2(-22, -42) * scale_factor, Vector2(44, 60) * scale_factor)
		if hero["role"] == "warrior":
			bounds = Rect2(center + Vector2(-28, -44) * scale_factor, Vector2(56, 60) * scale_factor)
		var distance_to_body := pointer.distance_squared_to(center + Vector2(0, -12) * scale_factor)
		if bounds.has_point(pointer) and distance_to_body < best_distance:
			closest = hero
			best_distance = distance_to_body
	return closest

func _draw() -> void:
	_layout_board()
	draw_style_box(_frame_style(), Rect2(Vector2.ZERO, size))
	if simulation == null:
		return
	var prep: bool = not simulation.running and simulation.result.is_empty()
	# Stone floor and a restrained grid. Borders are outside the playable cells.
	for y in range(ArenaSimulation.BOARD_SIZE.y):
		for x in range(ArenaSimulation.BOARD_SIZE.x):
			var rect := Rect2(board_rect.position + Vector2(x, y) * cell_size, Vector2.ONE * cell_size)
			var tone := 0.018 * ((x * 7 + y * 11) % 4)
			var color := Color(0.105 + tone, 0.115 + tone, 0.145 + tone)
			if prep and x < ArenaSimulation.PREP_COLUMNS:
				color = color.lerp(Color("24413f"), 0.42)
			draw_rect(rect.grow(-0.7), color)
			if (x * 3 + y * 7) % 9 == 0:
				draw_line(rect.position + Vector2(9, 4), rect.position + Vector2(18, 12), Color(0.25, 0.26, 0.3, 0.2))
	draw_rect(board_rect.grow(2), Color("434451"), false, 2)
	_draw_environment()
	var chosen := simulation.get_unit(selected)
	if not chosen.is_empty() and chosen["alive"]:
		var at := cell_center(Vector2(chosen["cell"]))
		draw_arc(at, float(chosen["range"]) * cell_size, 0, TAU, 100, Color(0.45, 0.85, 0.8, 0.10), 1.5, true)
		for ability in chosen.get("abilities", []):
			if ability.activation == "heal_action" and not is_equal_approx(ability.range_cells, float(chosen["range"])):
				draw_arc(at, ability.range_cells * cell_size, 0, TAU, 100, Color(0.45, 0.85, 0.8, 0.07), 1.0, true)
		if not prep and chosen["target"] >= 0:
			var target := simulation.get_unit(int(chosen["target"]))
			if not target.is_empty() and target["alive"]:
				draw_dashed_line(at, cell_center(Vector2(target["cell"])), Color(0.7, 0.85, 0.8, 0.24), 1, 5)
	# Sort by world depth to keep feet and shadows readable when actors pass.
	var sorted := simulation.units.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["cell"].y < b["cell"].y)
	for unit in sorted:
		if _dragging and unit["uid"] == _drag_uid:
			draw_arc(cell_center(Vector2(unit["cell"])), 15, 0, TAU, 30, Color(TEAL, 0.35), 1.5, true)
		else:
			_draw_unit(unit)
	if prep and _dragging:
		_draw_placement_preview()
	for effect in effects:
		_draw_effect(effect)
	var caption := "DEPLOYMENT ZONE" if prep else "THE HOLLOW GATE"
	_text(board_rect.position + Vector2(2, -11), caption, 11, TEAL if prep else GOLD)
	_text(Vector2(board_rect.end.x - 118, board_rect.position.y - 11), "16 × 7  /  ARENA", 11, Color("85869a"))

func _frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0c1018")
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color = Color("333443")
	return style

func _draw_environment() -> void:
	for x in [board_rect.position.x - 18, board_rect.end.x + 18]:
		for y in [board_rect.position.y + 26, board_rect.end.y - 26]:
			var point := Vector2(x, y)
			draw_rect(Rect2(point - Vector2(7, 14), Vector2(14, 28)), Color("34313a"))
			draw_circle(point - Vector2(0, 8), 14 + sin(clock * 3.0 + y) * 2.0, Color(0.9, 0.5, 0.2, 0.07))
			draw_colored_polygon(PackedVector2Array([point + Vector2(-4, -7), point + Vector2(0, -23 - sin(clock * 5) * 2), point + Vector2(5, -7)]), Color("e7ac69"))

func _draw_placement_preview() -> void:
	var cell := _pointer_cell(_drag_position)
	var valid := _valid_drop(_drag_position)
	var color := TEAL if valid else Color("ed8888")
	var text := "" if valid else "Drop inside the teal deployment zone"
	if valid:
		var occupant := simulation.unit_at(cell)
		if not occupant.is_empty() and occupant["uid"] != _drag_uid:
			color = GOLD
			text = "Swap with " + str(occupant["name"])
	if board_rect.has_point(_drag_position):
		var rect := Rect2(board_rect.position + Vector2(cell) * cell_size, Vector2.ONE * cell_size)
		draw_rect(rect.grow(-2), Color(color, 0.18))
		draw_rect(rect.grow(-2), color, false, 2)
	_draw_unit(simulation.get_unit(_drag_uid), _drag_position + _drag_offset)
	if not text.is_empty():
		var label_at := Vector2(clampf(_drag_position.x + 26, 12, maxf(12, size.x - 305)), clampf(_drag_position.y + 30, 20, size.y - 12))
		_text(label_at, text, 13, color)

func _draw_unit(unit: Dictionary, position_override: Vector2 = Vector2.INF) -> void:
	var uid: int = unit["uid"]
	var point := cell_center(visual_positions[uid]) if position_override == Vector2.INF else position_override
	var scale_factor := clampf(cell_size / 46.0, 0.65, 1.2)
	var hero: bool = unit["hero"]
	var color: Color = HERO_COLORS.get(unit["role"], Color("bb6a78"))
	var rendered := sprite_set(unit)
	if not unit["alive"]:
		if not rendered.is_empty():
			draw_set_transform(point, 0, Vector2.ONE * scale_factor)
			_draw_sprite(uid, rendered, Color(0.65, 0.65, 0.7, 0.75))
			draw_set_transform(Vector2.ZERO)
		draw_line(point + Vector2(-7, -5), point + Vector2(7, 5), Color("554657"), 3)
		draw_line(point + Vector2(7, -5), point + Vector2(-7, 5), Color("554657"), 3)
		return
	if uid == selected:
		draw_arc(point + Vector2(0, 7), 18 * scale_factor, 0, TAU, 36, TEAL, 1.5, true)
	draw_set_transform(point + Vector2(0, 10), 0, Vector2(1, 0.33))
	draw_circle(Vector2.ZERO, 16 * scale_factor, Color(0, 0, 0, 0.45))
	draw_set_transform(point, 0, Vector2.ONE * scale_factor)
	var facing := 1.0 if hero else -1.0
	var bob := sin(clock * 3.4 + uid) * 1.0
	# Simple original cloaked figures, with role-specific weapons and silhouettes.
	if not rendered.is_empty():
		_draw_sprite(uid, rendered)
	elif unit["role"] == "hound":
		draw_colored_polygon(PackedVector2Array([Vector2(-15, 4), Vector2(-12, -10), Vector2(6, -8), Vector2(16, -17), Vector2(14, 6)]), color.darkened(0.25))
		draw_line(Vector2(-9, 2), Vector2(-11, 12), color, 4)
		draw_line(Vector2(8, 2), Vector2(11, 12), color, 4)
		draw_circle(Vector2(9, -9), 2, Color("ffd29c"))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-9, -13), Vector2(8, -13), Vector2(13, 10), Vector2(-13, 10)]), color.darkened(0.48))
		draw_rect(Rect2(-7, -12 + bob, 14, 17), color.darkened(0.18))
		draw_line(Vector2(-5, 5), Vector2(-6, 13), Color("252c39"), 5)
		draw_line(Vector2(5, 5), Vector2(6, 13), Color("252c39"), 5)
		draw_circle(Vector2(0, -20 + bob), 8, color)
		draw_rect(Rect2(-5, -21 + bob, 11, 5), Color("2c2934"))
		draw_circle(Vector2(facing * 3, -19 + bob), 1.4, Color("fff0cd"))
		match unit["role"]:
			"warrior", "raider":
				draw_line(Vector2(facing * 13, 0), Vector2(facing * 13, -23), Color("d3d9df"), 3)
				draw_line(Vector2(facing * 8, -4), Vector2(facing * 18, -4), GOLD, 3)
				draw_colored_polygon(PackedVector2Array([Vector2(-14 * facing, -13), Vector2(-5 * facing, -8), Vector2(-8 * facing, 3), Vector2(-14 * facing, 7), Vector2(-20 * facing, -1), Vector2(-22 * facing, -10)]), color.lightened(0.1))
			"archer":
				draw_arc(Vector2(9, -5), 13, -1.3, 1.3, 16, GOLD, 2, true)
				draw_line(Vector2(12, -18), Vector2(12, 8), Color("d7dacb"), 1)
				draw_line(Vector2(3, -5), Vector2(25, -5), Color("e8ddbb"), 1.5)
			"mage", "hexer", "cleric":
				draw_line(Vector2(facing * 14, 11), Vector2(facing * 14, -27), GOLD.darkened(0.3), 3)
				draw_circle(Vector2(facing * 14, -26), 5, color.lightened(0.25))
				if unit["role"] == "mage" or unit["role"] == "hexer":
					draw_colored_polygon(PackedVector2Array([Vector2(-10, -24), Vector2(-2, -39), Vector2(8, -24)]), color.darkened(0.3))
				else:
					draw_line(Vector2(-3, -5), Vector2(3, -5), GOLD, 2)
					draw_line(Vector2(0, -9), Vector2(0, -1), GOLD, 2)
	draw_set_transform(Vector2.ZERO)
	var bar := Rect2(point + Vector2(-19, -44) * scale_factor, Vector2(38, 4) * scale_factor)
	draw_rect(bar, Color("181823"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(unit["hp"]) / unit["max_hp"], bar.size.y)), TEAL if hero else Color("e27f86"))
	if unit["shield"] > 0:
		# Shield reads on the HP bar so it never covers the figure.
		var shield_ratio := minf(1.0, float(unit["shield"]) / float(unit["max_hp"]))
		draw_rect(Rect2(bar.position - Vector2(0, 2 * scale_factor), Vector2(bar.size.x * shield_ratio, 2 * scale_factor)), Color("7ec4ff"))
	if unit["taunt_left"] > 0:
		_text(bar.end + Vector2(3, 2), "!", 13, GOLD)
	if unit["burn_left"] > 0:
		draw_circle(point + Vector2(-13, -12), 4 + sin(clock * 10.0), Color("eb9454"))
	if hero:
		_text(point + Vector2(-3, 25), str(uid + 1), 11, color)

func _draw_effect(effect: Dictionary) -> void:
	var age: float = effect["age"]
	var kind: String = effect["kind"]
	var from := cell_center(effect["from"])
	var to := cell_center(effect["to"])
	var color := Color("e9d4ab")
	if kind == "heal":
		color = TEAL
	elif effect["text"] in ["Bolt", "Arcane Surge"]:
		color = VIOLET
	elif effect["text"] == "Burn" or kind == "burn":
		color = Color("f3a66e")
	if kind == "taunt":
		draw_arc(to, (0.4 + age * 1.2) * cell_size, 0, TAU, 60, Color(GOLD, 0.45 * (1.0 - age / 0.85)), 1.5, true)
	elif kind in ["damage", "heal"] and age < 0.30:
		if from.distance_to(to) > cell_size * 1.5:
			var head := from.lerp(to, minf(1.0, age / 0.22))
			draw_line(head - (to - from).normalized() * 12, head, color, 2, true)
			draw_circle(head, 3, color)
		else:
			draw_arc(to, 16, -1.1 + age * 9, 0.8 + age * 9, 12, Color(color, 1.0 - age / 0.3), 2.5, true)
	if kind in ["damage", "heal"]:
		var label := ("+" if kind == "heal" else "") + str(effect["amount"])
		if effect["amount"] == 0:
			label = "BLOCK"
		var scale_factor := clampf(cell_size / 46.0, 0.65, 1.2)
		var font_size := 12 if effect["amount"] == 0 else 13
		var width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var lane: int = effect.get("lane", 0)
		var lift := 50.0 * scale_factor + lane * 13.0 + age * 22.0
		_text(to + Vector2(-width * 0.5 + (lane - 1) * 6.0 * float(lane > 0), -lift), label, font_size, Color(color, 1.0 - age / 0.85))

func _text(at: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, at + Vector2(1, 1), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, color.a))
	draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
