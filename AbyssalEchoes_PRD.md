# Abyssal Echoes: Void Weaver

## Product Requirements Document

**Version 3.0 | November 9, 2026 | Solo development | Godot + Blender**

This revision replaces the outdated April prototype plan. It separates the local implementation from proposed work and defines a small, testable next release. It does not certify release readiness or authorize a full 3D conversion.

## 1. Product vision

Lead four echo-bound heroes through the abyss. Choose a route, build complementary skill loadouts, arrange the party, and watch those decisions play out in an automatic arena battle. Rewards create the next meaningful choice; defeat teaches the player how to build a better party.

The central promise is **“Build the party, set the formation, understand the outcome.”** Dark fantasy atmosphere supports this promise; readable combat takes priority over spectacle.

| Product choice | Direction |
| --- | --- |
| Genre | Single-player roguelite tactical auto-battler |
| Combat | Real-time automatic combat with preparation, pause, and speed controls |
| Audience | Players who enjoy party builds and positioning without action-game input demands |
| Runtime | Godot 4.x with GDScript; retain the current Compatibility renderer during the next milestone |
| Art authoring | Blender for original models, reusable rigs, animation, props, and rendered images |
| Presentation | Current 2D arena; proposed next step is Blender-rendered sprites and scenery with a consistent fixed camera |
| First validation platform | Windows, keyboard and mouse |
| Later platform goals | Linux and macOS after separate export and input validation |
| Distribution | Playtest build first; itch.io and eventual Steam remain goals |
| Commercial decisions | Price, release date, and store requirements remain undecided |

New presentation and release targets below are planning proposals. Existing mechanics and saves remain the baseline until a separately implemented change passes its acceptance criteria.

## 2. Design pillars

1. **Preparation changes the fight.** Placement, range, skill compatibility, and party combinations must have visible consequences.
2. **The player can read the fight.** Distinct silhouettes, clear targets, HP, status effects, and skill feedback explain success and failure.
3. **Rewards develop a build.** Skills should offer useful choices, with clear ownership, tier, restrictions, and consequences.
4. **A run respects the player's progress.** Continue, inventory transfers, and reward claims must survive navigation and reloads without duplication or loss.
5. **A small art kit goes a long way.** Reuse Blender rigs, materials, lighting, and modular props while keeping units visually distinct.

Time Walker: Dark World is a design reference for positioning and build decisions. Use original assets, writing, code, and tuning. Reference behavior is not automatically a requirement.

## 3. Current implementation baseline

Status here reflects source inspection and previously recorded checks, not fresh gameplay testing in this documentation revision.

| Area | Current state | Remaining work |
| --- | --- | --- |
| Normal-run battles | `BattleScene` uses `RunArenaSimulation` and the shared arena; New Run and Continue use this route | Complete a manual run and tune balance |
| Party and content | Four-hero party flow; six class resources and 35 skill resources; saved-party adapter retains stats, skills, and wounded HP | Validate understandable and useful builds across classes |
| Positioning | Shared 16 x 7 board, six preparation columns, movement/range, drag placement and swaps | Check pathing and readability in crowded fights |
| Equipment | Inventory-backed equip/unequip with class and capacity rules; formation and loadouts saved | Manual usability and edge-case review |
| Map and progression | Map, shop, rewards, end screens, talents, and Codex already exist | End-to-end acceptance and economy tuning |
| Reward persistence | Pending choices persist; claim/skip and duplicate settlement have regression coverage | Full-run and reload playtests |
| Crafting | Legacy `MergeSystem` code exists; player-facing merge/recast workflow is not complete | Design and implement a deliberate transaction flow later |
| Skill artwork | 35 distinct illustrations already integrated | Preserve their identity and improve consistency where needed |
| Character/environment art | Arena presentation exists; production Blender art pipeline is not established | One representative art pilot |
| Blender tooling | Blender 5.2.3 LTS and Blender Development 0.0.31 connected through VS Code; script execution and debugger attachment verified | Asset authoring, rendering/export, and Godot integration |

