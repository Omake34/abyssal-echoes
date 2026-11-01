# PURPOSE: Package generated skill art at a consistent resolution for small game UI.
# Run with Godot --headless --path PROJECT --script res://tools/PrepareSkillArt.gd.
# Original generated images remain in the ImageGen library; this resizes runtime copies.
class_name PrepareSkillArt
extends SceneTree

const ART_DIRECTORY = "res://assets/skills/"
const ICON_RESOLUTION = 512

func _initialize() -> void:
	var count = 0
	for file in DirAccess.get_files_at(ART_DIRECTORY):
		if not file.ends_with(".png"):
			continue
		var path = ART_DIRECTORY + file
		var image = Image.load_from_file(path)
		if image == null:
			printerr("Could not load skill art: " + path)
			quit(1)
			return
		if image.get_width() != ICON_RESOLUTION or image.get_height() != ICON_RESOLUTION:
			image.resize(ICON_RESOLUTION, ICON_RESOLUTION, Image.INTERPOLATE_LANCZOS)
			if image.save_png(path) != OK:
				printerr("Could not save skill art: " + path)
				quit(1)
				return
		count += 1
	print("SKILL ART PACKAGED: %d icons at %dx%d" % [count, ICON_RESOLUTION, ICON_RESOLUTION])
	quit(0)
