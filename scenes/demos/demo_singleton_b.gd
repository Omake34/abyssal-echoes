extends Control

@onready var score_label: Label = %ScoreLabel

func _ready() -> void:
	# Even though we just switched scenes, the data is still here!
	score_label.text = "Score: %d" % GlobalScore.total_score

func _on_switch_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/demos/demo_singleton_a.tscn")
