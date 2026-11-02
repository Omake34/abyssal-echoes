# Shared arena trial

Implemented November 2, 2026. Open **ARENA TRIAL** from the main menu, or run `res://scenes/battle/ArenaTrial.tscn` in Godot.

This is the first playable slice from the reference-analysis rebuild plan. It uses original procedural character drawings and the existing skill illustrations. Its encounters and tuning are our own implementation, not recovered reference-game constants.

## Play and compare

1. Choose **The breach** or **Crossfire** and an Archer loadout.
2. Click a hero or their card to select them. Keys 1–4 also select heroes.
3. Hold the left mouse button on a hero, drag onto a teal cell, and release to reposition. Drop onto another hero to swap places. A moving hero preview and highlighted cell show the destination. Escape, losing window focus, or releasing outside the deployment zone cancels the move. Selecting a hero and clicking an empty cell also works. The Warrior should usually start ahead of the ranged allies.
   Select a hero and click a skill in the right shelf to equip it. Each hero has three slots. Equipped shelf entries become active **Unequip** buttons; the equipped icon buttons on hero cards also show **UNEQUIP**. Hover skills for their actual effects. Incompatible and full-slot choices are disabled, while removal remains available during preparation. Equipment is locked during combat and preserved across resets and encounter changes.
   The tier picker offers tiers I, II, and III. Unequip the current version before equipping another tier of the same skill; different tiers of one family cannot stack. Higher tiers have stronger effect values and corresponding upgraded artwork. Default loadouts remain tier I.
4. Select **Begin battle**. Use Pause/Resume and 1×/2×/3× playback as needed.
5. Review damage, effective healing, and damage absorbed by shields. **Reposition** restores the chosen starting formation, health, and timers for another attempt.

The trial uses four fixed heroes and authored encounters. It reads base hero resources but never changes RunState, inventory, map progress, rewards, or save files. Main menu returns directly without saving trial state. Formation and loadout choices are local to this visit.

UI regions are stable while editing equipment: the header, controls, instructions, hero row, and footer reserve fixed heights. All four hero cards have equal-width bounds and three permanent skill-slot boxes. The skill shelf reserves its width and scrollbar; long messages and counters stay within their own regions, with full hero details available on hover. Only a real window resize changes the arena's available space. Empty/full layout review images are `art/arena_layout_empty.png` and `art/arena_layout_full.png`.

## Implemented rules

- A 16 × 7 shared board. One authoritative cell is used for occupancy, pathfinding, targeting, and range. Rendering interpolates between cells without moving simulation state.
- Four-direction breadth-first navigation around living units. Dead units release their cells. Nearest-opponent selection uses stable unit-ID tie-breaks.
- Melee range of 1 cell and ranged/healing reach of 4 cells. All timers advance in seconds at a fixed 0.05-second step. Action cadence uses hero speed; cooldowns are independent of that cadence.
- Warrior: nearby Challenge taunts enemies within 3 cells for 2 seconds, grants 18 shield, and has a 5-second cooldown. Every third strike uses double attack power.
- Archer presets: Piercing arrows can hit one additional enemy behind the original target at 60% power, within a narrow shot line and a maximum reach of 5.5 cells. The Ember preset replaces piercing: every fourth arrow applies a four-second burn dealing 7 damage per second. Custom equipment can combine both effects.
- Mage: every third spell deals 50% more magic damage.
- Cleric: Holy Aura restores 5% of allies' maximum HP at battle start. Mend restores 30 HP to an injured ally in reach and has a 3-second cooldown. Healing power is explicitly interpreted as a multiplier of 20 HP in this trial. Effective healing excludes overheal and cannot revive a dead unit.
- Damage subtracts the relevant defense, then shield, and is capped by remaining HP. Damage, healing, and absorbed shield are credited to their source. Existing burns can finish after the caster falls.
- Victory, defeat, and a 120-second stalemate limit stop the simulation. No rewards or progression are awarded.

## Code and validation

`scripts/battle/ArenaSimulation.gd` owns combat and preparation state. It has no autoload dependencies. `scenes/battle/ArenaBoard.gd` draws the world, interpolates actors, and handles placement. `scenes/battle/ArenaTrial.gd` owns controls, HUD, and the fixed-step accumulator. Local events drive feedback; the global `battle_ended` signal is intentionally not emitted because SceneManager would advance the saved run.

