# Reward flow checks

`RewardFlowTest.gd` runs 46 checks against the real autoloads and game scenes, including reward persistence, team navigation, full inventory, skip, repeat claims, legacy saves, and victory checkpoint timing.

Run this only in a temporary project copy so it cannot affect player saves:

1. Copy `project.godot`, `autoloads`, `scripts`, `resources`, `scenes`, `assets`, and `tests` into a new temporary directory.
2. In the copied `project.godot`, set these properties under `[application]`:

   ```ini
   config/use_custom_user_dir=true
   config/custom_user_dir_name="AbyssalEchoesRewardTest-UNIQUE_SUFFIX"
   run/main_scene="res://tests/reward_flow_test.tscn"
   ```

3. Import the copy with `godot --headless --path "TEMP_PROJECT" --editor --quit`.
4. Run `godot --headless --path "TEMP_PROJECT"`.

Success prints `REWARD FLOW: 46 checks, 0 failures` and exits 0. An inventory-full warning is expected. The test scene refuses to execute unless both custom user directory settings identify an isolated test run.
