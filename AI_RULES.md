# 🤖 AI COLLABORATION RULES
## Abyssal Echoes: Void Weaver — Solo Dev + AI Workflow

**Version:** 1.0 | **Updated:** April 2026  
**Purpose:** Rules every AI session MUST follow for consistent, non-destructive development.

---

## RULE 0 — READ THIS FILE FIRST

Before writing a single line of code in any session, the AI must:
1. Read this file (`AI_RULES.md`)
2. Read `PROJECT_STATUS.md` (current state of the project)
3. Ask: *"What do you want to work on today?"* — then wait for the answer

**Never assume. Never continue where you guessed we left off.**

---

## RULE 1 — NEVER BREAK WORKING CODE

- **Always ask** before modifying a file that is marked `[WORKING]` in `PROJECT_STATUS.md`
- If a refactor is needed, propose it first — get approval — then do it
- If in doubt: add new code, don't edit existing code
- **Preferred pattern:** new function alongside old one, then swap when confirmed working

---

## RULE 2 — ONE SYSTEM AT A TIME

- Work on ONE scene or ONE script per session
- Do not start a new system until the current one passes its exit criteria (see `PROJECT_STATUS.md`)
- If asked to do multiple things: do them sequentially, confirm each before moving to next

---

## RULE 3 — ALWAYS EXPLAIN THE CODE

Every code block must include:
- A comment at the top: `# PURPOSE: what this script/function does`
- Inline comments on any line that is non-obvious
- A short plain-English explanation BEFORE the code block
- Example: *"This function loops through all heroes and calls their act() method each tick. Here's what each line does..."*

**Do not write code the developer cannot understand and maintain.**

---

## RULE 4 — GODOT 4 / GDSCRIPT ONLY

- Language: **GDScript 2.0** (Godot 4 syntax only — not Godot 3)
- No C#, no plugins, no third-party addons unless explicitly approved
- Use `class_name` at top of every script
- Use `@export` for all designer-facing variables
- Use `signal` declarations at top of script, before variables
- Signals go through **EventBus** autoload for cross-scene communication

**Godot 4 syntax reminders:**
```gdscript
# Godot 4 - CORRECT
@export var max_hp: int = 100
@onready var label = $Label
signal hero_died(hero_data)
func _ready() -> void:

# Godot 3 - WRONG (do not use)
export var max_hp = 100
onready var label = $Label
```

---

## RULE 5 — FILE NAMING CONVENTIONS

| Type | Convention | Example |
|------|-----------|---------|
| Scenes | `snake_case.tscn` | `battle_scene.tscn` |
| Scripts | `PascalCase.gd` | `BattleManager.gd` |
| Resources | `snake_case_type.tres` | `warrior_hero.tres` |
| Art | `snake_case.png` | `hero_warrior_idle.png` |
| Constants | `SCREAMING_SNAKE` | `MAX_PARTY_SIZE = 4` |
| Variables | `snake_case` | `current_hp` |
| Functions | `snake_case()` | `take_damage()` |
| Signals | `snake_case` | `hero_died` |
| Classes | `PascalCase` | `HeroData` |

---

## RULE 6 — SIGNAL DISCIPLINE

- ALL cross-scene communication uses `EventBus` signals — never direct node references between scenes
- Local signals (within one scene) can be connected directly
- **Emit:** `EventBus.hero_died.emit(hero)` — **not** `get_node("/root/...").some_function()`
- New signals must be declared in `EventBus.gd` before use
- When adding a signal: update `EventBus.gd` AND add it to the signal list in `PROJECT_STATUS.md`

---

## RULE 7 — DATA IN RESOURCES, LOGIC IN SCRIPTS

- Hero stats, skill effects, enemy data = **Custom Resources (.tres files)**
- Game logic, battle simulation, UI updates = **Scripts (.gd files)**
- Never hardcode numbers inside scripts. Use `@export` or resource files.

```gdscript
# CORRECT — data in resource
@export var base_hp: int = 120
@export var base_atk: int = 15

# WRONG — hardcoded in script
func get_hp():
    return 120  # never do this
```

---

## RULE 8 — SESSION START CHECKLIST

At the start of EVERY AI session, paste this prompt:

```
Read AI_RULES.md and PROJECT_STATUS.md first.
Current task: [describe what you want to build today]
Do not start coding until you confirm you understand the current project state.
```

---

## RULE 9 — SESSION END CHECKLIST

At the end of EVERY session, ask the AI to:
1. Update `PROJECT_STATUS.md` with what was completed
2. Mark any files changed as `[MODIFIED - needs test]`
3. Write the git commit message you should use
4. List any open issues or things left unfinished

---

## RULE 10 — NO SCOPE CREEP

If the AI suggests a feature not in the PRD:
- It must label it: `[SCOPE CREEP — not in PRD]`
- It must ask permission before implementing
- New ideas go into `BACKLOG.md`, not the game

If YOU ask for something not in the PRD:
- AI must say: *"This isn't in the current scope. Want me to add it to BACKLOG.md, or proceed anyway?"*

---

## RULE 11 — ASSET STRATEGY (FREE ONLY)

Since the project uses free assets only:
- **Placeholder art:** Godot `ColorRect` + `Label` nodes — no real art until Phase 3
- **Free sprite sources:** Kenney.nl, OpenGameArt.org, itch.io free packs
- **Free SFX:** Freesound.org (CC0 license only), BFXR
- **Free music:** Kevin MacLeod / Incompetech (CC BY license — credit required)
- **Godot Asset Library:** approved for use — AI must check it before suggesting external tools
- AI must NEVER suggest paid assets without flagging cost explicitly

---

## RULE 12 — ERROR HANDLING STANDARD

Every function that can fail must handle errors:
```gdscript
# CORRECT
func load_hero_data(path: String) -> HeroData:
    if not ResourceLoader.exists(path):
        push_error("HeroData not found at: " + path)
        return null
    return load(path) as HeroData

# WRONG — silent failure
func load_hero_data(path: String):
    return load(path)
```

---

## PHASE LOCK TABLE

The AI must check this before implementing any feature:

| Feature | Phase | Status |
|---------|-------|--------|
| Baby Battle prototype (throwaway) | Phase 0 | ✅ Done |
| BattleScene (real) | Phase 1 | ✅ Done |
| FormationScreen | Phase 1 | ✅ Done |
| InventoryScreen | Phase 1 | ✅ Done |
| MapScene | Phase 2 | ✅ Done |
| ShopScene | Phase 2 | ✅ Done |
| Meta-progression | Phase 3 | ✅ Done |
| All 6 classes | Phase 3 | ✅ Done |
| Steam integration | Phase 4 | 🔒 Locked |

**🔒 Locked = Do not implement yet. 🔲 Not started = Ready to begin. ✅ Done = Complete.**

---

*This file is the contract between you and your AI. Keep it updated.*
