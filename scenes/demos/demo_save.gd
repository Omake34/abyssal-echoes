extends Control

const SAVE_PATH = "user://save_demo.json"

@onready var name_input: LineEdit = %NameInput
@onready var score_label: Label = %ScoreLabel
@onready var status_label: Label = %StatusLabel

var player_score: int = 0

func _on_save_button_pressed() -> void:
	# 1. Create the data dictionary
	var data = {
		"player_name": name_input.text,
		"score": player_score,
		"last_played": Time.get_datetime_string_from_system()
	}
	
	# 2. Convert to JSON string
	var json_string = JSON.stringify(data)
	
	# 3. Save to file
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		status_label.text = "Saved successfully to user://"
	else:
		status_label.text = "Error: Could not save file."

func _on_load_button_pressed() -> void:
	# 1. Check if file exists
	if not FileAccess.file_exists(SAVE_PATH):
		status_label.text = "No save file found."
		return
		
	# 2. Open and read file
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	
	# 3. Parse JSON string back to Dictionary
	var json = JSON.new()
	var error = json.parse(json_string)
	if error == OK:
		var data = json.data
		name_input.text = data["player_name"]
		player_score = data["score"]
		status_label.text = "Loaded: " + data["last_played"]
		update_ui()
	else:
		status_label.text = "Error parsing JSON."

func _on_add_score_pressed() -> void:
	player_score += 100
	update_ui()

func update_ui() -> void:
	score_label.text = "Score: %d" % player_score
