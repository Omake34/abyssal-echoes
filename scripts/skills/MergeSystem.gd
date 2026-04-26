# PURPOSE: MergeSystem — Handles all skill merging logic.
# Merging rules:
#   3x Tier I same-type skills → 1x Tier II skill (random from same type)
#   3x Tier II same-type skills → 1x Tier III skill (random from same type)
#   2x Tier III compatible skills → 1x EX skill (specific combination)
# This class is stateless — call its static functions from anywhere.

class_name MergeSystem
extends RefCounted

# ── MERGE VALIDATION ──────────────────────────────────────────────────────────

## Check if three skills can be merged together.
## Returns a dictionary: { "can_merge": bool, "reason": String }
static func can_merge_three(skill_a: SkillData, skill_b: SkillData, skill_c: SkillData) -> Dictionary:
	# All must be same tier
	if not (skill_a.tier == skill_b.tier and skill_b.tier == skill_c.tier):
		return { "can_merge": false, "reason": "Skills must all be the same tier." }

	# Tier 4 (EX) skills cannot be merged further
	if skill_a.tier >= 3:
		return { "can_merge": false, "reason": "Use 2x Tier III skills to craft an EX ability instead." }

	# All must be mergeable
	if not (skill_a.can_merge and skill_b.can_merge and skill_c.can_merge):
		return { "can_merge": false, "reason": "One or more skills cannot be merged." }

	# All must be same skill_type (physical, magic, support, utility)
	if not (skill_a.skill_type == skill_b.skill_type and skill_b.skill_type == skill_c.skill_type):
		return { "can_merge": false, "reason": "Skills must be the same type (Physical, Magic, Support, or Utility)." }

	return { "can_merge": true, "reason": "" }

## Check if two Tier III skills can be combined into an EX ability.
static func can_craft_ex(skill_a: SkillData, skill_b: SkillData) -> Dictionary:
	if skill_a.tier != 3 or skill_b.tier != 3:
		return { "can_craft": false, "reason": "EX crafting requires two Tier III (Master) skills." }

	# Look for an EX skill that takes these two as ingredients
	var ex_skill = _find_ex_skill(skill_a.id, skill_b.id)
	if ex_skill == null:
		return { "can_craft": false, "reason": "These two skills have no known EX combination." }

	return { "can_craft": true, "reason": "", "result": ex_skill }

# ── MERGE EXECUTION ───────────────────────────────────────────────────────────

## Performs a 3-skill merge. Removes the 3 skills from inventory and adds the result.
## Returns the resulting SkillData, or null if merge failed.
static func perform_merge(skill_a: SkillData, skill_b: SkillData, skill_c: SkillData) -> SkillData:
	var check = can_merge_three(skill_a, skill_b, skill_c)
	if not check["can_merge"]:
		push_warning("[MergeSystem] Merge failed: " + check["reason"])
		return null

	# Determine the result skill
	var result_skill: SkillData = null

	# If skill_a has a specific merge result defined, use it
	if skill_a.merge_result_id != "" and skill_a.id == skill_b.id and skill_b.id == skill_c.id:
		result_skill = GameData.get_skill(skill_a.merge_result_id)
	else:
		# Generic tier-up: pick a random skill of next tier and same type
		result_skill = _pick_random_tier_up(skill_a.skill_type, skill_a.tier + 1)

	if result_skill == null:
		push_error("[MergeSystem] Could not find a result skill for merge!")
		return null

	# Remove the 3 input skills from inventory
	RunState.remove_item(skill_a)
	RunState.remove_item(skill_b)
	RunState.remove_item(skill_c)

	# Add the result to inventory
	RunState.add_item(result_skill)

	RunState.run_stats["skills_merged"] += 1
	EventBus.merge_completed.emit(result_skill)

	print("[MergeSystem] Merge complete: %s + %s + %s → %s" % [
		skill_a.display_name, skill_b.display_name, skill_c.display_name, result_skill.display_name
	])
	return result_skill

## Performs an EX craft from two Tier III skills.
static func perform_ex_craft(skill_a: SkillData, skill_b: SkillData) -> SkillData:
	var check = can_craft_ex(skill_a, skill_b)
	if not check["can_craft"]:
		push_warning("[MergeSystem] EX craft failed: " + check["reason"])
		return null

	var ex_skill: SkillData = check["result"]

	RunState.remove_item(skill_a)
	RunState.remove_item(skill_b)
	RunState.add_item(ex_skill)

	# Unlock this EX skill in meta-progression (so player knows they found it)
	if not RunState.meta["unlocked_skills"].has(ex_skill.id):
		RunState.meta["unlocked_skills"].append(ex_skill.id)
		RunState.save_meta()

	RunState.run_stats["skills_merged"] += 1
	EventBus.merge_completed.emit(ex_skill)

	print("[MergeSystem] EX Craft: %s + %s → %s!" % [skill_a.display_name, skill_b.display_name, ex_skill.display_name])
	return ex_skill

## Returns a preview of what a merge would produce — WITHOUT performing it.
static func preview_merge(skill_a: SkillData, skill_b: SkillData, skill_c: SkillData) -> SkillData:
	var check = can_merge_three(skill_a, skill_b, skill_c)
	if not check["can_merge"]:
		return null
	if skill_a.merge_result_id != "" and skill_a.id == skill_b.id and skill_b.id == skill_c.id:
		return GameData.get_skill(skill_a.merge_result_id)
	return _pick_random_tier_up(skill_a.skill_type, skill_a.tier + 1)

## Returns a preview of the EX craft result without performing it.
static func preview_ex_craft(skill_a: SkillData, skill_b: SkillData) -> SkillData:
	return _find_ex_skill(skill_a.id, skill_b.id)

# ── INTERNAL HELPERS ──────────────────────────────────────────────────────────

## Picks a random skill of the given type and tier from GameData
static func _pick_random_tier_up(skill_type: String, target_tier: int) -> SkillData:
	var candidates = []
	for skill in GameData.skills.values():
		if skill.skill_type == skill_type and skill.tier == target_tier:
			candidates.append(skill)
	if candidates.is_empty():
		push_warning("[MergeSystem] No Tier %d %s skills found in GameData!" % [target_tier, skill_type])
		return null
	return candidates[randi() % candidates.size()]

## Searches GameData for an EX skill that takes skill_a_id and skill_b_id as ingredients
static func _find_ex_skill(skill_a_id: String, skill_b_id: String) -> SkillData:
	for skill in GameData.skills.values():
		if skill.tier == 4:  # EX skills are tier 4
			var ingredients = [skill.ex_ingredient_a, skill.ex_ingredient_b]
			if skill_a_id in ingredients and skill_b_id in ingredients:
				return skill
	return null
