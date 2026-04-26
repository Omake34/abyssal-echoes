# 📊 PROJECT STATUS
## Abyssal Echoes: Void Weaver — Live Development Tracker

**Last Updated:** April 2026  
**Current Phase:** Phase 1 — Core Systems  
**Overall Progress:** ▓▓░░░░░░░░ 20%

---

## 🎯 CURRENT TASK
> **Phase 2 — Map & Navigation: MapNode.tscn**
> Create interactive, clickable nodes for the branching path system.
> File: `res://scenes/map/MapNode.tscn`

---

## ✅ COMPLETED
- **Mini-Demo 1: Signals** — Successfully built a button that updates a label via signals.
- **Mini-Demo 2: Resources** — Created a custom `HeroData` resource and a scene that loads/displays it.
- **Mini-Demo 3: Reactive UI** — Implemented a setter-based reactive HP bar.
- **Mini-Demo 4: Tweens** — Created smooth motion and fade effects using `create_tween()`.
- **Mini-Demo 5: Save/Load** — Persisted player data to a JSON file using `FileAccess`.
- **Mini-Demo 6: Grid & Drag-and-Drop** — Built a 3×2 formation grid with functional item dragging.
- **Mini-Demo 7: Singletons** — Implemented an Autoload to share data across scene changes.
- **Phase 0 Capstone: Baby Battle** — Successfully ran a automated combat loop using Resources.
- **Phase 1 Core: Battle System** — Built the `BattleManager` simulation and the visual `BattleScene`.

---

## 🔧 IN PROGRESS
| File | Status | Notes |
|------|--------|-------|
| `BattleManager.gd` | [READY] | Logic foundation is complete |
| `project.godot` | [WORKING] | Config set up |
| `AI_RULES.md` | [WORKING] | Rules established |
| `PROJECT_STATUS.md` | [WORKING] | This file |

---

## 🔲 PHASE 0 CHECKLIST — Learn Godot
- [ ] Watch Brackeys Godot 4 Beginner Tutorial
- [ ] Complete official "Your First 2D Game" tutorial
- [x] Mini-Demo 1: Button → Signal → Label update
- [x] Mini-Demo 2: HeroResource with stats, load and print
- [x] Mini-Demo 3: Control node panel that updates on variable change
- [x] Mini-Demo 4: Sprite that slides + fades via Tween
- [x] Mini-Demo 5: Save/load a dictionary to JSON (FileAccess)
- [x] Mini-Demo 6: 3×2 GridContainer with draggable items
- [x] Mini-Demo 7: Singleton (Autoload) that stores a score, read from 2 scenes
- [x] Baby Battle Prototype (throwaway): 2 heroes vs 1 enemy, text log

**Phase 0 Exit Criteria:** Baby Battle Prototype runs. You understand scenes, signals, resources, autoloads.

---

## 🔲 PHASE 1 CHECKLIST — Core Systems
*(Locked until Phase 0 complete)*
- [ ] BattleManager.gd — tick-based simulation loop
- [ ] Hero.gd + HeroData resource
- [ ] Skill.gd + SkillData resource
- [ ] Enemy.gd + EnemyData resource
- [ ] BattleScene.tscn — full visual battle
- [ ] FormationScreen.tscn — 3×2 drag-and-drop grid
- [ ] InventoryScreen.tscn — view, equip, salvage
- [ ] HUD.tscn — HP bars + speed toggle
- [ ] PostBattleSummary.tscn — results screen
- [ ] 2 hero classes: Warrior + Archer
- [ ] 10 skills as .tres resources
- [ ] 2 enemy types

**Phase 1 Exit Criteria:** Single fight, start to finish, is playable and fun.

---

## 🔲 PHASE 2 CHECKLIST — Vertical Slice
*(Locked until Phase 1 complete)*
- [ ] MapScene.tscn — 5-node linear path
- [ ] ShopScene.tscn
- [ ] EventScene.tscn + 5 event cards
- [ ] Merge system (3x Tier I → Tier II)
- [ ] Save/Load run state
- [ ] 20 total skills
- [ ] 1 boss encounter

---

## 📡 EVENTBUS SIGNALS REGISTRY
*(Update this every time a new signal is added to EventBus.gd)*

| Signal | Parameters | Emitted By | Listened By |
|--------|-----------|------------|-------------|
| `battle_started` | none | BattleManager | HUD, BattleScene |
| `battle_ended` | `result: String` | BattleManager | RunState, BattleScene |
| `hero_died` | `hero: HeroData` | Hero | BattleManager, HUD |
| `skill_cast` | `hero: HeroData, skill: SkillData` | Hero | BattleScene (VFX) |
| `damage_dealt` | `target, amount: int` | Skill | HUD, BattleScene |
| `item_acquired` | `item: ItemData` | RunState | InventoryScreen |
| `run_ended` | `victory: bool` | RunState | MetaScreen |

---

---

## 📚 DEMO GUIDES

### Mini-Demo 1: Signals
**Goal:** Understand how nodes communicate.
- **Scene:** `res://scenes/demos/demo_signals.tscn`
- **Mechanism:** The `Button` node has a built-in `pressed` signal. This signal is connected to the root `DemoSignals` node's `_on_signal_button_pressed` function.
- **Code Snippet:**
  ```gdscript
  func _on_signal_button_pressed() -> void:
      status_label.text = "Signal received!"
  ```
