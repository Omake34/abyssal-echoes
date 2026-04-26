extends Control

@onready var log_label: RichTextLabel = %LogLabel
@onready var start_button: Button = %StartButton

# Battle state
var heroes = []
var enemy = {"name": "Dark Slime", "hp": 500, "max_hp": 500, "atk": 10, "speed": 3, "progress": 0}
var battle_active = false

func _ready() -> void:
	# Load our heroes from resources
	var warrior_data = load("res://resources/heroes/warrior.tres")
	var archer_data = load("res://resources/heroes/archer.tres")
	
	heroes = [
		{"data": warrior_data, "hp": warrior_data.base_hp, "progress": 0},
		{"data": archer_data, "hp": archer_data.base_hp, "progress": 0}
	]
	
	log_message("[color=yellow]A wild %s appears![/color]" % enemy.name)
	log_message("Your team: [color=red]%s[/color] and [color=green]%s[/color]" % [warrior_data.display_name, archer_data.display_name])

func log_message(msg: String) -> void:
	log_label.append_text(msg + "\n")

func _on_start_button_pressed() -> void:
	if battle_active: return
	battle_active = true
	start_button.disabled = true
	log_message("[color=cyan]--- BATTLE START ---[/color]")
	battle_loop()

func battle_loop() -> void:
	while battle_active:
		# Small delay between ticks so we can see what's happening
		await get_tree().create_timer(0.05).timeout
		
		# 1. Update Heroes
		for hero in heroes:
			if hero.hp <= 0: continue
			hero.progress += hero.data.base_speed
			if hero.progress >= 100:
				hero_attack(hero)
				hero.progress = 0
		
		# 2. Update Enemy
		enemy.progress += enemy.speed
		if enemy.progress >= 100:
			enemy_attack()
			enemy.progress = 0
		
		# 3. Check Win/Loss
		check_battle_end()

func hero_attack(hero) -> void:
	var damage = hero.data.base_atk
	enemy.hp -= damage
	log_message("[color=white]%s[/color] attacks for [color=orange]%d[/color] damage! (Slime HP: %d)" % [hero.data.display_name, damage, enemy.hp])

func enemy_attack() -> void:
	# Enemy attacks a random living hero
	var living_heroes = heroes.filter(func(h): return h.hp > 0)
	if living_heroes.is_empty(): return
	
	var target = living_heroes.pick_random()
	target.hp -= enemy.atk
	log_message("[color=red]%s[/color] hits [color=white]%s[/color] for %d damage!" % [enemy.name, target.data.display_name, enemy.atk])

func check_battle_end() -> void:
	if enemy.hp <= 0:
		log_message("[color=green][b]VICTORY![/b][/color] The Slime is defeated.")
		battle_active = false
	elif heroes.all(func(h): return h.hp <= 0):
		log_message("[color=red][b]DEFEAT![/b][/color] All heroes have fallen.")
		battle_active = false
