# 🚀 AI SESSION STARTER PROMPT
## Copy and paste this at the START of every new Claude conversation.

---

```
You are my Godot 4 game development assistant for "Time Walker: Darkworld" — a roguelite auto-battler.

STEP 1 — Read these two files before doing anything else:
- AI_RULES.md         (your rules and constraints for this project)
- PROJECT_STATUS.md   (current state of the project)

STEP 2 — Confirm you understand:
- Current phase
- What was last completed
- What the current task is

STEP 3 — Wait for me to tell you what to work on today.

Do NOT write any code until you have confirmed the project state and I have given you a task.

Rules reminder:
- Godot 4 / GDScript 2.0 ONLY
- One system at a time
- Explain every line of code you write
- Never modify [WORKING] files without asking
- All assets must be FREE (Kenney.nl, OpenGameArt.org, Freesound.org CC0)
- New feature ideas go in BACKLOG.md, not the game
```

---

## EXAMPLE SESSION TASKS

Paste one of these after the starter prompt depending on what you want to do:

**To build a new system:**
```
Today I want to build: [BattleScene.tscn — the visual battle screen]
The BattleManager.gd script is already done. I need a scene that:
- Shows hero and enemy sprites (placeholder ColorRects for now)
- Displays HP bars for each combatant
- Has a speed toggle button (1x / 2x / 3x)
- Listens to EventBus signals to update the UI each tick
Start by explaining the scene structure before writing any code.
```

**To fix a bug:**
```
I have a bug: [describe exactly what happens and what you expected]
The relevant file is: [filename]
Here is the error message: [paste full error from Godot output]
Do NOT rewrite the whole file — find the specific problem and fix only that.
```

**To add a resource:**
```
I need a new [HeroData / SkillData / EnemyData] resource file.
Name: [display name]
Details: [describe stats, effect, role]
Create the .tres file contents I can paste into Godot.
```

**To get a code review:**
```
Please review this GDScript file for:
1. Godot 4 correctness (no Godot 3 syntax)
2. Bugs or logic errors
3. Missing error handling
4. Anything that violates AI_RULES.md

[paste your code]
```

---

## END-OF-SESSION CHECKLIST

Ask Claude this at the end of every session:

```
Session complete. Please:
1. Tell me what we finished today
2. Update PROJECT_STATUS.md with the changes
3. List any files that were modified (mark as [MODIFIED - needs test])
4. Write the git commit message I should use
5. Tell me what to work on next session
```

---

*Keep this file. It is your key to consistent AI-assisted development.*
