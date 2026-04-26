extends Node

# This script lives forever. It is loaded at game start and stays
# in memory even when you change scenes.

var total_score: int = 0:
	set(value):
		total_score = value
		print("Global Score Updated: ", total_score)

func reset_score() -> void:
	total_score = 0