- **How to Run:** In Godot, open the scene and press `F6` (Run Current Scene).

---

### Mini-Demo 2: Resources
**Goal:** Learn how to use `Resource` to separate data from logic.
- **Script:** `res://scripts/heroes/HeroData.gd` (defines the structure).
- **Instance:** `res://resources/heroes/warrior.tres` (holds actual data like HP: 150).
- **Scene:** `res://scenes/demos/demo_resources.tscn` (loads the resource and prints it).
- **Why?** This is how we'll build 100+ different skills and heroes without creating 100+ scenes.
- **How to Run:** Open the scene and press `F6`.

---

### Mini-Demo 3: Reactive UI
**Goal:** Automate UI updates when data changes.
- **Scene:** `res://scenes/demos/demo_reactive.tscn`
- **Mechanism:** Uses a variable **setter** (`set(value)`). When `current_health` is modified, it automatically calls `update_ui()`.
- **Why?** In combat, many things (poison, heals, hits) will change HP. We don't want to hunt down every UI element manually; the data should drive the UI.
- **How to Run:** Open the scene and press `F6`. Click buttons to see the bar and text react.

---

### Mini-Demo 4: Tweens
**Goal:** Master "Juice" and smooth animations.
- **Scene:** `res://scenes/demos/demo_tweens.tscn`
- **Mechanism:** Uses `create_tween()`. Unlike the old `Tween` node, this is a code-first approach that is much more flexible.
- **Key Methods:**
  *   `.tween_property()`: Animates any property (position, scale, color).
  *   `.set_trans()`: Changes the "vibe" (Springy, Bounce, Linear).
  *   `.set_parallel()`: Decides if the next animation happens *with* the current one or *after* it.
- **How to Run:** Open the scene and press `F6`. Click the button to watch the blue box dance.

---

### Mini-Demo 5: Save/Load (JSON)
**Goal:** Persist data between game sessions.
- **Scene:** `res://scenes/demos/demo_save.tscn`
- **Mechanism:**
  1.  **Dictionary**: Collect data into a `{key: value}` map.
  2.  **JSON.stringify**: Turn the map into a text string.
  3.  **FileAccess**: Open a file at `user://` and write the string.
  4.  **JSON.parse**: Turn the text string back into a map when loading.
- **Why?** Roguelites need to save "Meta-Progression" (unlocks, currency) and "Run State" (current health, floor number).
- **How to Run:** Open the scene and press `F6`. Type a name, add some score, click **Save**, close the game, then open it again and click **Load**.

---

### Mini-Demo 6: Grid & Drag-and-Drop
**Goal:** Create the foundation for the character formation screen.
- **Scene:** `res://scenes/demos/demo_grid.tscn`
- **Key Concepts:**
  *   **GridContainer**: Automatically arranges children into rows and columns (we used 2 columns).
  *   **`_get_drag_data`**: Runs when you start dragging. Returns the "payload".
  *   **`_can_drop_data`**: Runs while hovering. Checks if the payload is valid for this slot.
  *   **`_drop_data`**: Runs when you release the mouse. Finalizes the move.
- **Why?** This is exactly how the player will organize their 4 heroes in the 3×2 battle grid.
- **How to Run:** Open the scene and press `F6`. Click and drag the red, green, or blue boxes into empty slots.

---

### Mini-Demo 7: Singletons (Autoloads)
**Goal:** Persist data while switching scenes.
- **Script:** `res://autoloads/GlobalScore.gd`
- **Mechanism:**
  1.  **Project Settings**: The script is added to the "Autoload" tab.
  2.  **Global Access**: You can type `GlobalScore` in *any* script to access it.
  3.  **Persistence**: Unlike normal nodes, this one isn't deleted when `change_scene_to_file` is called.
- **Why?** This is where you'll store the `RunState` (current map progress, team health, gold) so it doesn't vanish when you move from a Shop to a Battle.
- **How to Run:** Open `demo_singleton_a.tscn` and press `F6`. Add some score, click "Go to Scene B", and verify the score is still there!

---

### Phase 0 Capstone: Baby Battle Prototype
**Goal:** Prove the battle logic works before building the real system.
- **Scene:** `res://scenes/demos/baby_battle.tscn`
- **Logic:**
  *   **Tick-Based**: Each unit has a "Speed" value. Every tick, they gain progress. At 100 progress, they attack.
  *   **Resource-Driven**: Uses the actual `HeroData` (.tres) files for stats.
- **Why?** This confirms we can handle automated turns, health tracking, and target selection.
- **How to Run:** Open the scene and press `F6`. Click **START BATTLE** and watch the log!

---

## 🐛 KNOWN ISSUES
*(none yet)*

---

## 📝 BACKLOG (future ideas — not in current scope)
- Multiplayer co-op mode
- Mobile port
- Steam Workshop for custom heroes
- Endless mode
- Achievement system (Phase 4)

---

## 🔗 GIT LOG (paste your commit messages here)
```
[initial] Project scaffolding — AI_RULES, folder structure, autoloads
```

---

*AI: Update this file at the end of every session.*
