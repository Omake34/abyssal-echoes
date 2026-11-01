# Skill artwork

35 individual dark fantasy illustrations created with the built-in ImageGen tool on November 1, 2026. Every skill and tier has its own image, including the five boss abilities.

The game uses 512 × 512 PNGs here. Original full-size outputs remain in the ImageGen library. `art_manifest.json` records the shared generation prompt, each skill's subject prompt, resource mapping, and original generated filename. The full prompt is `common_prompt + "Ability: " + name + ". Subject: " + subject`.

Art is connected through each SkillData resource's `icon_path`. `SkillIcon.gd` handles cards, inventory, equipment, and shop images; Codex and cast effects use the same imported texture.

Review every skill by running `res://tests/skill_art_review.tscn` in Godot. The smoke test scene is `res://tests/skill_art_smoke_test.tscn`.
