extends Control

@onready var background: TextureRect = $Background
@onready var continue_button: Button = $MainLayout/LeftSection/ContinueButton
@onready var new_run_button: Button = $MainLayout/LeftSection/NewRunButton
@onready var talent_button: Button = $MainLayout/LeftSection/TalentButton
@onready var codex_button: Button = $MainLayout/LeftSection/CodexButton
@onready var quit_button: Button = $MainLayout/LeftSection/QuitButton

func _ready() -> void:
	# Manually load background to avoid .tscn dependency errors
	var bg_tex = _load_png_texture("res://assets/ui/main_menu_bg.png")
	if bg_tex:
		background.texture = bg_tex
	else:
		# Fallback: dark blue background if image is still re-importing
		background.self_modulate = Color(0.1, 0.1, 0.15)
		print("[MainMenu] Background image still re-importing, using fallback color.")		
	
	continue_button.pressed.connect(_on_continue_pressed)
	new_run_button.pressed.connect(_on_new_run_pressed)
	talent_button.pressed.connect(_on_talent_pressed)
	codex_button.pressed.connect(_on_codex_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	$MainLayout/LeftSection/ArenaTrialButton.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/battle/ArenaTrial.tscn"))
	
	# Only show continue if a save exists
	var has_save = RunState.has_saved_run()
	continue_button.visible = has_save
	
	# Initial focus for keyboard/controller navigation
	if has_save:
		continue_button.grab_focus()
	else:
		new_run_button.grab_focus()

func _load_png_texture(path: String) -> Texture2D:
	var bytes = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var image = Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)

func _on_continue_pressed() -> void:
	if RunState.load_run():
		SceneManager.resume_run()
	else:
		# Fallback if load fails
		continue_button.visible = false
		new_run_button.grab_focus()

func _on_new_run_pressed() -> void:
	RunState.start_new_run()
	EventBus.scene_change_requested.emit("res://scenes/HeroSelectScene.tscn")

func _on_talent_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/meta/TalentTree.tscn")

func _on_codex_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/meta/CodexScene.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
