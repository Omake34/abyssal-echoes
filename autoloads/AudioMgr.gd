# PURPOSE: AudioMgr — Controls all music and sound effects in the game.
# Keeps music and SFX on separate volume buses so player can adjust them independently.
# HOW TO USE:
#   AudioMgr.play_sfx("hit")          # Play a sound effect by name
#   AudioMgr.play_music("battle")     # Play a music track by name
#   AudioMgr.set_sfx_volume(0.8)      # Set SFX volume (0.0 to 1.0)

extends Node

# ── AUDIO BUS NAMES (must match your Godot Audio Bus Layout) ──────────────────
const BUS_MUSIC = "Music"
const BUS_SFX   = "SFX"

# ── AUDIO PLAYERS ─────────────────────────────────────────────────────────────
# We create two players: one for looping music, one for one-shot SFX
var _music_player: AudioStreamPlayer
var _sfx_player:   AudioStreamPlayer

# ── SOUND FILE PATHS ──────────────────────────────────────────────────────────
# Add your audio files to res://assets/audio/ and register them here
# Free sources: Freesound.org (CC0), Kevin MacLeod (CC BY)
const MUSIC_FILES: Dictionary = {
	"menu":    "res://assets/audio/music/menu_theme.ogg",
	"battle":  "res://assets/audio/music/battle_theme.ogg",
	"victory": "res://assets/audio/music/victory.ogg",
	"defeat":  "res://assets/audio/music/defeat.ogg",
}

const SFX_FILES: Dictionary = {
	"hit_physical": "res://assets/audio/sfx/hit_physical.wav",
	"hit_magic":    "res://assets/audio/sfx/hit_magic.wav",
	"heal":         "res://assets/audio/sfx/heal.wav",
	"skill_cast":   "res://assets/audio/sfx/skill_cast.wav",
	"merge":        "res://assets/audio/sfx/merge.wav",
	"purchase":     "res://assets/audio/sfx/purchase.wav",
	"hero_die":     "res://assets/audio/sfx/hero_die.wav",
	"enemy_die":    "res://assets/audio/sfx/enemy_die.wav",
	"button_click": "res://assets/audio/sfx/button_click.wav",
	"level_up":     "res://assets/audio/sfx/level_up.wav",
}

# ── LIFECYCLE ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Create the music player — set to loop automatically
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)

	# Create the SFX player
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = BUS_SFX
	add_child(_sfx_player)

	print("[AudioMgr] Ready.")

# ── MUSIC CONTROL ─────────────────────────────────────────────────────────────

## Plays a music track by name. Stops the current track first.
func play_music(track_name: String) -> void:
	if not MUSIC_FILES.has(track_name):
		push_warning("[AudioMgr] Unknown music track: " + track_name)
		return
	var path = MUSIC_FILES[track_name]
	if not ResourceLoader.exists(path):
		push_warning("[AudioMgr] Music file not found: " + path + " (placeholder — add your audio file)")
		return
	var stream = load(path)
	if _music_player.stream == stream and _music_player.playing:
		return  # Already playing this track
	_music_player.stream = stream
	_music_player.play()

## Stops the current music track
func stop_music() -> void:
	_music_player.stop()

## Fades out music over a given duration (in seconds)
func fade_out_music(duration: float = 1.0) -> void:
	var tween = create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, duration)
	tween.tween_callback(_music_player.stop)
	tween.tween_property(_music_player, "volume_db", 0.0, 0.0)

# ── SFX CONTROL ───────────────────────────────────────────────────────────────

## Plays a sound effect by name. Multiple SFX can overlap.
func play_sfx(sfx_name: String) -> void:
	if not SFX_FILES.has(sfx_name):
		push_warning("[AudioMgr] Unknown SFX: " + sfx_name)
		return
	var path = SFX_FILES[sfx_name]
	if not ResourceLoader.exists(path):
		# Silent fail during development — audio files added later
		return
	# Use a new player so SFX can overlap
	var player = AudioStreamPlayer.new()
	player.bus = BUS_SFX
	player.stream = load(path)
	player.finished.connect(player.queue_free)  # Auto-cleanup when done
	add_child(player)
	player.play()

# ── VOLUME CONTROL ────────────────────────────────────────────────────────────

## Set music volume. value is 0.0 (silent) to 1.0 (full)
func set_music_volume(value: float) -> void:
	var db = linear_to_db(clampf(value, 0.0, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC), db)

## Set SFX volume. value is 0.0 (silent) to 1.0 (full)
func set_sfx_volume(value: float) -> void:
	var db = linear_to_db(clampf(value, 0.0, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_SFX), db)