The earlier isolated validation milestone recorded 98 run-arena, 46 reward-flow, 193 arena-fixture, 259 artwork, and 110 party-adapter checks passing. These are regression evidence, not proof of balanced combat or a finished game. See [test instructions](tests/README.md) and [arena migration decisions](docs/ARENA_MIGRATION.md).

## 4. Player journey and functional requirements

### 4.1 Run loop

**New Run / Continue → party and route decisions → battle preparation → automatic battle → reward → next node → victory or defeat → progression.** Shops and other existing node types fit into the route. Do not add new node types before validating the current loop.

### 4.2 Preparation

- Show party HP, equipped skills, inventory, and readable enemy information before battle.
- Support drag-to-place, drag-to-swap, and click-to-place. Invalid releases, Escape, and focus loss cancel safely.
- Keep destination and swap feedback. Do not restore the rejected “Release to place” hint.
- Manual and automatic equipment must follow the same ownership, compatibility, and slot rules.
- Preserve current hero-specific slot limits; the fixture's three slots are not a reason to overwrite saved-party limits.
- Equip/unequip must not resize the map, hero panels, or skill shelf. Actual window resizing may change layout.
- Lock equipment and formation once combat starts. Team inspection from pending rewards must not restart the battle.

### 4.3 Combat

- One authoritative simulation determines cells, movement, range, targeting, cooldowns, damage, healing, status effects, and results.
- Retain pause and 1x / 2x / 3x speed controls. Presentation must remain readable at all speeds.
- Render animation from simulation events. An animation must never decide whether damage occurred or delay the next simulation action.
- Keep existing skill IDs, effects, class traits, and carried HP when changing visuals.
- Current migration tuning uses half-second legacy cooldown ticks and a 20-HP healing base. Treat these as balance inputs to test, not settled design truths.
- Show deaths and battle completion clearly; settle each result exactly once.

### 4.4 Rewards and saves

- Preserve generated reward choices across reloads and team inspection.
- Claiming consumes the pending reward once. A full inventory must leave the reward available and explain the problem.
- Provide an explicit skip option. Award encounter gold consistently without double claims.
- Continue must return to the correct preparation, map, or pending reward state.
- Art changes must not invalidate skill IDs, formation cells, or existing saves.

### 4.5 Proposed crafting milestone

Crafting follows the stable-run milestone; it is not a prerequisite for the art pilot.

- **Merge proposal:** three unequipped copies of the same skill ID and tier produce the explicitly defined next-tier skill, capped at tier III for the first implementation.
- **Recast proposal:** three eligible unequipped skills of the same tier produce another skill of that tier. Output pool, exclusions, and cost must be specified before implementation.
- Preview exact merge output and recast possibilities before confirming. Cancel changes nothing.
- Validate distinct inventory items, eligibility, output availability, and capacity before consuming anything. Commit inputs and output together and save once.
- Reopening a preview must not reroll a committed result. Failed operations must preserve all inputs.
- EX/tier IV recipes remain deferred until recipe content, UI, and combat behavior are explicitly scoped. Existing helper code is not evidence that EX crafting is ready.

## 5. Godot + Blender visual direction

### 5.1 Proposed first route: rendered 3D art in the 2D arena

Use Blender to model and animate, render transparent sprites and environment layers, then display them through the existing Godot arena presentation. This gives the game dimensional characters, consistent lighting, and reusable art production while preserving its cell-based combat and UI.

This is a proposed art direction, not a claim that the renderer already supports animated sprites. The first pilot includes the small presentation adapter required to display them.

A real-time 3D arena remains a later option. It requires a separate decision after comparing readability, performance, asset workload, and picking/placement behavior. It would retain the same simulation; it must not silently become a combat rewrite.

### 5.2 Visual language

- **World:** ruined ritual chambers, dark stone, worn metal, spectral cloth, and restrained abyssal glow.
- **Units:** readable class silhouettes at actual board size; broad armor for the Warrior, bow profile for the Archer, staff or spell shape for the Mage, and a distinct healing symbol for the Cleric.
- **Palette:** dark neutral scenery, warm selection accents, and controlled teal/violet atmosphere. Physical red, magic blue, and healing green retain their current UI meaning.
- **Priority:** selected unit and destination first, units/HP second, combat effects third, scenery last.
- Existing illustrated skill cards remain the UI art system. Blender work should complement them.
- Avoid pixelation filters until a visual comparison establishes that they improve the intended style.

