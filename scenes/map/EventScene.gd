class_name EventScene
extends Control

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var desc_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/DescLabel
@onready var choices_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ChoicesContainer

var events: Array = [
	{
		"title": "Altar of the Void",
		"desc": "A dark altar hums with void energy. You can feel it pulling at your soul, offering forbidden knowledge in exchange for your life force.",
		"choices": [
			{
				"text": "[Take Damage, Gain Skill] Lose 15 HP, Gain a random skill.",
				"action": "_altar_sacrifice"
			},
			{
				"text": "[Leave] Walk away safely.",
				"action": "_leave_event"
			}
		]
	},
	{
		"title": "Wandering Merchant",
		"desc": "A cloaked figure sits by a small campfire. 'Found these in the ruins. Yours for the taking, if you can carry them.'",
		"choices": [
			{
				"text": "[Loot] Gain 50 Gold.",
				"action": "_merchant_loot"
			},
			{
				"text": "[Leave] Say thanks and leave.",
				"action": "_leave_event"
			}
		]
	},
	{
		"title": "Resting Camp",
		"desc": "You find an abandoned camp. The fire is still warm.",
		"choices": [
			{
				"text": "[Rest] Heal 30% HP for all heroes.",
				"action": "_camp_rest"
			},
			{
				"text": "[Leave] Move on.",
				"action": "_leave_event"
			}
		]
	},
	{
		"title": "Dark Ritual",
		"desc": "Cultists were performing a ritual here before they fled. They left behind some of their offerings, but the void energy is unstable.",
		"choices": [
			{
				"text": "[Offer Gold] Lose 20 Gold, gain a random skill.",
				"action": "_ritual_offer"
			},
			{
				"text": "[Leave] Don't touch anything.",
				"action": "_leave_event"
			}
		]
	},
	{
		"title": "Echo of the Past",
		"desc": "A ghostly echo of a fallen warrior appears. It lashes out in confusion, but drops a coin purse when it fades.",
		"choices": [
			{
				"text": "[Fight] Take 10 damage, gain 30 gold.",
				"action": "_echo_fight"
			},
			{
				"text": "[Flee] Run away.",
				"action": "_leave_event"
			}
		]
	}
]

func _ready() -> void:
	_load_random_event()

func _load_random_event() -> void:
	var event = events.pick_random()
	title_label.text = event["title"]
	desc_label.text = event["desc"]
	
	for child in choices_container.get_children():
		child.queue_free()
		
	for choice in event["choices"]:
		var btn = Button.new()
		btn.text = choice["text"]
		btn.custom_minimum_size = Vector2(0, 45)
		# We must use call_deferred or bind properly.
		btn.pressed.connect(Callable(self, choice["action"]))
		choices_container.add_child(btn)

func _get_random_skill() -> Resource:
	var skill_paths = [
		"res://resources/skills/skill_slash.tres",
		"res://resources/skills/skill_fireball.tres",
		"res://resources/skills/skill_power_strike.tres",
		"res://resources/skills/skill_rally.tres",
		"res://resources/skills/skill_magic_bolt.tres"
	]
	return load(skill_paths.pick_random())

func _set_result(msg: String) -> void:
	desc_label.text = "[color=yellow]" + msg + "[/color]"
	for child in choices_container.get_children():
		child.queue_free()
	
	var btn = Button.new()
	btn.text = "Continue"
	btn.custom_minimum_size = Vector2(0, 45)
	btn.pressed.connect(_leave_event)
	choices_container.add_child(btn)

# ── EVENT ACTIONS ────────────────────────────────────────────────────────────

func _altar_sacrifice() -> void:
	for hero in RunState.party:
		hero["current_hp"] = max(1, hero["current_hp"] - 15)
	var skill = _get_random_skill()
	RunState.add_item(skill)
	_set_result("You sacrificed your life force and gained: " + skill.display_name)

func _merchant_loot() -> void:
	RunState.add_gold(50)
	_set_result("You found 50 gold lying around. The merchant didn't seem to notice.")

func _camp_rest() -> void:
	RunState.heal_party(0.3)
	_set_result("Your party rested by the fire and recovered HP.")

func _ritual_offer() -> void:
	if RunState.spend_gold(20):
		var skill = _get_random_skill()
		RunState.add_item(skill)
		_set_result("You offered 20 gold to the altar and received: " + skill.display_name)
	else:
		_set_result("You don't have enough gold for the ritual. The void remains silent.")

func _echo_fight() -> void:
	for hero in RunState.party:
		hero["current_hp"] = max(1, hero["current_hp"] - 10)
	RunState.add_gold(30)
	_set_result("The echo struck your party for 10 damage before fading away, leaving 30 gold behind.")

func _leave_event() -> void:
	if RunState.current_node_id != "":
		RunState.completed_node_ids.append(RunState.current_node_id)
	EventBus.scene_change_requested.emit("res://scenes/map/MapView.tscn")
