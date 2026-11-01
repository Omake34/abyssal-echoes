# Project Explainer: Abyssal Echoes: Void Weaver
### Built on Godot 4.x (GDScript) • A Roguelike Auto-Battler Game

Welcome to the **Abyssal Echoes: Void Weaver** comprehensive learning guide. This document was designed specifically for **non-coders** or developers new to the game's engine (Godot 4.x) to understand exactly how the project is structured, how the systems interact, and how to read the codebase. 

You can upload this document directly to **NotebookLM** (along with other markdown files in the project) to ask questions, learn concepts, or generate study guides!

---

## 1. High-Level Game Concept (The Big Picture)

*Abyssal Echoes: Void Weaver* is an auto-battler turn-based strategy roguelike game inspired by *Time Walker: Darkworld*. 

### The Gameplay Loop:
1. **Draft Party:** You start a run by choosing a party of **4 heroes** (e.g., Warrior, Archer, Assassin, Captain).
2. **Procedural Journey:** You travel node-by-node on a branching map. Nodes can be **Battles**, **Shops** (where you buy skills), **Rest Stops** (where you heal), or **Mystery Events**.
3. **Automated Grid Combat:** When a battle starts, you arrange your 4 heroes on a **3x2 tactical grid**. The battle plays out automatically in real-time, executing tick-based attacks, healing, and casting skills.
4. **Skill Merging:** You collect skills as rewards or purchases. If you collect **three of the exact same skill**, they automatically **merge** into a single, higher-tier, more powerful skill (Tier I → Tier II → Tier III). You can also craft high-power **EX skills** by combining specific Tier III ingredients.
5. **Meta-Progression:** Win or lose, you receive **Darkworld Coins** at the end of a run. You can spend these coins in the **Talent Tree** on the main menu to purchase permanent, cross-run stat buffs (e.g., permanent HP, extra starting gold) or unlock new character classes (Assassin, Captain).

---

## 2. A Non-Coder's Guide to Godot Terminology

To understand this codebase, you only need to know **four key concepts** of how Godot games are built:

### A. Scenes (`.tscn` files)
Think of a Scene as a **Lego assembly** or a individual screen template. A scene can be a single button, a full UI panel, an enemy character, or an entire level (like the Main Menu or the Battle Scene). 
* Scenes are structured as a tree of **Nodes**. Each node has a specific duty (e.g., a `Label` node displays text, a `TextureRect` node displays an image, a `Timer` node counts down time).

### B. GDScript (`.gd` files)
GDScript is Godot's programming language. It is designed to look like Python and read like plain English. 
* A GDScript is a plain text file that is attached to a scene to give it a "brain". For example, `MainMenu.tscn` is the layout of the menu, and `MainMenu.gd` is the script that tells the game what to do when the "Play" button is clicked.

### C. Autoloads / Singletons
Normally, when you change scenes in a game (e.g., going from the Main Menu to the Battle Screen), all nodes in the old scene are destroyed, and their memory is wiped.
* **Autoloads** are special scripts that are loaded at the very start of the game and **never die**. They stay in the background across all scenes. 
* In this game, they serve as the global brains: `RunState.gd` keeps track of how much gold you have, your party, and your inventory. If we change scenes, `RunState` stays alive and remembers everything!

### D. Signals (The Event Bus Pattern)
In programming, you want to avoid making scripts overly dependent on each other. If the player clicks a button on the UI, the script controlling the player shouldn't have to search through the entire game to find the audio player and say "play a click sound."
* Instead, we use **Signals**, which are like radio broadcasts. 
* The button "emits" a signal called `pressed`. The audio player is "listening" (connected) to that signal. 
* This game uses a centralized radio tower called the **EventBus** (`EventBus.gd`). Anyone can broadcast a signal to the tower (e.g., `EventBus.hero_died.emit()`), and any scene in the game can tune in and respond.

---

## 3. Core Technical Architecture (How the Systems Connect)

The architecture is highly modular and organized. Rather than having one giant file that does everything, the code is split into specific, single-responsibility modules:

