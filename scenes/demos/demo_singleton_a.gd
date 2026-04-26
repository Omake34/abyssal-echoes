extends Control

@onready var score_label: Label = %ScoreLabel

func _ready() -> void:
	update_ui()

func _on_add_button_pressed() -> void:
	# Accessing the singleton directly by its name!
	GlobalScore.total_score += 10
	update_ui()

func _on_switch_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/demos/demo_singleton_b.tscn")

func update_ui() -> void:
	score_label.text = "Current Global Score: %d" % GlobalScore.total_score
