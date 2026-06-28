extends SceneTree
## Headless verification for Phase B9 menu / persistence hooks.
## Run: Godot --headless --path escort_wing_godot -s res://tests/test_b9_menus.gd


func _init() -> void:
	var failures: Array[String] = []
	_test_progress_manager_api(failures)
	_test_playable_ships_for_random_mission(failures)
	_test_random_mission_generator_params(failures)
	if failures.is_empty():
		print("test_b9_menus: all checks passed")
	else:
		for msg in failures:
			push_error("test_b9_menus: " + msg)
		quit(1)
		return
	quit()


func _test_progress_manager_api(failures: Array[String]) -> void:
	ProgressManager.load_all()
	if ProgressManager.max_mission < 1:
		failures.append("max_mission should be at least 1")
	if ProgressManager.WINDOW_SIZE.x <= 0 or ProgressManager.WINDOW_SIZE.y <= 0:
		failures.append("WINDOW_SIZE should be a positive resolution")
	if ProgressManager.INPUT_ACTIONS.size() != 6:
		failures.append("expected 6 rebindable input actions")
	for action in ProgressManager.INPUT_ACTIONS:
		if not InputMap.has_action(action):
			failures.append("missing InputMap action: " + action)


func _test_playable_ships_for_random_mission(failures: Array[String]) -> void:
	var playable: Array[String] = []
	for base_name in GameData.list_ship_info_base_names():
		var si := ShipInfo.named(base_name)
		if si != null and si.playable:
			playable.append(si.name)
	if playable.is_empty():
		failures.append("no playable ships found for random mission UI")
	elif not playable.has("Flak Interceptor"):
		failures.append("Flak Interceptor should be playable")


func _test_random_mission_generator_params(failures: Array[String]) -> void:
	var info := RandomMissionGenerator.build_random_mission("Flak Interceptor", 1, 8, 50, 300)
	if info == null:
		failures.append("build_random_mission returned null")
		return
	if info.player_ship != "Flak Interceptor":
		failures.append("player_ship not set on procedural mission")
	if info.player_team != 1:
		failures.append("random mission should store chosen player_team on LevelInfo")
	if info.convoy_ships.any(func(spawn: LevelInfo.ShipSpawn) -> bool:
		return spawn.ship_info_name != "Freighter"
	):
		failures.append("random mission convoy should only use procedural Freighters")
	if info.convoy_ships.any(func(spawn: LevelInfo.ShipSpawn) -> bool:
		return spawn.ship_info_name == "Radar Freighter"
	):
		failures.append("random mission should not keep Random.lvl template convoy ships")
	var telrith := RandomMissionGenerator.build_random_mission("Tel-Rith Fighter", 2, 5, 50, 300)
	if telrith == null:
		failures.append("build_random_mission for Telrith faction returned null")
	elif telrith.player_team != 2:
		failures.append("random mission should preserve non-human player_team")
	else:
		for spawn in telrith.escort_ships:
			var ally := ShipInfo.named(spawn.ship_info_name)
			if ally == null or ally.team != 2:
				failures.append("random escorts should all be from the chosen faction")
				break
	if info.end_ships.is_empty():
		failures.append("community random missions should populate end_ships")
	# escort_strength 50 -> 10.5 budget -> 10 or 11 escorts depending on float loop
	if info.escort_ships.size() < 10:
		failures.append("scaled escort budget should add multiple escorts (got %d)" % info.escort_ships.size())
	if info.events.is_empty():
		failures.append("random mission should schedule enemy events")