```mermaid
graph TD
    subgraph Global Systems (Autoloads)
        GameData[GameData.gd <br/> Static reference database]
        RunState[RunState.gd <br/> Save/Load & active run progress]
        EventBus[EventBus.gd <br/> Central radio signal broker]
        SceneManager[SceneManager.gd <br/> Smooth screen transitions]
    end

    subgraph Game Setup & Progression
        MainMenu[MainMenu.tscn <br/> Hub for Codex & Talent upgrades]
        HeroSelect[HeroSelectScene.tscn <br/> Party selection draft]
        MapView[MapView.tscn <br/> Procedural map traversal]
    end

    subgraph Core Run Gameplay
        BattleScene[BattleScene.tscn <br/> Grid setup, HP bars & combat VFX]
        BattleManager[BattleManager.gd <br/> The combat simulator / ticks]
        ShopScene[ShopScene.tscn <br/> Spending gold to buy skills]
        RewardScene[RewardScene.tscn <br/> Victory skill draft selection]
    end

    %% Interactions
    MainMenu -->|Transition| HeroSelect
    HeroSelect -->|Generates Party| RunState
    HeroSelect -->|Transition| MapView
    MapView -->|Travel to Battle Node| BattleScene
    BattleScene -->|Ticks & Combat Logic| BattleManager
    BattleManager -->|Win/Lose broadcast| EventBus
    EventBus -->|Load rewards| RewardScene
    RewardScene -->|Save inventory & Map| RunState
    RewardScene -->|Transition| MapView
```

---

## 4. Key Files Map & Explanations

Here is a catalog of the most critical files in the codebase, what they do in plain English, and direct links so you can inspect them.

### ── 📂 The Infrastructure (Autoloads)

#### 1. [EventBus.gd](file:///d:/Godot%20Things/New%20folder/time_walker_darkworld/autoloads/EventBus.gd)
* **What it does:** The global communications broker. It lists all major game events like battle start/end, hero/enemy death, skill execution, damage floating numbers, item changes, and scene transition requests. 
* **Why it's important:** It completely decouples different screens. For example, when a battle is won, `BattleManager.gd` tells `EventBus` that the battle ended with a `"win"`. The `BattleScene` listens to this and opens the Victory UI.

#### 2. [RunState.gd](file:///d:/Godot%20Things/New%20folder/time_walker_darkworld/autoloads/RunState.gd)
* **What it does:** Represents the "Save File" for the player's active run. It holds variable values for current gold, party members, skill inventory, completed map nodes, current difficulty, and game statistics. It also manages **JSON saving and loading** to a local file (`user://run_state.json`) and **meta-progression currency/upgrades** (`user://meta_progress.json`).
* **Why it's important:** It handles active character traits, auto-equipping skills from the inventory, and **automatic skill merging** (when 3 identical skills are placed in the inventory).

#### 3. [GameData.gd](file:///d:/Godot%20Things/New%20folder/time_walker_darkworld/autoloads/GameData.gd)
* **What it does:** Acts as the game's read-only "Database". At startup, it scans specific folders (`res://resources/skills/`, `res://resources/heroes/`, etc.) and automatically parses and loads all `.tres` data files.
* **Why it's important:** The rest of the game asks `GameData` for info, like: *"Give me the baseline stats for a Warrior"* or *"Show me all skills that are Tier I Magic skills."*

---

### ── 📂 Core Game Logic & Systems

#### 4. [SkillData.gd](file:///d:/Godot%20Things/New%20folder/time_walker_darkworld/scripts/skills/SkillData.gd)
* **What it does:** A **Resource Blueprint** defining what a "Skill" is. It holds values for a skill's ID, display name, description, power tier (1 to 4), classification (physical, magic, support, utility), target rules (e.g., single enemy, all allies), casting cooldown ticks, and how it merges into higher tiers.
* **Why it's important:** Allows easy creation of new skills without writing code; designers can just create a new resource file, fill out the form in Godot's inspector, and the game automatically integrates it.

