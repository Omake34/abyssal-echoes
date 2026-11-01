# PURPOSE: Verify every skill has distinct artwork and all consuming UI scenes use it.
class_name SkillArtSmokeTest
extends Node

var checks: int = 0
var failures: int = 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	_check(GameData.skills.size() == 35, "all 35 skills load")
	var paths: Array[String] = []
	for skill in GameData.skills.values():
		_check(not paths.has(skill.icon_path), "distinct artwork: " + skill.display_name)
		paths.append(skill.icon_path)
		var texture = skill.get_icon_texture()
		_check(texture != null, "texture loads: " + skill.display_name)
		if texture == null:
			continue
		_check(texture.get_width() == 512 and texture.get_height() == 512, "optimized square texture: " + skill.display_name)
		var card = load("res://scenes/battle/SkillCard.tscn").instantiate()
		add_child(card)
		card.setup(skill)
		_check(card.skill_icon.texture == texture, "card uses illustration: " + skill.display_name)
		_check(card.name_label.text == skill.display_name, "card name stays visible: " + skill.display_name)
		_check(card.find_children("*", "SubViewport", true, false).is_empty(), "card has no old 3D viewport")
		card.free()
		var slot = InventorySlot.new()
		add_child(slot)
		slot.setup(skill)
		var icons = slot.find_children("*", "TextureRect", true, false)
		_check(icons.size() == 1 and icons[0].texture == texture, "inventory uses illustration: " + skill.display_name)
		slot.free()

	var example = GameData.get_skill("fireball")
	var hero_data = GameData.get_hero("warrior")
	var combatant = load("res://scenes/battle/CombatantUI.tscn").instantiate()
	add_child(combatant)
	combatant.setup({"data": hero_data, "display_name": "Warrior", "current_hp": 160, "max_hp": 160, "skills": [example], "status_effects": []})
	_check(combatant.skills_container.get_child(0).texture == example.get_icon_texture(), "equipped skill uses illustration")
	combatant.free()
	var codex = load("res://scenes/meta/CodexScene.tscn").instantiate()
	add_child(codex)
	codex._show_item_details(example)
	_check(codex.item_icon.visible and codex.item_icon.texture == example.get_icon_texture(), "Codex detail uses illustration")
	_check(codex.grid.get_child(0).icon != null, "Codex list uses illustrations")
	codex.free()
	var shop = load("res://scenes/map/ShopScene.tscn").instantiate()
	add_child(shop)
	var shop_icons = shop.shop_items.get_child(0).find_children("*", "TextureRect", true, false)
	_check(shop_icons.size() == 1 and shop_icons[0].texture != null, "shop purchase uses illustration")
	shop.free()
	var vfx = SkillVFX.new()
	add_child(vfx)
	vfx.launch_projectile(Vector2.ZERO, Vector2(60, 0), example.type_color, example.get_icon_texture())
	_check(vfx.get_child(0) is Sprite2D and vfx.get_child(0).texture == example.get_icon_texture(), "cast effect uses matching illustration")
	await get_tree().create_timer(0.4).timeout
	_check(not is_instance_valid(vfx), "cast effect cleans up")
	print("SKILL ART: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
