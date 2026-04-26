extends Control

# This is our reactive variable.
# In Godot 4, we use 'set' to run code whenever the value is assigned.
var current_health: int = 100:
	set(value):
		current_health = clampi(value, 0, max_health)
		update_ui()

var max_health: int = 100

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel

func _ready() -> void:
	update_ui()

func update_ui() -> void:
	# This function runs automatically whenever current_health is changed!
	if health_bar:
		health_bar.value = current_health
	if health_label:
		health_label.text = "HP: %d / %d" % [current_health, max_health]

func _on_damage_button_pressed() -> void:
	# Note how we don't call update_ui() here. 
	# The 'set' trigger does it for us!
	current_health -= 15

func _on_heal_button_pressed() -> void:
	current_health += 15
