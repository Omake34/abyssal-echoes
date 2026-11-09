# Blender art pilot — November 9, 2026

Original procedural models rendered with Blender 5.2.3 LTS / Cycles.

- `arena_beauty.png`: 1440 x 1000 scene with Warrior and Riftbound sentinel.
- `arena_environment.png`: the same camera and ruin kit, without characters, on alpha.
- `../../../assets/characters/blender_pilot/`: eight transparent 256 x 256 PNGs; one static idle pose in four directions per character.
- `../../source/blender/abyssal_pilot.blend`: editable scene, materials, lights, and orthographic camera, saved before sprite isolation.
- `manifest.json`: asset paths and generator provenance.

Regenerate from the project root using a separate process:

```powershell
& 'F:/SteamLibrary/steamapps/common/Blender/blender.exe' --background --python tools/blender/render_pilot.py
```

The generator replaces its own named outputs and refuses interactive execution to protect open Blender work. The source directory has `.gdignore`; the game consumes exported images rather than importing the authoring scene.

Visual review: arena composition and both front-facing sprites inspected. All eight sprite files have 256 x 256 dimensions, transparent corners, and opaque character centers. Render process reached `ABYSSAL PILOT COMPLETE`.

## Warrior integration

`ArenaBoard.gd` now displays the Warrior sprites in the shared production/fixture board. Movement and targets choose a facing; the sprite uses the projected ground origin `(0.5, 0.82505)` as its normalized pivot. East/west renders use three-quarter poses after the exact side view proved too narrow at gameplay scale. The 72-pixel display canvas scales with the board; hit bounds include the shield and sword. Existing HP, selection, status, drag/swap, and death feedback remain.

Godot 4.7.2 captures at 1280 x 720:

- `godot_warrior_preparation.png`: actual board scale and selected Warrior.
- `godot_warrior_drag.png`: drag preview and occupied-cell swap feedback.
- `godot_warrior_battle.png`: paused combat with the new Warrior presentation.

All three were visually inspected. Final isolated regressions passed: 193 arena checks and 98 production run-arena checks. Player saves were not used.

This is still a static sprite pilot, not the completed PRD art milestone. Rigs, animation sequences, other character integrations, 1080p visual acceptance, and performance acceptance remain open. The arena image is an illustrative 8 x 6 tile diorama; it is not a replacement for the gameplay's 16 x 7 board. Next, build a small Warrior animation sample before expanding the roster.

## Warrior animation pilot

`tools/blender/render_warrior_animation.py` renders the Warrior's idle, move, attack, hit, and death rows (six 256 x 256 frames each) for four facings into `assets/characters/blender_pilot/animated/`. Timing, row order, and the shared foot pivot are recorded in that folder's `manifest.json`. Regenerate in a separate background process:

```powershell
& 'F:/SteamLibrary/steamapps/common/Blender/blender.exe' --background --python tools/blender/render_warrior_animation.py
```

`ArenaBoard.gd` selects rows from simulation events after combat has resolved them; animation never applies or delays damage. Captures at gameplay scale:

- `animated_battle_1280x720.png`
- `animated_battle_1920x1080.png`

Both were reviewed, along with live unpaused frames. A follow-up readability pass moved combat numbers above HP bars (stacked), put the shield on the HP bar, and toned down the taunt pulse, so the swing and recoil now read in melee. Numbers for a unit directly below can still overlap.
