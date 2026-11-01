# PURPOSE: ShopScene — Lets the player buy skills with gold.
# Shows 3 random skills for purchase plus a "Heal 30%" option.
# After shopping, the player returns to the map.
class_name ShopScene
extends Control

@onready var gold_label: Label = $Panel/VBoxContainer/Header/GoldLabel
@onready var shop_items: HBoxContainer = $Panel/VBoxContainer/ShopItems
@onready var leave_button: Button = $Panel/VBoxContainer/BottomBar/LeaveButton
@onready var reroll_button: Button = $Panel/VBoxContainer/BottomBar/RerollButton
@onready var message_label: Label = $Panel/VBoxContainer/MessageLabel
@onready var inventory_grid: Container = $InventoryPanel/VBoxContainer/ScrollContainer/InventoryGrid

# ── CONFIGURATION ─────────────────────────────────────────────────────────────

const SKILL_PRICE: int = 30
const HEAL_PRICE: int = 20
const HEAL_PERCENT: float = 0.3
const REROLL_BASE_COST: int = 10

var reroll_count: int = 0

func _ready() -> void:
	_update_gold_display()
	leave_button.pressed.connect(_on_leave_pressed)
	reroll_button.pressed.connect(_on_reroll_pressed)
	EventBus.merge_completed.connect(_on_merge_completed)
	_update_reroll_button()
	_generate_shop_items()
	_populate_inventory()

func _on_merge_completed(result_skill: Resource) -> void:
	message_label.text = "MERGED! Created: " + result_skill.display_name
	message_label.add_theme_color_override("font_color", Color(1, 1, 0))

func _update_gold_display() -> void:
	gold_label.text = "Gold: " + str(RunState.gold)

func _generate_shop_items() -> void:
	# Clear existing
	for child in shop_items.get_children():
		child.queue_free()
	
	# Get all Tier 1 skills from GameData
	var pool = GameData.get_skills_by_tier(1)
	pool.shuffle()
	
	# Pick top 3
	for i in range(min(3, pool.size())):
		var skill = pool[i]
		if skill == null:
			continue
		var item_panel = _create_shop_item(skill.display_name, skill.description, SKILL_PRICE, skill)
		shop_items.add_child(item_panel)
		
		# Connect buy button — stored as metadata, not via get_node
		var buy_btn: Button = item_panel.get_meta("buy_button")
		buy_btn.pressed.connect(_on_buy_skill.bind(skill, item_panel))
	
	# Add a heal option
	var heal_panel = _create_shop_item("Heal Party", "Restore 30% HP\nto all heroes.", HEAL_PRICE)
	shop_items.add_child(heal_panel)
	var heal_btn: Button = heal_panel.get_meta("buy_button")
	heal_btn.pressed.connect(_on_buy_heal.bind(heal_panel))

func _create_shop_item(title: String, desc: String, price: int, skill: SkillData = null) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 200)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.4, 0.5, 1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	# PURPOSE: Show the same skill illustration before purchase as on reward cards.
	if skill != null:
		var icon = SkillIcon.new()
		icon.custom_minimum_size = Vector2(0, 112)
		vbox.add_child(icon)
		icon.setup(skill)
	
	# Title
	var title_label = Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = desc
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)
	
	# Buy button
	var buy_btn = Button.new()
	buy_btn.text = "Buy — %d gold" % price
	buy_btn.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(buy_btn)
	
	# Store the button reference as metadata so we can find it later
	panel.set_meta("buy_button", buy_btn)
	
	return panel

# ── PURCHASE HANDLERS ─────────────────────────────────────────────────────────

func _on_buy_skill(skill: Resource, panel: PanelContainer) -> void:
	if not RunState.spend_gold(SKILL_PRICE):
		message_label.text = "Not enough gold!"
		return
	
	RunState.add_item(skill)
	message_label.remove_theme_color_override("font_color")
	message_label.text = "Bought: " + skill.display_name
	_update_gold_display()
	_populate_inventory()
	
	# Disable the button so they can't buy the same one twice
	var btn: Button = panel.get_meta("buy_button")
	btn.disabled = true
	btn.text = "SOLD"
	panel.modulate = Color(0.5, 0.5, 0.5)

func _on_buy_heal(panel: PanelContainer) -> void:
	if not RunState.spend_gold(HEAL_PRICE):
		message_label.text = "Not enough gold!"
		return
	
	RunState.heal_party(HEAL_PERCENT)
	message_label.text = "Party healed!"
	_update_gold_display()
	
	var btn: Button = panel.get_meta("buy_button")
	btn.disabled = true
	btn.text = "SOLD"
	panel.modulate = Color(0.5, 0.5, 0.5)

func _on_leave_pressed() -> void:
	# Mark node as completed and return to map
	if RunState.current_node_id != "":
		RunState.completed_node_ids.append(RunState.current_node_id)
	EventBus.scene_change_requested.emit("res://scenes/map/MapView.tscn")

# ── REROLL ────────────────────────────────────────────────────────────────────

func _get_reroll_cost() -> int:
	# Each reroll costs more: 10, 15, 20, 25...
	return REROLL_BASE_COST + (reroll_count * 5)

func _update_reroll_button() -> void:
	var cost = _get_reroll_cost()
	reroll_button.text = "REROLL — %d gold" % cost
	reroll_button.disabled = RunState.gold < cost

func _on_reroll_pressed() -> void:
	var cost = _get_reroll_cost()
	if not RunState.spend_gold(cost):
		message_label.text = "Not enough gold!"
		return
	
	reroll_count += 1
	message_label.text = "New items!"
	_update_gold_display()
	_update_reroll_button()
	_generate_shop_items()

# ── INVENTORY ─────────────────────────────────────────────────────────────────

const INVENTORY_SLOT = preload("res://scenes/battle/InventorySlot.gd")

func _populate_inventory() -> void:
	for child in inventory_grid.get_children():
		child.queue_free()
		
	for skill in RunState.inventory:
		var panel = INVENTORY_SLOT.new()
		panel.setup(skill)
		inventory_grid.add_child(panel)
