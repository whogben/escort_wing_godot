extends Node2D

## Test script for SoundSystem.
## Plays all available sounds one by one, alternating between left and right sides of the screen.

func _ready() -> void:
	# Give the engine a moment to initialize audio before starting
	await get_tree().process_frame
	run_sound_test()

func run_sound_test() -> void:
	# Get all sound files from the GameData directory
	var files = GameData.list_data_files(GameData.SOUND_FX)
	var sound_names: Array[String] = []
	
	# Filter for .ogg files and strip extensions
	for file in files:
		if file.get_extension() == "ogg":
			sound_names.append(file.get_basename())
	
	# Sort for consistent order
	sound_names.sort()
	
	print("Starting Sound Test. Found ", sound_names.size(), " sounds.")
	print("Sounds will play with 1 second intervals, alternating Left/Right.")
	
	var screen_size = get_viewport_rect().size
	# Positions for stereo testing
	var left_pos = Vector2(screen_size.x * 0.2, screen_size.y * 0.5)
	var right_pos = Vector2(screen_size.x * 0.8, screen_size.y * 0.5)
	
	for i in range(sound_names.size()):
		var sound_name = sound_names[i]
		
		# Wait 1 second before playing each sound
		await get_tree().create_timer(1.0).timeout
		
		# Determine side
		var is_left = (i % 2 == 0)
		var pos = left_pos if is_left else right_pos
		var side_str = "LEFT" if is_left else "RIGHT"
		
		print("[%s] Playing: %s (%s)" % [i + 1, sound_name, side_str])
		
		# Create a visual indicator
		_create_visual_indicator(pos, is_left)
		
		# Play the sound
		SoundSystem.play(sound_name, pos, self)

	print("Sound Test Sequence Complete.")

func _create_visual_indicator(pos: Vector2, is_left: bool) -> void:
	var marker = ColorRect.new()
	marker.color = Color.CYAN if is_left else Color.MAGENTA
	marker.size = Vector2(40, 40)
	marker.position = pos - marker.size / 2
	add_child(marker)
	
	# Create a label for the sound name? No, handled by console for now, keeping scene simple.
	
	# Animate the marker fading out
	var tween = create_tween()
	tween.tween_property(marker, "scale", Vector2(2.0, 2.0), 0.5)
	tween.parallel().tween_property(marker, "modulate:a", 0.0, 0.5)
	tween.tween_callback(marker.queue_free)
