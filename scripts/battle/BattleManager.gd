# PURPOSE: BattleManager — The heart of the game.
# Runs the tick-based auto-battle simulation.
# It does NOT handle visuals — it only simulates the math.
# The BattleScene listens to EventBus signals from this manager to show animations.
#
# HOW THE TICK SYSTEM WORKS:
#   Every _process() frame, we accumulate time.
#   When enough time passes (based on battle_speed), we fire one "tick".
#   Each tick, every living combatant tries to act (if their speed allows it).
#   This continues until all heroes or all enemies are dead.

class_name BattleManager
extends Node

# ── SIGNALS (local — also emit through EventBus for cross-scene listeners) ────
signal battle_finished(result: String)

# ── CONSTANTS ─────────────────────────────────────────────────────────────────
const TICK_INTERVAL_SECONDS: float = 0.5  # How often a tick fires at 1x speed
const MAX_TICKS: int = 500               # Safety limit to prevent infinite battles

# ── STATE ─────────────────────────────────────────────────────────────────────

## Live hero instances for this battle
## Each is a Dictionary mirroring RunState party format, with battle-only fields added
var heroes: Array = []

## Live enemy instances for this battle
var enemies: Array = []

## Current battle speed multiplier (1.0, 2.0, 3.0)
var battle_speed: float = 1.0

## Accumulated time since last tick
var _tick_accumulator: float = 0.0

## Total ticks elapsed in this battle
var _tick_count: int = 0

## Whether the battle is currently running
var _running: bool = false
var _finished: bool = false

# ── SETUP ─────────────────────────────────────────────────────────────────────

## Initializes the battle state, setting up combatant dictionaries.
## Does NOT start the timer. Call begin_combat() to start fighting.
func init_battle(party: Array, enemy_data_list: Array) -> void:
	_tick_accumulator = 0.0
	_tick_count       = 0
	_running          = false
	_finished         = false

	# Build live hero instances from RunState party
	heroes = []
	for i in range(party.size()):
		heroes.append(_create_combatant_from_hero(party[i], i))

	# Build live enemy instances from EnemyData resources
	enemies = []
	for enemy_data in enemy_data_list:
		enemies.append(_create_combatant_from_enemy(enemy_data))
		RunState.record_enemy_discovery(enemy_data.id)

	print("[BattleManager] Battle initialized! %d heroes vs %d enemies" % [heroes.size(), enemies.size()])

## Starts the tick timer and commences auto-battle.
func begin_combat() -> void:
	if _running or _finished:
		return
	_running = true
	EventBus.battle_started.emit()
	print("[BattleManager] Combat started!")

## Builds a live combatant dictionary from a RunState hero instance
func _create_combatant_from_hero(hero_instance: Dictionary, index: int) -> Dictionary:
	return RunPartyAdapter.hero_snapshot(hero_instance, index)

## Builds a live combatant dictionary from an EnemyData resource
func _create_combatant_from_enemy(enemy_data: EnemyData) -> Dictionary:
	# Load skills from IDs
	var enemy_skills = []
	for skill_id in enemy_data.skill_ids:
		var skill = GameData.get_skill(skill_id)
		if skill:
			enemy_skills.append(skill)

	return {
		"id":           enemy_data.id,
		"display_name": enemy_data.display_name,
		"is_hero":      false,
		"data":         enemy_data,
		"current_hp":   enemy_data.base_hp,
		"max_hp":       enemy_data.base_hp,
		"atk":          enemy_data.base_atk,
		"magic_atk":    enemy_data.base_magic_atk,
		"heal_power":   enemy_data.base_heal_power,
		"def":          enemy_data.base_def,
		"magic_def":    enemy_data.base_magic_def,
		"speed":        enemy_data.base_speed,
		"crit_chance":  0.05,
		"crit_mult":    1.5,
		"evasion":      0.0,
		"skills":       enemy_skills,
		"skill_cooldowns": {},
		"status_effects":  [],
		"alive":        true,
		"tick_progress": 0,
	}

# ── MAIN LOOP ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _running:
		return

	# Accumulate time, scaled by battle speed
	_tick_accumulator += delta * battle_speed

	# Fire a tick when enough time has passed
	if _tick_accumulator >= TICK_INTERVAL_SECONDS:
		_tick_accumulator -= TICK_INTERVAL_SECONDS
		_simulate_tick()