### 5.3 First art pilot

Build only one Warrior, one basic enemy, and a small arena floor/prop kit. Capture them in the real battle view before producing the rest of the roster.

Provisional character requirements: idle, move, attack, hit, and death animations; four rendered facing directions; one consistent orthographic camera and lighting rig. Asymmetric equipment must remain readable when facing changes. Start at 256 x 256 pixels per frame and judge the downscaled result in Godot before fixing production resolution or frame counts.

Pilot acceptance:

- Units remain identifiable at 1280 x 720, including overlapping effects and small HP bars.
- Feet stay anchored to their simulation positions; animation frames do not jump or change apparent scale.
- Transparent edges are clean; shadows do not become opaque rectangles.
- Selection, drag preview, swaps, pause, death, and speed changes work with the new visuals.
- Attack feedback occurs at the simulation event; effects finish cleanly or cancel on death/reset.
- One source-model edit can be regenerated and imported without manually repairing paths or scene wiring.
- A side-by-side capture demonstrates improvement over the current presentation before expanding the art set.

## 6. Asset pipeline and technical boundaries

| Responsibility | Tool / owner |
| --- | --- |
| Models, rigs, animation, render camera and lighting | Blender source files |
| Repeatable render/export helpers | Blender Python under `tools/blender/` |
| Combat, progression, UI, audio, input, saves | Godot / GDScript |
| Character and environment runtime images | Exported PNG atlases/layers imported into Godot |
| Optional future real-time models | Explicit `.glb` exports with a separate Godot presentation scene |

Proposed organization, to create during the art milestone:

- `art/source/blender/`: editable `.blend` files and source textures; add `.gdignore` so Godot does not auto-import the source collection.
- `assets/characters/`: runtime sprites and animation metadata.
- `assets/environments/`: exported floor and prop imagery.
- `assets/models/`: only if a real-time 3D pilot is approved.
- `art/previews/`: comparison renders and contact sheets.
- `tools/blender/`: documented generation scripts; never embed machine-specific executable paths in reusable scripts.

Each asset needs a stable ID, source path, export path, author/license record, camera/render preset, dimensions, pivot, and animation names/timing. Regeneration replaces only that asset's outputs. Review changes in Godot at gameplay scale, not only in Blender's viewport.

The VS Code connection launches and debugs Blender scripts; it does not automatically synchronize assets with Godot. Follow the [local Blender workflow](docs/BLENDER_WORKFLOW.md).

For a future 3D pilot, use explicit glTF/GLB exports as the reproducible handoff. Godot also supports direct `.blend` imports by invoking Blender's glTF exporter, but that introduces a local Blender dependency. Validate materials, scale, axes, and animation after import. See the [official Godot format guidance](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html).

Keep Blender Python limited to authoring tools; runtime stays GDScript. This document proposes no new Godot plugins or paid assets. Preserve the simulation/presentation separation in `ArenaSimulation`, `RunArenaSimulation`, and `ArenaBoard`; keep progression settlement in the existing run integration.

## 7. Usability, audio, and quality targets

These are proposed acceptance targets, not measurements already achieved.

- Validate the UI at 1280 x 720 and 1920 x 1080. Critical buttons, text, and selected-unit information must remain visible.
- Pair skill colors with names, symbols, and tier marks; color alone must not communicate meaning.
- Use concise tooltips for restrictions, cooldowns, targets, and effects. Explain unavailable actions.
- Give attack, heal, selection, reward, victory, and defeat distinct audio cues. Limit repeated combat sounds at high speed.
- Provide music/SFX volume controls and a reduced-flash option before public release; these are release requirements to implement and verify.
- Target 60 FPS at 1280 x 720 in the busiest planned encounter at 3x speed. Record hardware, build, encounter, frame-time captures, and texture memory before setting minimum specifications.
- Profile sprite atlas memory and VFX counts before expanding animation directions or resolutions.
- For the first external playtest, aim for at least four of five players to equip a skill, place a hero, start battle, and claim a reward without verbal help. Ask each to explain one reason for a win or loss.

