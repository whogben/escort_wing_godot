extends SceneTree
## Headless verification for level format parsing (Phase B6).
## Run: Godot --headless --path escort_wing_godot -s res://tests/test_level_info.gd


func _init() -> void:
	var failures: Array[String] = []
	_test_eyes_and_ears_rgb(failures)
	_test_random_level_features(failures)
	_test_bramble_retire_angle(failures)
	_test_conditional_event_format(failures)
	if failures.is_empty():
		print("test_level_info: all checks passed")
	else:
		for msg in failures:
			push_error("test_level_info: " + msg)
		quit(1)
		return
	quit()


func _test_eyes_and_ears_rgb(failures: Array[String]) -> void:
	var path := GameData.get_data_path(GameData.Type.LEVEL, "2) Eyes and Ears")
	if path == "":
		failures.append("Eyes and Ears level not found")
		return
	var info := LevelInfo.load_level(path)
	if info == null:
		failures.append("Failed to load Eyes and Ears")
		return
	if not info.custom_rgb:
		failures.append("Eyes and Ears missing custom LEVEL RGB")
		return
	if not is_equal_approx(info.bg_r, 0.8) or not is_equal_approx(info.bg_g, 0.6) or not is_equal_approx(info.bg_b, 0.4):
		failures.append("Eyes and Ears LEVEL RGB values wrong: %s,%s,%s" % [info.bg_r, info.bg_g, info.bg_b])


func _test_random_level_features(failures: Array[String]) -> void:
	var path := GameData.get_data_path(GameData.Type.LEVEL, "Random")
	if path == "":
		failures.append("Random level not found")
		return
	var info := LevelInfo.load_level(path)
	if info == null:
		failures.append("Failed to load Random level")
		return
	if not info.randomize_background_rgb:
		failures.append("Random level missing randomize background RGB flag")
	var fade_found := false
	for event in info.events:
		for action in event.actions:
			if action is LevelInfo.BackgroundColorChangeData:
				var bg := action as LevelInfo.BackgroundColorChangeData
				if not bg.random and is_equal_approx(bg.r, 0.06) and is_equal_approx(bg.fade_time, 5.0):
					fade_found = true
	if not fade_found:
		failures.append("Random level missing t=60 FADE BACKGROUND RGB event")


func _test_bramble_retire_angle(failures: Array[String]) -> void:
	var path := GameData.get_data_path(GameData.Type.LEVEL, "3) Bramble's Choice")
	if path == "":
		failures.append("Bramble's Choice level not found")
		return
	var info := LevelInfo.load_level(path)
	if info == null:
		failures.append("Failed to load Bramble's Choice")
		return
	var retire_found := false
	for event in info.events:
		if event.event_time != 148:
			continue
		for action in event.actions:
			if action is LevelInfo.GroupSpawn:
				var group := action as LevelInfo.GroupSpawn
				if group.team == -1 and group.angle == 135:
					if group.ships.size() == 1 and group.ships[0].ship_info_name == "Bramble's Flak Interceptor":
						retire_found = true
	if not retire_found:
		failures.append("Bramble's Choice missing t=2:28 RETIRE ESCORT with ANGLE:135")


func _test_conditional_event_format(failures: Array[String]) -> void:
	var tmp := "user://test_event_format.lvl"
	var content := """LEVEL NAME:
Test

LEVEL DESC:
Test

LEVEL WIN DESC:
Test

LEVEL BACKGROUND:
Ocean

LEVEL GROUND CLOUD COVER:
0

LEVEL AIR CLOUD COVER:
0

LEVEL SUCCESS MINUTES AND SECONDS:
1
0

PLAYER SHIP:
Interceptor

CONVOY HEADING DEGREES:
0

LEVEL CONVOY SHIPS:
{
0
Freighter
}

EVENT:
MINUTES AND SECONDS:
0
30
{
SET MUSIC:
Duty Calls
FADE BACKGROUND RGB:
0.2
0.3
0.4
OVER TIME:
2
}
"""
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write temp level file")
		return
	file.store_string(content)
	file.close()

	var info := LevelInfo.load_level(tmp)
	DirAccess.remove_absolute(tmp)
	if info == null:
		failures.append("Failed to load conditional EVENT: format")
		return
	if info.events.size() != 1:
		failures.append("Conditional EVENT: should produce one event")
		return
	var event: LevelInfo.Event = info.events[0]
	if event.event_time != 30:
		failures.append("Conditional EVENT: wrong event time")
	if not LevelInfo.event_conditions_met(event, 30):
		failures.append("Conditional EVENT: conditions not met at t=30")
	if LevelInfo.event_conditions_met(event, 29):
		failures.append("Conditional EVENT: conditions met too early")
	var music := false
	var fade := false
	for action in event.actions:
		if action is LevelInfo.MusicChangeData and (action as LevelInfo.MusicChangeData).track_name == "Duty Calls":
			music = true
		if action is LevelInfo.BackgroundColorChangeData:
			var bg := action as LevelInfo.BackgroundColorChangeData
			if is_equal_approx(bg.r, 0.2) and is_equal_approx(bg.fade_time, 2.0):
				fade = true
	if not music or not fade:
		failures.append("Conditional EVENT: missing parsed actions")