## Rapidly simulates the remainder of the battle (for dev testing)
func skip_battle() -> void:
	if not _running: return
	print("[BattleManager] Skipping to end of battle...")
	# Simulate ticks as fast as possible until running stops
	# Put a hard limit to avoid freezing the game
	var limit = MAX_TICKS
	while _running and limit > 0:
		_simulate_tick()
		limit -= 1
		
	if limit <= 0 and _running:
		_end_battle("lose")

## One tick of battle simulation
func _simulate_tick() -> void:
	_tick_count += 1

	# Safety: end battle if it goes on too long (something is wrong)
	if _tick_count > MAX_TICKS:
		push_warning("[BattleManager] MAX_TICKS reached — forcing battle end")
		_end_battle("lose")
		return

	# Tick all combatants
	var all_combatants = heroes + enemies
	for combatant in all_combatants:
		if combatant["alive"]:
			_tick_combatant(combatant)

	# Tick down status effects
	_process_status_effects()

	# Check if battle is over
	_check_battle_end()

	# Tell listeners a tick happened (BattleScene will refresh UI)
	EventBus.tick_processed.emit()
	RunState.run_stats["turns_survived"] += 1

## Advances one combatant's action logic
func _tick_combatant(combatant: Dictionary) -> void:
	# Check for stun
	for effect in combatant["status_effects"]:
		if effect["type"] == "stun":
			# Stunned: cannot accumulate progress or act
			return

	# Speed determines how often a combatant acts
	# A combatant with speed 10 acts every tick; speed 5 acts every 2 ticks
	combatant["tick_progress"] += combatant["speed"]
	if combatant["tick_progress"] < 10:
		return  # Not their turn yet

	combatant["tick_progress"] -= 10

	# Reduce skill cooldowns
	for skill_id in combatant["skill_cooldowns"].keys():
		combatant["skill_cooldowns"][skill_id] = max(0, combatant["skill_cooldowns"][skill_id] - 1)

	# Decide action: try to use a skill, otherwise basic attack
	var skill_used = _try_use_skill(combatant)
	if not skill_used:
		_do_basic_attack(combatant)

# ── SKILL LOGIC ───────────────────────────────────────────────────────────────

## Tries to use a skill. Returns true if a skill was used.
func _try_use_skill(combatant: Dictionary) -> bool:
	if combatant["skills"].is_empty():
		return false

	# Check if enemy or hero
	var use_chance = combatant["data"].skill_use_chance if not combatant["is_hero"] else 0.6

	if randf() > use_chance:
		return false

	# Pick a random available skill (not on cooldown)
	var available_skills = combatant["skills"].filter(func(s):
		return combatant["skill_cooldowns"].get(s.id, 0) == 0
	)

	if available_skills.is_empty():
		return false

	var skill: SkillData = available_skills[randi() % available_skills.size()]
	var targets = _get_targets(combatant, skill)

	EventBus.skill_cast.emit(combatant, skill, targets)
	_apply_skill(combatant, skill, targets)
	combatant["skill_cooldowns"][skill.id] = skill.cooldown_ticks
	return true

## Determines the target array for a given skill
func _get_targets(caster: Dictionary, skill: SkillData) -> Array:
	var opponent_list = enemies if caster["is_hero"] else heroes
	var ally_list     = heroes if caster["is_hero"] else enemies
	var alive_opponents = opponent_list.filter(func(c): return c["alive"])
	var alive_allies    = ally_list.filter(func(c): return c["alive"])

	match skill.target_type:
		"single_enemy":  return [_pick_target(alive_opponents, caster)]
		"all_enemies":   return alive_opponents
		"single_ally":   return [_pick_target(alive_allies, caster, true)]
		"all_allies":    return alive_allies
		"self":          return [caster]
	return []

