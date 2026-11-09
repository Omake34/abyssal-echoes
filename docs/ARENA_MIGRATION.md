# Battle v0.2 integration

The requested destination is one player-facing battle scene, using the shared arena for map battles, elites, bosses, and reward-screen team inspection.

## Requirements and resolution

| Requirement | Integration approach |
| --- | --- |
| Actual saved party, including advanced classes | Build arena units from RunPartyAdapter snapshots, retaining skill resources, stats, wounded HP, and slot limits. |
| Every owned skill | Execute the existing SkillData effect definitions in the arena, with movement and range. Keep original resource IDs and tiers. |
| Existing and new formations | Store arena cells separately and migrate old grid slots when no arena placement exists. |
| Inventory ownership | Move one item per equip or unequip, enforce class and slot restrictions, and reject removal when the bag is full. |
| Map encounters | Use RunEncounterAdapter once when entering preparation. |
| Results and saves | Commit HP, kill gold, drops, and stats once before emitting the existing battle-ended signal. Pending rewards prevent replay. |
| Arena presentation | Reuse the board, drag/swap input, fixed UI regions, skill artwork, and type/tier styling. |
| One battle entry | Keep BattleScene as the normal route and remove the standalone trial menu entry. The authored trial remains a test fixture. |
| Verification | Import and run integration, reward, party, artwork, and arena checks in an isolated project and save directory. |

## Gameplay decisions

Owned skills retain their effect values and resource identity. Legacy cooldown ticks become half-second world timers. Healing multipliers use the arena's 20-HP base. Offensive skills require a target in range, and area skills affect targets within that reach. Hero traits use the arena's spatial rules. The existing deterministic trial remains a regression fixture for the original arena mechanics.

## Verified result

Implemented November 5, 2026. BattleScene now loads the v0.2 arena for normal run battles and reward-screen team checks. The menu offers the normal New Run and Continue routes. The former standalone trial scene lives at `tests/arena_fixture.tscn` for regression checks.

Validation in an isolated project and user-data directory passed 98 run-arena checks, 46 reward-flow checks, 193 original arena checks, 259 artwork checks, and 110 saved-party checks. Tests cover all 35 effect resources, all six classes, normal/elite/boss encounters, save/load placement, inventory capacity and transfers, combat equipment locking, pause, limited uses, status expiration, and duplicate result settlement. A full manually played run and broad balance tuning remain open.

Warrior Taunt uses the arena Challenge range, shield, and cooldown. Archer Pierce uses the arena's shot-line geometry and secondary damage. Mage Arcane Surge counts spells and magic basic attacks. Holy Aura heals living allies at battle start. Captain defense aura and Assassin critical bonus now execute from the saved hero trait.

Suggested commit message — `Replace legacy run battles with the v0.2 shared arena`.

