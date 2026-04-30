extends Control

@onready var background: TextureRect = $Background
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var stats_label: RichTextLabel = $CenterContainer/VBoxContainer/StatsLabel
@onready var return_button: Button = $CenterContainer/VBoxContainer/ReturnButton

func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)
	return_button.grab_focus()

func setup(victory: bool, stats: Dictionary) -> void:
	if victory:
		status_label.text = "VICTORY"
		status_label.add_theme_color_override("font_color", Color(1, 0.84, 0)) # Gold
		background.texture = _load_png_texture("res://assets/ui/victory_bg.png")
	else:
		status_label.text = "DEFEAT"
		status_label.add_theme_color_override("font_color", Color(0.86, 0.08, 0.24)) # Crimson
		background.texture = _load_png_texture("res://assets/ui/defeat_bg.png")
		
	var stats_text = "[center]"
	stats_text += "[b]Run Statistics[/b]\n\n"
	stats_text += "Battles Won: %d\n" % stats.get("battles_won", 0)
	stats_text += "Enemies Killed: %d\n" % stats.get("enemies_killed", 0)
	stats_text += "Skills Merged: %d\n" % stats.get("skills_merged", 0)
	stats_text += "Gold Earned: %d\n" % stats.get("gold_earned", 0)
	stats_text += "Turns Survived: %d\n" % stats.get("turns_survived", 0)
	stats_text += "[/center]"
	
	stats_label.text = stats_text

func _on_return_pressed() -> void:
	EventBus.scene_change_requested.emit("res://scenes/MainMenu.tscn")

func _load_png_texture(path: String) -> Texture2D:
	var bytes = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var image = Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)