## Picks one target from a list based on targeting strategy
func _pick_target(target_list: Array, caster: Dictionary, prefer_hurt: bool = false) -> Dictionary:
	if target_list.is_empty():
		return {}
	
	if prefer_hurt:
		# For heals: target ally with lowest HP percentage
		target_list.sort_custom(func(a, b): return float(a["current_hp"]) / a["max_hp"] < float(b["current_hp"]) / b["max_hp"])
		return target_list[0]
	
	# If it's an enemy, use their defined strategy
	if not caster["is_hero"] and "data" in caster and caster["data"] is EnemyData:
		var strategy = caster["data"].targeting_strategy
		match strategy:
			"lowest_hp":
				target_list.sort_custom(func(a, b): return a["current_hp"] < b["current_hp"])
				return target_list[0]
			"highest_hp":
				target_list.sort_custom(func(a, b): return a["current_hp"] > b["current_hp"])
				return target_list[0]
			"front_row":
				var front = target_list.filter(func(c): return c.get("position", Vector2i.ZERO).y == 0)
				if not front.is_empty(): return front[randi() % front.size()]
			"back_row":
				var back = target_list.filter(func(c): return c.get("position", Vector2i.ZERO).y == 1)
				if not back.is_empty(): return back[randi() % back.size()]
	
	# Default: random target
	return target_list[randi() % target_list.size()]

## Applies a skill's effect to its targets
func _apply_skill(caster: Dictionary, skill: SkillData, targets: Array) -> void:
	for target in targets:
		if not target or not target.get("alive", false):
			continue
		match skill.effect_id:
			"damage_flat":
				var dmg = int(skill.power)
				_deal_damage(caster, target, dmg, skill.skill_type == "magic")
			"damage_atk_mult":
				var dmg = int(caster["atk"] * skill.power)
				
				# Special Logic: Execute
				if skill.id == "skill_execute":
					var hp_percent = float(target["current_hp"]) / target["max_hp"]
					if hp_percent <= skill.power_secondary:
						dmg *= 2
						print("[Battle] EXECUTE! %s deals double damage to %s" % [caster["display_name"], target["display_name"]])
				
				_deal_damage(caster, target, dmg, false)
			"damage_magic_mult":
				var dmg = int(caster["magic_atk"] * skill.power)
				_deal_damage(caster, target, dmg, true)
			"heal_flat":
				_apply_heal(caster, target, int(skill.power))
			"heal_power_mult":
				var heal = int(caster["heal_power"] * skill.power)
				_apply_heal(caster, target, heal)
			"apply_stun":
				_apply_status_effect(target, "stun", int(skill.power), 0)
			"apply_burn":
				_apply_status_effect(target, "burn", int(skill.power_secondary), skill.power)
			"apply_bleed":
				_apply_status_effect(target, "bleed", int(skill.power_secondary), skill.power)
			_:
				push_warning("[BattleManager] Unknown effect_id: " + skill.effect_id)

# ── COMBAT MATH ───────────────────────────────────────────────────────────────

## Basic auto-attack (no skill)
func _do_basic_attack(attacker: Dictionary) -> void:
	var targets = enemies if attacker["is_hero"] else heroes
	var alive = targets.filter(func(c): return c["alive"])
	if alive.is_empty():
		return
	var target = alive[randi() % alive.size()]
	_deal_damage(attacker, target, attacker["atk"], false)

## Deals physical or magical damage to a target, accounting for defense and crits
func _deal_damage(attacker: Dictionary, target: Dictionary, base_damage: int, is_magic: bool) -> void:
	# Evasion check — if target evades, no damage
	if randf() < target.get("evasion", 0.0):
		print("[Battle] %s evaded %s's attack!" % [target["display_name"], attacker["display_name"]])
		return

	# Defense reduction
	var defense = target["def"] if not is_magic else target["data"].base_magic_def
	var damage = max(1, base_damage - defense)  # Minimum 1 damage always

	# Critical hit check
	var is_crit = randf() < attacker.get("crit_chance", 0.05)
	if is_crit:
		damage = int(damage * attacker.get("crit_mult", 1.5))

	# Apply damage
	target["current_hp"] = max(0, target["current_hp"] - damage)
	EventBus.damage_dealt.emit(target, damage, is_crit)

	print("[Battle] %s → %s: %d dmg%s (HP: %d/%d)" % [
		attacker["display_name"], target["display_name"],
		damage, " (CRIT!)" if is_crit else "",
		target["current_hp"], target["max_hp"]
	])

	# Check if target died
	if target["current_hp"] <= 0:
		_handle_death(target)

