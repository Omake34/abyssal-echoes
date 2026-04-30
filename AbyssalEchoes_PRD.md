# ABYSSAL ECHOES: VOID WEAVER
## Game Remake — Product Requirements Document
**Version 2.1 | April 2026 | Solo Developer | Godot 4.x | PC (Windows / Linux / macOS)**

---

> ⚠️ **DEVELOPER PROFILE:** Solo developer — complete beginner in Godot. This PRD is scoped
> accordingly: systems are designed to be built one at a time, the learning curve is
> front-loaded, and scope is kept tight to maximise the chance of shipping a complete game.

---

## TABLE OF CONTENTS

1. [Project Overview](#1-project-overview)
2. [Solo Beginner Reality Check](#2-solo-beginner-reality-check)
3. [Godot 4.x Learning Roadmap](#3-godot-4x-learning-roadmap)
4. [Original Game Analysis](#4-original-game-analysis)
5. [Game Concept & Vision](#5-game-concept--vision)
6. [Core Gameplay Systems](#6-core-gameplay-systems)
7. [Godot 4.x Technical Architecture](#7-godot-4x-technical-architecture)
8. [Development Milestones](#8-development-milestones)
9. [Art & Audio Plan](#9-art--audio-plan-solo-friendly)
10. [Risk Register](#10-risk-register)
11. [Recommended Resources](#11-recommended-resources)
12. [Your Next 7 Actions](#12-your-next-7-actions)

---

## 1. Project Overview

| Field | Value |
|---|---|
| Project Name | Abyssal Echoes: Void Weaver |
| Engine | Godot 4.x — GDScript (primary language) |
| Genre | Roguelike Auto-Battler / Turn-Based Strategy |
| Perspective | 2D Top-Down |
| Target Platform | PC — Windows, Linux, macOS |
| Developer | Solo — beginner Godot experience |
| Distribution | Steam (target) — Itch.io for early builds |
| Monetization | Paid game — one-time purchase (TBD: $5–$10) |
| Doc Version | 2.1 — April 2026 (Updated Progress) |

This document defines requirements for an original game **inspired by** Time Walker: Darkworld. 
> *"As the last Void Weaver, you must lead a party of echo-bound souls through the cursed abyss. Weave skills across classes, master the formation grid, and survive the echoes of the void in this roguelite auto-battler."*
The goal is a focused, shippable PC game built by one developer learning Godot from scratch. Scope is deliberately conservative to avoid the most common solo dev failure: abandoning an over-ambitious project.

---

## 2. Solo Beginner Reality Check

> ⚠️ **Read this section carefully.** The #1 reason indie games fail is scope creep combined
> with skill ramp-up time. This section exists to keep you honest.

### 2.1 Honest Time Estimates

| Task | Optimistic | Realistic (Beginner) | Notes |
|---|---|---|---|
| Learn Godot basics (scenes, nodes, GDScript) | 2 weeks | 4–6 weeks | **[DONE - 2 Weeks]** |
| Build a working battle prototype | 1 week | 3–6 weeks | **[DONE - 1 Week]** |
| Full inventory + merge system | 1 week | 3–4 weeks | More complex than it looks |
| Run map + node graph | 3 days | 2–3 weeks | **[IN PROGRESS]** |
| Polish, audio, UI | 1 week | 4–8 weeks | Always underestimated |
| Bug fixing + balancing | 1 week | 4–6 weeks | Needs external playtesters |
| **TOTAL (rough estimate)** | **2 months** | **12–24 months** | Part-time = upper end; full-time = lower |

### 2.2 Scope Rules for This Project

- **RULE 1** — Build a VERTICAL SLICE first. One full run, 2 classes, 20 skills. Ship that before adding more.
- **RULE 2** — No new features until current feature is fully working and tested.
- **RULE 3** — Use placeholder art (colored rectangles) until systems are working. Art last.
- **RULE 4** — Commit to Git every session. Use GitHub or GitLab (free). No exceptions.
- **RULE 5** — Show your game to someone else every 2 weeks. External eyes catch invisible problems.
- **RULE 6** — Cut features ruthlessly. A finished small game beats an abandoned big game 100% of the time.

---

## 3. Godot 4.x Learning Roadmap

### Step 1 — Godot Fundamentals (Weeks 1–2) — [✅ COMPLETE]

**Goal:** Understand how Godot's scene/node system works.

| Resource | Type | Status | What You Learned |
|---|---|---|---|
| GDQuest — Learn GDScript Series (YouTube) | Free Video | ✅ | Syntax, variables, functions |
| Godot Docs — "Your First 2D Game" | Free Text | ✅ | Scenes, nodes, signals |
| Brackeys — Godot 4 Beginner Tutorial | Free Video | ✅ | Editor and core workflow |
| Practice | Practice | ✅ | Built various mini-demos |

### Step 2 — Core Systems You Need (Weeks 3–5) — [✅ COMPLETE]

**Goal:** Learn the specific Godot features this game requires. Study each, then build a mini-demo.

| Godot Concept | Why You Need It | Mini-Demo Status |
|---|---|---|
| Signals & EventBus pattern | Decoupled battle events | ✅ demo_signals.tscn |
| Custom Resources (.tres) | Data files | ✅ demo_resources.tscn |
| Control nodes + Themes | UI systems | ✅ demo_reactive.tscn |
| Tweens & AnimationPlayer | Feedback | ✅ demo_tweens.tscn |
| FileAccess (JSON save/load) | Save system | ✅ demo_save.tscn |
| GridContainer | Formation layout | ✅ demo_grid.tscn |
| Autoloads (Singletons) | Global State | ✅ GlobalScore.gd |

### Step 3 — Build a "Baby Battle" Prototype (Weeks 5–7) — [✅ COMPLETE]

The "Baby Battle" prototype was successfully implemented at `res://scenes/demos/baby_battle.tscn`. It demonstrated automated combat, tick-based resolution, and win detection.

---

## 4. Original Game Analysis

### 4.1 Core Loop (What to Keep)

| Feature | Keep? | Status |
|---|---|---|
| Auto-battle (watch fights play out) | YES | ✅ BattleManager.gd (Core Ready) |
| Cross-class skill equipping | YES | 🔲 Pending |
| 3-tier skill merge system | YES | 🔲 Pending |
| EX ability crafting | YES | 🔲 Pending |
| Branching run map | YES | 🏗️ MapNode.tscn (Started) |
| Formation grid positioning | YES | ✅ demo_grid.tscn (Prototype Ready) |
| Meta-progression | YES | 🔲 Pending |
| Pixel art 2D top-down perspective | YES | ✅ Placeholder colors working |
| Speed toggle (1x / 2x / 3x) | YES | ✅ Logic built in BattleManager |

---

## 8. Development Milestones

### Phase 0 — Learn Godot (Weeks 1–7) — [✅ 100% COMPLETE]

- [x] Complete GDQuest GDScript tutorial series
- [x] Complete Godot official "Your First 2D Game" tutorial
- [x] Build the 7 mini-demos from Section 3
- [x] Build the Baby Battle prototype (throwaway)
- [x] Set up GitHub repo

### Phase 1 — Core Systems Prototype (Weeks 8–18) — [✅ 100% COMPLETE]

- [x] BattleScene: tick-based auto-battle with 2 heroes and 1 enemy type
- [x] FormationScreen: 3×2 grid with draggable hero placement (Mini-demo done)
- [x] Skill system: 10 skills as Resource files, equippable to heroes (Classes ready)
- [x] Basic InventoryScreen: view, equip, salvage
- [x] Win/Lose detection + post-battle summary screen
- [x] HUD: HP bars, battle speed toggle (Logic ready)

**Current Focus:** Moving towards a functional Map system and connecting the BattleScene to rewards.

### Phase 2 — Vertical Slice (Weeks 19–32) — [✅ 100% COMPLETE]

- [x] MapScene: 5-node linear map (Started `MapNode.tscn`)
- [x] ShopScene: buy skills with run gold
- [x] Merge system: 3x Tier I → Tier II, preview before commit

---

## 12. Your Next 7 Actions

> ✅ Milestone achieved! Battle logic is solid. Here are the next steps to make it a game:

1. **Complete the Map System**: Build `MapGenerator.gd` to create a simple path of nodes.
2. **Connect Battle to Map**: Selecting a node on the map should load the `BattleScene`.
3. **Build the Reward Screen**: After a win, show a screen where you pick 1 of 3 skills.
4. **Implement the Formation Screen**: Allow players to drag heroes on the 3x2 grid before the fight.
5. **Create 10 Basic Skills**: Flesh out the `SkillData` resources (Slash, Heal, Fireball, etc).
6. **Implement Inventory System**: A basic panel to view the skills you've collected.
7. **Playtest the Loop**: Run from Map -> Battle -> Reward -> Map.

---

*Abyssal Echoes: Void Weaver — PRD v2.1 · Solo Developer Edition · April 2026*
*This is a living document. Update it every time a major decision is made.*
