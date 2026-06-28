class_name SoundSystem
extends Node

## Static sound system that mimics the original BlitzMax sound system's functionality.
## Handles loading and playing of 2D spatial sounds.

# Cache loaded AudioStream resources to avoid reloading from disk
# Key: sound name (String), Value: AudioStream
static var _sound_cache: Dictionary = {}

# Active audio players. Used to stop all sounds.
static var _active_players: Array[AudioStreamPlayer2D] = []

# Minimum audible range in world units; grows with viewport when the window is larger.
const BASE_MAX_DISTANCE: float = 2000.0

## Returns the spatial audio max distance for the current viewport size.
static func get_max_distance(context: Node) -> float:
	if not is_instance_valid(context) or not context.is_inside_tree():
		return BASE_MAX_DISTANCE
	var viewport_size: Vector2 = context.get_viewport().get_visible_rect().size
	var viewport_max: float = maxf(viewport_size.x, viewport_size.y)
	return maxf(BASE_MAX_DISTANCE, viewport_max)

## Updates max_distance on all active sounds (e.g. after a window resize).
static func sync_max_distances(context: Node) -> void:
	var max_distance := get_max_distance(context)
	for player in _active_players:
		if is_instance_valid(player):
			player.max_distance = max_distance

## Plays a sound at the given position.
## [param sound_name]: The name of the sound file (without extension).
## [param position]: The global position to play the sound at.
## [param context]: A node in the scene tree (used to access the tree and attach the sound).
## [param volume_db]: Volume adjustment in decibels.
## [param pitch_scale]: Pitch scale (1.0 is normal).
static func play(sound_name: String, position: Vector2, context: Node, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not is_instance_valid(context) or not context.is_inside_tree():
		# Cannot play sound without a valid tree context
		return

	var stream = _get_sound_stream(sound_name)
	if stream == null:
		return

	sync_max_distances(context)

	# Create a transient AudioStreamPlayer2D
	var player = AudioStreamPlayer2D.new()
	player.stream = stream
	player.global_position = position
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	
	# Configure attenuation to behave somewhat like the original
	# Original used an inverse distance formula. Godot's default is also inverse distance.
	player.max_distance = get_max_distance(context)
	player.panning_strength = 1.0
	
	# Auto-destroy on finish
	player.finished.connect(player.queue_free)
	
	# Track the player
	_active_players.append(player)
	# Clean up from tracking when it leaves the tree
	player.tree_exiting.connect(func(): _active_players.erase(player))
	
	# Add to the current scene so it persists even if the context node dies (unless scene changes).
	# This mimics "fire and forget" behavior.
	var root = context.get_tree().current_scene
	if root:
		root.add_child(player)
		player.play()
	else:
		# Fallback if current_scene is not available (e.g. during scene transition?)
		# Try adding to context if possible, otherwise abort.
		context.add_child(player)
		player.play()

## Stops all currently playing sounds and removes them.
static func stop_all() -> void:
	# Duplicate the list to avoid modification issues during iteration,
	# and clear the main list immediately.
	var players = _active_players.duplicate()
	_active_players.clear()
	
	for player in players:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()

## Clears cached audio streams (e.g. after loading or unloading a mod).
static func clear_cache() -> void:
	_sound_cache.clear()


## Retrieves or loads the sound stream for the given name.
static func _get_sound_stream(sound_name: String) -> AudioStream:
	if _sound_cache.has(sound_name):
		return _sound_cache[sound_name]
		
	var path = GameData.get_data_path(GameData.Type.SOUND_FX, sound_name)
	if path.is_empty():
		push_warning("SoundSystem: Sound not found: " + sound_name)
		return null
	
	var stream = GameData.load_audio(path)
	if stream:
		_sound_cache[sound_name] = stream
		
		# Ensure OGG files don't loop by default (typical for SFX)
		if stream is AudioStreamOggVorbis:
			stream.loop = false
	else:
		push_error("SoundSystem: Failed to load sound at " + path)
		
	return stream

## Preloads a list of sounds. Useful for loading levels.
## Preloading ensures that the audio data is loaded into memory before gameplay starts.
## If sounds are loaded on the fly (when play() is called), there can be a slight
## stutter or frame drop the first time a sound plays, due to disk I/O.
static func preload_sounds(sound_names: Array[String]) -> void:
	for sound_name in sound_names:
		_get_sound_stream(sound_name)