## Applies healing to a target
func _apply_heal(caster: Dictionary, target: Dictionary, amount: int) -> void:
	var actual_heal = min(amount, target["max_hp"] - target["current_hp"])
	target["current_hp"] += actual_heal
	EventBus.healing_applied.emit(target, actual_heal)
	print("[Battle] %s healed %s for %d HP" % [caster["display_name"], target["display_name"], actual_heal])

# ── DEATH & STATUS ────────────────────────────────────────────────────────────

func _handle_death(combatant: Dictionary) -> void:
	combatant["alive"] = false
	combatant["current_hp"] = 0
	if combatant["is_hero"]:
		EventBus.hero_died.emit(combatant)
		print("[Battle] HERO DIED: " + combatant["display_name"])
	else:
		EventBus.enemy_died.emit(combatant)
		RunState.run_stats["enemies_killed"] += 1
		# Give gold for killing this enemy
		var gold = randi_range(
			combatant["data"].gold_drop_min,
			combatant["data"].gold_drop_max
		)
		RunState.add_gold(gold)
		# Boss Guaranteed Drop
		if combatant["data"].is_boss and combatant["data"].boss_guaranteed_drop_id != "":
			var drop_id = combatant["data"].boss_guaranteed_drop_id
			var drop_res = GameData.get_skill(drop_id)
			if drop_res:
				RunState.add_item(drop_res)
				print("[Battle] BOSS DROP: %s dropped %s!" % [combatant["display_name"], drop_res.display_name])
		
		print("[Battle] ENEMY DIED: %s (gave %d gold)" % [combatant["display_name"], gold])

## Adds a status effect to a combatant
func _apply_status_effect(target: Dictionary, type: String, duration: int, power: float) -> void:
	# Refresh if exists
	for effect in target["status_effects"]:
		if effect["type"] == type:
			effect["duration_ticks"] = max(effect["duration_ticks"], duration)
			effect["power"] = max(effect["power"], power)
			return
			
	target["status_effects"].append({
		"type": type,
		"duration_ticks": duration,
		"power": power
	})
	print("[Battle] %s applied to %s (%d ticks)" % [type.to_upper(), target["display_name"], duration])

func _process_status_effects() -> void:
	var all = heroes + enemies
	for combatant in all:
		if not combatant["alive"]: continue
		
		var to_remove = []
		for effect in combatant["status_effects"]:
			match effect["type"]:
				"burn":
					var dmg = int(combatant["max_hp"] * effect["power"])
					_deal_damage(combatant, combatant, dmg, true)
				"bleed":
					_deal_damage(combatant, combatant, int(effect["power"]), false)
			
			effect["duration_ticks"] -= 1
			if effect["duration_ticks"] <= 0:
				to_remove.append(effect)
				
		for e in to_remove:
			combatant["status_effects"].erase(e)

# ── WIN / LOSE ────────────────────────────────────────────────────────────────

func _check_battle_end() -> void:
	var all_heroes_dead  = heroes.all(func(h): return not h["alive"])
	var all_enemies_dead = enemies.all(func(e): return not e["alive"])

	if all_enemies_dead:
		_end_battle("win")
	elif all_heroes_dead:
		_end_battle("lose")

func _end_battle(result: String) -> void:
	if _finished:
		return
	_finished = true
	_running = false
	RunState.run_stats["battles_won"] += (1 if result == "win" else 0)

	# Sync hero HP back to RunState
	if result == "win":
		for i in range(min(heroes.size(), RunState.party.size())):
			RunState.party[i]["current_hp"] = heroes[i]["current_hp"]

	print("[BattleManager] Battle ended: " + result.to_upper())
	EventBus.battle_ended.emit(result)
	battle_finished.emit(result)

# ── SPEED CONTROL ─────────────────────────────────────────────────────────────

## Change battle speed. Valid values: 1.0, 2.0, 3.0
func set_battle_speed(speed: float) -> void:
	battle_speed = clampf(speed, 0.5, 5.0)
	EventBus.battle_speed_changed.emit(battle_speed)