## 8. Milestones and exit criteria

Milestones are sequential acceptance gates, not calendar promises. Do not label a phase complete merely because its screens or scripts exist.

| Milestone | Deliverable | Exit criteria |
| --- | --- | --- |
| M0 — Stable current run | Current v0.2 gameplay validated end to end | Complete victory and defeat routes; test Continue before battle and during pending rewards; verify wounded HP, shop/inventory, full bag, and exactly-once settlement; relevant isolated regressions pass |
| M1 — Blender art pilot | One hero, one enemy, one arena kit and repeatable render preset | All pilot criteria in section 5 pass; compare in-game captures and record production effort/performance |
| M2 — Cohesive playable slice | Apply the accepted style to the four core classes and one bounded encounter set | One complete playable route through existing systems, including a normal fight, elite, and boss; no missing visual feedback; external onboarding target met |
| M3 — Build depth | First merge flow, followed by separately validated recast if useful | Inventory transactions are safe; previews are clear; at least two contrasting builds succeed without one mandatory combination |
| M4 — Release candidate | Expand accepted art to retained content, finish settings/audio, package Windows build | Fresh-machine launch, save/Continue, credits/licenses, performance, and full-run checklist pass; no known progress-loss defects |

The six existing classes and 35 skills are retained. M2 limits new art workload; it does not delete existing content or declare advanced classes release-ready. Additional biomes, classes, or skill counts require evidence that the current pool is understandable and enjoyable.

## 9. Scope limits and risks

Out of scope for the next slice: multiplayer, open-world exploration, free camera rotation, procedural 3D terrain, cinematic dialogue, new class trees, EX crafting, and a full real-time 3D conversion.

| Risk | Response / decision rule |
| --- | --- |
| Blender work overwhelms a solo developer | Measure the first character's production effort; reuse rigs/materials and reduce directions before expanding the roster |
| Pre-rendered assets consume too much memory | Profile atlases; reduce resolution, frame count, or directions while preserving readability |
| Attractive scenery hides tactics | Reduce contrast, prop height, and VFX overlap; keep destination cells and unit silhouettes readable |
| Visual changes alter combat outcomes | Consume simulation events only; verify existing regression fixtures and saved-run behavior |
| Crafting or rewards lose/duplicate items | Atomic transactions, explicit rejection paths, reload checks, and isolated test saves |
| Historical status claims mislead planning | Treat newest source and recorded test evidence as baseline; distinguish implemented, verified, and proposed |
| Platform scope grows too early | Validate Windows first; make other platforms separate release gates |

## 10. Immediate next actions

1. Manually validate a full current run and record gameplay defects before adding systems.
2. Capture the current arena at the two target resolutions as a visual baseline.
3. Create a Blender camera/lighting preset and one Warrior silhouette study.
4. Render a small animation sample and integrate it through a presentation-only pilot.
5. Compare readability, anchor stability, memory, and frame time in a real encounter.
6. Decide whether to expand the rendered-sprite pipeline or revise the art approach.
7. Implement the next milestone only after its predecessor's exit criteria pass.

Open decisions: final character style, camera angle, production frame counts, target hardware, intended run duration, recast pool/cost, and commercial release details. Resolve them through the relevant pilot or playtest instead of treating provisional numbers as fixed requirements.

## 11. Working references

- [Project status and historical verification](PROJECT_STATUS.md)
- [Production arena migration](docs/ARENA_MIGRATION.md)
- [Arena fixture and interaction rules](docs/ARENA_TRIAL.md)
- [Tests and save isolation](tests/README.md)
- [Blender connection and script workflow](docs/BLENDER_WORKFLOW.md)

**Revision 3.0:** Reconciled the PRD with the November arena implementation, replaced unsupported completion claims, and introduced a proposed Godot + Blender art pipeline with acceptance gates. No gameplay or asset conversion was implemented as part of this revision.
