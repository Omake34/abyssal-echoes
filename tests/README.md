# Arena combat checks

For the shared arena slice, run `godot --headless --path "TEMP_PROJECT" res://tests/arena_combat_test.tscn` after importing the isolated copy described below. Success prints `ARENA COMBAT: 193 checks, 0 failures`. The suite tests full fights and real trial controls, including mouse dragging/cancellation, resource-driven abilities, equipment rules, shelf/removal controls, and saved-run isolation. It does not award rewards or modify progression. See `docs/ARENA_TRIAL.md` for the exact prototype rules and limitations.

# Reward flow checks

`RewardFlowTest.gd` runs 46 checks against the real autoloads and game scenes, including reward persistence, team navigation, full inventory, skip, repeat claims, legacy saves, and victory checkpoint timing.

Run this only in a temporary project copy so it cannot affect player saves:

1. Copy `project.godot`, `autoloads`, `scripts`, `resources`, `scenes`, `assets`, and `tests` into a new temporary directory. Exclude `.godot/` and generated `*.import` files so Godot creates fresh import metadata.
2. In the copied `project.godot`, set these properties under `[application]`:

   ```ini
   config/use_custom_user_dir=true
   config/custom_user_dir_name="AbyssalEchoesRewardTest-UNIQUE_SUFFIX"
   run/main_scene="res://tests/reward_flow_test.tscn"
   ```

3. Import the copy with `godot --headless --path "TEMP_PROJECT" --editor --quit`.
4. Run `godot --headless --path "TEMP_PROJECT"`.

Success prints `REWARD FLOW: 46 checks, 0 failures` and exits 0. An inventory-full warning is expected. The test scene refuses to execute unless both custom user directory settings identify an isolated test run.

# Skill artwork checks and review

After importing the isolated copy, run `godot --headless --path "TEMP_PROJECT" res://tests/skill_art_smoke_test.tscn`. Success prints `SKILL ART: 259 checks, 0 failures`. This verifies all 35 unique textures at 512 × 512, card labels and images, inventory, equipped skills, shop art, Codex art, and cast-effect cleanup.

For an interactive gallery, run `res://tests/skill_art_review.tscn` in Godot. Hover the cards for descriptions and scroll through every skill. The Back button opens the main menu.

To export previews with the regular renderer, pass `-- --capture-sheet="ABSOLUTE_OUTPUT.png"` for all 35 labelled icons or `-- --capture-cards="ABSOLUTE_OUTPUT.png"` for the card gallery. The review scene exits after writing the requested PNG.

Use `-- --capture-tiers="ABSOLUTE_OUTPUT.png"` for a nine-card comparison of physical/red, magic/blue, and healing/green across tiers I, II, and III. It renders the real reward cards, including frame weights, rank marks, and master details.
