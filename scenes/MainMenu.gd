extends Control

@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var new_run_button: Button = $CenterContainer/VBoxContainer/NewRunButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	new_run_button.pressed.connect(_on_new_run_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Only show continue if a save exists
	var has_save = RunState.has_saved_run()
	continue_button.visible = has_save
	
	# Initial focus for keyboard/controller navigation
	if has_save:
		continue_button.grab_focus()
	else:
		new_run_button.grab_focus()

func _on_continue_pressed() -> void:
	if RunState.load_run():
		EventBus.scene_change_requested.emit("res://scenes/map/MapView.tscn")
	else:
		# Fallback if load fails
		continue_button.visible = false
		new_run_button.grab_focus()

func _on_new_run_pressed() -> void:
	# If a save exists, maybe warn the player? 
	# For now, just start a new one (RunState.start_new_run handles deleting old save)
	RunState.start_new_run()
	
	# Initial setup for a fresh run
	RunState.add_hero_to_party(load("res://resources/heroes/warrior.tres"))
	RunState.add_hero_to_party(load("res://resources/heroes/archer.tres"))
	
	EventBus.scene_change_requested.emit("res://scenes/map/MapView.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
