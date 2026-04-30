# PURPOSE: EventBus — Global signal hub for all cross-scene communication.
# All signals that need to travel between different scenes are declared here.
# HOW TO USE:
#   Emit:  EventBus.hero_died.emit(hero_data)
#   Listen: EventBus.hero_died.connect(_on_hero_died)
# Never use get_node() to talk between scenes — use EventBus instead.

extends Node

class_name EventBusClass  # Accessed as the autoload "EventBus"

# ── BATTLE SIGNALS ────────────────────────────────────────────────────────────

## Emitted when a battle begins
signal battle_started()

## Emitted when a battle ends. result is "win" or "lose"
signal battle_ended(result: String)

## Emitted each simulation tick (used for UI refresh)
signal tick_processed()

## Emitted when any combatant dies
signal hero_died(hero: Dictionary)
signal enemy_died(enemy: Dictionary)

## Emitted when a skill is cast
signal skill_cast(caster: Dictionary, skill: SkillData, targets: Array)

## Emitted when damage is dealt (for floating damage numbers)
signal damage_dealt(target: Dictionary, amount: int, is_crit: bool)

## Emitted when healing is applied
signal healing_applied(target: Dictionary, amount: int)

# ── INVENTORY / ITEM SIGNALS ──────────────────────────────────────────────────

## Emitted when a new item is added to inventory
signal item_acquired(item: Resource)

## Emitted when an item is removed (salvaged, used, sold)
signal item_removed(item: Resource)

## Emitted when a skill is equipped to a hero
signal skill_equipped(hero: Resource, skill: Resource, slot: int)

## Emitted when a merge is completed
signal merge_completed(result_skill: Resource)

# ── RUN / MAP SIGNALS ─────────────────────────────────────────────────────────

## Emitted when the player selects a map node to travel to
signal map_node_selected(node_id: String)

## Emitted when a node's encounter is fully resolved
signal node_completed(node_id: String)

## Emitted when the full run ends (victory or defeat)
signal run_ended(victory: bool, stats: Dictionary)

## Emitted when gold changes
signal gold_changed(new_amount: int)

# ── UI SIGNALS ────────────────────────────────────────────────────────────────

## Emitted to request a scene transition
signal scene_change_requested(scene_path: String)

## Emitted when battle speed is toggled
signal battle_speed_changed(new_speed: float)

## Emitted to show a tooltip
signal tooltip_requested(title: String, description: String)
signal tooltip_hidden()