Twenty-one `ArenaAbilityData` resources under `resources/arena/abilities/` define seven families across three tiers. Definitions contain type, tier, family ID, activation, effect, counter, power, cooldown, geometry, duration, interval, compatibility, and icon. Seven `ArenaUnitProfile` resources define basic attacks, movement, and starting abilities. Edit these `.tres` files in Godot's Inspector to tune the effects. Descriptions and progress text read those values; cooldown dictionaries belong to units rather than the shared resources.

`SkillVisualStyle` supplies physical red, magic blue, and healing green to both the trial and legacy skill UI (legacy `support` displays as Healing). Type determines color. Tier determines frame weight, Roman badge, one/two/three rank marks, a second inset frame from tier II, and corner diamonds/glow for tier III. `SkillIcon` draws these marks over the existing art in reward cards, inventory, equipment, shops, and review galleries. Other type colors remain future work.

`ArenaEquipment` is the shared route for slot limits, duplicates, definition validation, compatibility, adding/removing abilities, and atomic loadout replacement. Trial presets, custom loadout restore, the shelf, and equipped-icon removal use these rules. Arcane Surge requires a magic basic attack; the other current abilities are available across classes. Profiles and the tiered abilities are an arena-specific schema, separate from the legacy `SkillData` resources and saved-run inventory.

`tests/arena_combat_test.tscn` passes **193 checks**. It covers legal placement and swaps, occupied-cell routing, changed first engagement when the frontline is reversed, melee/ranged reach, dead-unit behavior, taunt and shield, effective healing, cooldown units, spell/arrow counters, burn attribution, deterministic encounters, bounds/occupancy/range throughout complete fights, actual UI pause/reset/build controls, the menu entry, and unchanged run/meta save bytes. Mouse events dispatched through Godot's viewport also verify dragging, delayed commit until release, swapping, invalid/outside drops, Escape, focus loss, click jitter, character-head hit testing, retained click-to-place controls, and the combat placement lock. Equipment checks cover all 21 definitions, capacity, duplicates, cross-class use, compatibility, atomic failure, cooldown isolation, restore/lock behavior, combined piercing/burn, the real shelf/removal controls, and resource edits changing actual damage, counters, burn intervals, and tooltips. Both default encounter outcomes are checked against the earlier fixed implementation.

In an isolated project/user directory, the existing reward suite passes **46 checks** and the artwork suite passes **259 checks**. Rendered review images are `art/arena_preparation.png` and `art/arena_combat.png`.

The latest arena checks also verify all 21 definitions, increasing tier powers/art, consistent type colors, family stacking prevention, tier-picker controls, both shelf and icon unequip actions, and actual tier III damage. Artwork checks cover stronger frames, rank badges, palette consistency, and clearing old master glow when a card is reused. The nine-card visual comparison is `art/skill_tiers_preview.png`; export it through `res://tests/skill_art_review.tscn` with `-- --capture-tiers="ABSOLUTE_OUTPUT.png"`.

Layout regression checks compare the actual map rectangle/cell scale, shelf, four hero cards, slot rows, health fields, bars, toolbar, and message regions. They cover zero/one/three skills, tier III names, hero/tier selection, actual Equip/Unequip clicks, long messages and large statistics, paused/locked combat, and a 1600 × 900 window resize and restore. These reproduced the prior map zoom/panel-shift bug before the fix.

The drag/swap preview is rendered in `art/arena_drag_preview.png`. To reproduce it with Godot's renderer, launch the trial scene with `-- --capture-arena="ABSOLUTE_OUTPUT.png" --drag`.

The default formation finishes The breach in approximately 12.1 simulation seconds with piercing arrows. Crossfire with Ember Volley finishes in approximately 12.7 seconds and loses the Warrior. These are deterministic baseline observations, not a broad balance claim.

## Remaining work

The normal run still uses the old battle scene. Its formation, traits, and healing have not been silently changed by this prototype. The trial offers reusable catalog equipment rather than saved-run inventory consumption. It does not yet support all 35 legacy skill effects, crafting, persistent loadouts across visits, critical hits, evasion, enemy special abilities, or world obstacles/line-of-sight rules. Character art is procedural prototype art.

Next milestone: expand authored builds and establish the encounter/reward adapter and save compatibility before routing real map battles through the arena. Inventory-backed equipment needs an explicit adapter between the legacy skill schema and the arena definitions. Explicit merge/recast work remains a later milestone.