#### 5. [HeroData.gd](file:///d:/Godot%20Things/New%20folder/time_walker_darkworld/scripts/heroes/HeroData.gd)
* **What it does:** A **Resource Blueprint** defining what a base "Hero Class" is. It holds values for class names, starting HP, attack, magic attack, speed, evasion, starting skills, preferred grid layout row (front or back), and unlock conditions.
* **Why it's important:** Keeps unit definition entirely separate from the active battle simulation code, preventing bugs and allowing easy balance adjustments.

#### 6. [EnemyData.gd](file:///d:/Godot%20Things/New%20folder/time_walker_darkworld/scripts/enemies/EnemyData.gd)
* **What it does:** A **Resource Blueprint** defining an enemy type's stats, loot table, difficulty level, and special AI behavior keys (e.g., "attack_lowest_hp", "heal_allies").
* **Why it's important:** Allows the game to dynamically load different combat challenges during procedural generation.

#### 7. [BattleManager.gd](file:///d:/Godot%20Things/New%20folder/time_walker_darkworld/scripts/battle/BattleManager.gd)
* **What it does:** The **physics engine of combat**. It is not a visual scene, but a pure script that drives battles tick-by-tick. It handles initiative queues, calculates damage, runs statuses (like Bleed, Burn, Stun), executes skill effects, coordinates target-selection AI, and triggers victory or defeat when a team is wiped out.
* **Why it's important:** It holds the mathematical formulas for combat resolution, stat scaling, and global battlefield modifiers.

#### 8. [SynergyManager.gd](file:///d:/Godot%20Things/New%20folder/time_walker_darkworld/scripts/battle/SynergyManager.gd)
* **What it does:** Evaluates active synergy combos. If the player equips multiple skills of the same type (like physical or support) across their characters, this manager detects the matches and applies team-wide passive buffs.
* **Why it's important:** Adds tactical depth, encouraging players to build specific party archetypes (e.g., a high-magic party or defensive-physical lineup).

---

### ── 📂 High-Level Documents & Tracking

* [AbyssalEchoes_PRD.md](file:///d:/Godot%20Things/New%20folder/time_walker_darkworld/AbyssalEchoes_PRD.md) - The **Product Requirements Document**. This is the game's blueprint, outlining solo-developer time estimates, scope guidelines, milestone phases, and next action priorities.
* [PROJECT_STATUS.md](file:///d:/Godot%20Things/New%20folder/time_walker_darkworld/PROJECT_STATUS.md) - The active development dashboard, tracking which core screens, inventory logic, and meta-progression features are completed, in progress, or planned.

---

## 5. Summary of Key Coding Paradigms in the Game

When you ask NotebookLM to explain specific scripts, keep these coding styles in mind:

1. **Composition Over Inheritance:** Instead of creating a complicated family tree of scripts (e.g., a "Warrior" script that inherits from a "Hero" script which inherits from "Combatant"), characters are represented as generic containers that dynamically *load* different `HeroData` resources.
2. **Resource-Driven Systems:** Stats are never hardcoded inside script files. They are defined in separate `.tres` files (Godot Resources). This means you can change a character's HP or a skill's damage directly in a menu without risk of breaking the code.
3. **Save State Integrity:** The game state behaves like a transactional database. Every time you finish a node on the map, choose a battle reward, or buy a skill from the shop, `RunState` immediately commits the changes to the JSON save files on your hard drive. If the game crashes or is closed, the player can resume exactly where they left off.

---

### 💡 Tips for using this with NotebookLM:
* **Ask for structural summaries:** *"Based on `RunState.gd` and `EventBus.gd`, explain step-by-step what happens when a player merges three Tier I skills."*
* **Ask about game design balance:** *"Look at the stats inside `HeroData.gd` and `SkillData.gd`. How does physical attack power scale with skills compared to magical attack?"*
* **Ask for code translation:** *"I am a beginner. Explain how `GameData.gd` loads resources using simple analogies."*
