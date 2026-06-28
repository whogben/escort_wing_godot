extends SceneTree
## Headless verification for music loading and SET MUSIC parsing (Phase B5).
## Run: Godot --headless --path escort_wing_godot -s res://tests/test_music.gd


func _init() -> void:
	var failures: Array[String] = []
	_test_all_music_load(failures)
	_test_set_music_parsing(failures)
	_test_play_track_smoke(failures)
	if failures.is_empty():
		print("test_music: all checks passed")
	else:
		for msg in failures:
			push_error("test_music: " + msg)
		quit(1)
		return
	quit()


func _test_all_music_load(failures: Array[String]) -> void:
	MusicSystem.clear_cache()
	var expected := ["Boglins", "Duty Calls", "No Return", "Waiting"]
	for track in expected:
		var path := GameData.get_data_path(GameData.Type.MUSIC, track)
		if path == "":
			failures.append("Music file missing: %s" % track)
			continue
		var stream := GameData.load_audio(path)
		if stream == null:
			failures.append("Failed to load music: %s" % track)


func _test_set_music_parsing(failures: Array[String]) -> void:
	var path := GameData.get_data_path(GameData.Type.LEVEL, "1) Homeward Bound")
	if path == "":
		failures.append("Homeward Bound level not found")
		return
	var info := LevelInfo.load_level(path)
	if info == null:
		failures.append("Failed to load Homeward Bound")
		return
	var found_start := false
	var found_end := false
	for event in info.events:
		for action in event.actions:
			if action is LevelInfo.MusicChangeData:
				var music := action as LevelInfo.MusicChangeData
				if event.event_time == 0 and music.track_name == "No Return":
					found_start = true
				if music.track_name == "Boglins":
					found_end = true
	if not found_start:
		failures.append("Homeward Bound missing t=0 SET MUSIC: No Return")
	if not found_end:
		failures.append("Homeward Bound missing SET MUSIC: Boglins")

	var bramble_path := GameData.get_data_path(GameData.Type.LEVEL, "3) Bramble's Choice")
	if bramble_path != "":
		var bramble := LevelInfo.load_level(bramble_path)
		var waiting := false
		for event in bramble.events:
			for action in event.actions:
				if action is LevelInfo.MusicChangeData:
					if (action as LevelInfo.MusicChangeData).track_name == "Waiting":
						waiting = true
		if not waiting:
			failures.append("Bramble's Choice missing SET MUSIC: Waiting")


func _test_play_track_smoke(failures: Array[String]) -> void:
	MusicSystem.clear_cache()
	var stream := GameData.load_audio(GameData.get_data_path(GameData.Type.MUSIC, "Duty Calls"))
	if stream == null:
		failures.append("Duty Calls stream failed to load for MusicSystem smoke test")
