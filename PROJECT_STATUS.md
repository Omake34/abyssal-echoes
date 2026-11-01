# PROJECT STATUS
## Abyssal Echoes: Void Weaver — Live Development Tracker

**Last Updated:** November 1, 2026
**Current Phase:** Phase 3 — Meta-Progression (Battle UX & Flow Polish)
**Overall Progress:** [##########] 100%

---

## CURRENT TASK
> **Skill Artwork Replacement**
> All 35 skills now have individual generated illustrations, including every upgrade tier and boss ability. Artwork is connected to reward cards, inventory and drag previews, equipment, shop purchases, Codex lists/details, and cast indicators.
> Primary files: `res://assets/skills/`, `res://scenes/ui/SkillIcon.gd`, `res://scenes/battle/SkillCard.gd`

---

## SKILL ARTWORK UPDATE — November 1, 2026

- Created 35 separate dark fantasy illustrations with the built-in ImageGen tool. Each image depicts the skill's action, with stronger visual effects for upgraded tiers. Runtime images are 512 × 512 PNGs (about 16 MB total); full-size original outputs remain in the ImageGen library.
- Assigned every skill resource an `icon_path`. `SkillData.get_icon_texture()` and the shared `SkillIcon` control keep images consistent across the UI.
- Replaced the reused 3D skill models with artwork in cards, inventory, equipped skill slots, the shop, Codex, and cast indicators. The old model assets remain available for other uses.
- Restored visible skill names and tier labels on reward cards. Hover descriptions, drag/drop, equipment tooltips, card selection, and reward claiming remain functional.
- Added an interactive Godot gallery at `res://tests/skill_art_review.tscn`, plus rendered previews in `art/`.
- Saved the complete prompt set and skill/image mapping in `assets/skills/art_manifest.json`.

**Changed files [MODIFIED - needs test]:** all 35 `resources/skills/*.tres` files; `SkillData.gd`; `SkillCard.gd` and `.tscn`; `InventorySlot.gd`; `CombatantUI.gd`; `BattleScene.gd`; `ShopScene.gd`; `CodexScene.gd` and `.tscn`; `SkillVFX.gd`. Automated checks and rendered gallery review pass; a full manual run remains pending.

**Added:** `assets/skills/` illustrations and manifest, `scenes/ui/SkillIcon.gd`, skill artwork smoke test and review scenes under `tests/`, `tools/PrepareSkillArt.gd`, and preview images under `art/`.

**Validation:** Godot 4.7.2 import succeeds. `SKILL ART: 252 checks, 0 failures` covers every texture, distinct paths, card names/art, inventory, equipment, shop, Codex, and cast-effect cleanup. The reward-flow regression suite still reports `46 checks, 0 failures`. Rendered cards and the labelled contact sheet have been visually inspected.

**Suggested commit message:** `Replace all skill visuals with individual dark fantasy illustrations`

---

## SESSION UPDATE — November 1, 2026

Continued the existing battle/reward polish task and opened the project in the installed Godot 4.7.2 editor.

- Unclaimed rewards now save their node, three skill choices, and encounter gold. Continue resumes the reward screen after a victory and returns to the map after a claim.
- Checking the team preserves reward choices. New runs clear pending reward state.
- Claims retain the reward when inventory is full and prevent double-click duplication. Skip Skill provides a way to continue without a skill.
- Reward gold displays the current encounter's earnings. Treasure uses its own heading and does not offer a fake battle through Check Team.
- Renamed the legacy data class in `MapData.gd` from `MapNode` to `MapData`, resolving a global class collision found during a fresh import.

| File | Status | Verification |
|------|--------|--------------|
| `autoloads/RunState.gd` | [MODIFIED - needs test] | Save/load, legacy saves, claim/skip, full inventory, and new-run resets pass automated checks; manual playtest pending |
| `autoloads/SceneManager.gd` | [MODIFIED - needs test] | Resume routing and immediate victory checkpoint pass automated checks; manual playtest pending |
| `scenes/battle/RewardScene.gd` | [MODIFIED - needs test] | Team round trip, stable choices, treasure, and duplicate clicks pass automated checks; visual review pending |
| `scenes/battle/BattleScene.gd` | [MODIFIED - needs test] | Return to Rewards routing passes automated check; manual playtest pending |
| `scripts/map/MapData.gd` | [MODIFIED - needs test] | Fresh import and map transitions pass; manual playtest pending |
| `tests/RewardFlowTest.gd`, `tests/reward_flow_test.tscn` | [ADDED] | 46 checks pass in an isolated project copy with a separate user data directory |

**Validation:** Godot headless editor import exits 0; reward-flow runtime suite reports `46 checks, 0 failures`. The inventory-full warning is expected in the rejection test. Desktop screenshot capture timed out, so visual inspection remains pending.

**Open work:** Manually play a complete run and inspect the reward buttons at small window sizes. The existing gameplay balance and late-game boss behavior were not covered by this focused suite.

**Suggested commit message:** `Fix reward persistence, claim handling, and map class collision`

---

## RECENT UPDATES (Uncommitted — June 2026)

### Battle & Formation
- **Expanded Battle Grid** — Formation grew from 3×2 (6 slots) to 4×3 (12 slots) for heroes and enemies.
- **Responsive Slot Sizing** — Battle grids and combatant cards scale with window size (`BattleScene.gd`, `BattleSlot.gd`, `CombatantUI.gd`).
- **Auto Formation** — One-click placement by role (front/back) using `preferred_row` and class (warrior/captain → front).
- **Party Buff Panel** — Aggregated synergy display across the whole party with tooltips during prep.
- **Skill Card UI** — Simplified reward card layout; front labels removed in favor of model + back-panel hover.

### Reward & Navigation Flow
- **Pending Reward State** — `RunState.pending_reward_node_id` tracks battles won before a reward is claimed.
- **Reward ↔ Battle Loop** — Back button on reward screen returns to battle; battle shows **RETURN TO REWARDS** when a reward is pending.
- **Scene Back Buttons** — Hero Select (cancels run, deletes save → Main Menu) and Map View (→ Main Menu).

### Meta & Codex
- **Codex Tier Filters** — Skills tab filters by All / T1 / T2 / T3; all skills visible for reference.

---

## COMPLETED (PHASE 3 - META PROGRESSION)
- **Talent Tree UI** — Permanent stat upgrade screen with scaling costs.
- **Meta Currency System** — Reward coins based on performance and spend them on buffs.
- **Persistent Buffs** — Permanent HP, ATK, and Speed bonuses applied to all heroes.
- **Starting Advantages** — "Bounty Hunter" talent for increased starting gold.
- **Global Codex** — Library scene to view all discovered skills, heroes, and enemies.
- **Hero Unlocks** — Assassin and Captain classes unlockable via Darkworld Coins.
- **Advanced Bosses** — 3 new boss types with unique mechanics and guaranteed drops.
- **Skill Synergies** — Dynamic bonuses for equipping combinations of skill types.
- **Polish & Balancing** — Implemented Status Effect system (Burn, Bleed, Stun) and tuned all stats.

---

## COMPLETED (PHASE 2 - VERTICAL SLICE)
- **Main Menu** — Redesigned with premium aesthetic and fully functional buttons.
- **Hero Selection** — Functional draft screen for starting party of 4.
- **Procedural Map** — Procedural generation with branching paths and node routing.
- **Tactical Battle** — Tick-based combat with VFX, floating numbers, and hit flashes.
- **Formation Logic** — Drag-and-drop 4×3 grid with persistent slot saving and auto-formation.
- **Inventory Management** — Equipment slots, auto-equip button, and restricted auto-merging.
- **Save/Load System** — JSON-based persistence with checkpointing at every scene transition.
- **End-of-Run Flow** — Victory and Defeat scenes with statistics and rewards.

---

## IN PROGRESS (PHASE 3)
| File | Status | Notes |
|------|--------|-------|
| `BattleScene.gd` | [UPDATED] | 4×3 grid, auto-formation, party buff panel, responsive layout |
| `BattleSlot.gd` | [UPDATED] | Dynamic slot sizing for expanded grid |
| `CombatantUI.gd` | [UPDATED] | Responsive portrait, HP bar, and skill icons |
| `RewardScene.gd` | [UPDATED] | Back-to-battle flow; clears pending reward on continue |
| `RunState.gd` | [UPDATED] | `pending_reward_node_id` for mid-reward navigation |
| `SceneManager.gd` | [UPDATED] | Sets pending reward flag on battle victory |
| `HeroSelectScene.gd` | [UPDATED] | Back button cancels run and returns to Main Menu |
| `MapView.gd` | [UPDATED] | Back button returns to Main Menu |
| `CodexScene.gd` | [UPDATED] | Library + tier filters (All / T1 / T2 / T3) on Skills tab |
| `SkillCard.gd` | [UPDATED] | Simplified hover card (front labels removed) |
| `TalentTree.gd` | [COMPLETED] | Persistent stat upgrade logic |
| `SynergyManager.gd` | [COMPLETED] | Skill combination bonus logic |
| `BattleManager.gd` | [COMPLETED] | Status effects and final balancing |

---

## PHASE 3 CHECKLIST — Meta-Progression
- [x] Talent Tree UI — spend coins on HP/ATK/Speed buffs
- [x] Meta Currency — reward coins based on run performance
- [x] Global Codex — view discovered items and lore
- [x] Hero Unlocks — logic for Assassin and Captain classes
- [x] 3 Advanced Bosses — for high-difficulty runs
- [x] Expanded battle grid — 4×3 formation with responsive slot sizing
- [x] Auto formation — role-based one-click placement
- [x] Party buff panel — aggregated synergy display in battle prep
- [x] Reward flow — back to battle before claiming; pending reward state
- [x] Scene navigation — back buttons on Hero Select and Map View
- [x] Codex tier filters — filter skills by tier in the library

---
